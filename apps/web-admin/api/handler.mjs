// SalesArmy admin + platform API.
//
// One stateless handler used by BOTH runtimes:
//   - Cloudflare Workers  (_worker.js)
//   - Node.js             (server.js)
// Supabase is the single source of truth. There is no local state file.
//
// Access model
//   PUBLIC   config, public catalog, health, login, agency self-signup,
//            Razorpay webhook (HMAC verified)
//   MEMBER   checkout (owners), staff provisioning (owners, own tenant),
//            tenant list (own tenant)
//   ADMIN    everything under /api/platform/* (profile.role = super_admin)
import { createDb, HttpError, enc } from './supabase.mjs';
import {
  ROLES, STAFF_ROLES, TENANT_STATUSES, ORDER_STATUSES, HARDWARE_STATUSES, canonicalRole, tierFor,
  DEFAULT_TIERS, DEFAULT_PRINTERS, DEFAULT_ADDONS, DEFAULT_REMOTE_CONFIG, DEFAULT_BROADCAST,
  normalizePlans, normalizePrinter, normalizeAddon, normalizeCoupon, normalizeCoupons,
  normalizeSettings, normalizeRemoteConfig, normalizeBroadcast,
} from './catalog.mjs';
import { createCheckoutService, createRazorpay } from './checkout.mjs';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const SLUG_RE = /^[A-Za-z0-9_\-]{1,64}$/;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
const MAX_BODY = 1024 * 1024;

const fail = (status, message) => { throw new HttpError(status, message); };
const nowIso = () => new Date().toISOString();
const str = (v, max = 255) => (v === undefined || v === null ? '' : String(v).trim().slice(0, max));
const titleCase = s => String(s || '').replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase());
const dateOnly = v => (v ? String(v).split('T')[0] : null);

function json(data, status = 200, extra = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', ...extra },
  });
}

function csv(rows, filename) {
  const safe = v => {
    let s = v === null || v === undefined ? '' : typeof v === 'object' ? JSON.stringify(v) : String(v);
    if (/^[=+\-@\t\r]/.test(s)) s = `'${s}`;
    return `"${s.replace(/"/g, '""')}"`;
  };
  const headers = rows.length ? Object.keys(rows[0]) : ['empty'];
  const body = [headers.join(','), ...rows.map(r => headers.map(h => safe(r[h])).join(','))].join('\r\n');
  return new Response('﻿' + body, {
    headers: { 'Content-Type': 'text/csv; charset=utf-8', 'Content-Disposition': `attachment; filename="${filename}"`, 'Cache-Control': 'no-store' },
  });
}

async function readJson(request) {
  const text = await request.text();
  if (text.length > MAX_BODY) fail(413, 'Payload too large');
  if (!text) return {};
  try {
    const parsed = JSON.parse(text);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) fail(400, 'Expected a JSON object');
    return parsed;
  } catch (err) {
    if (err instanceof HttpError) throw err;
    fail(400, 'Invalid JSON body');
  }
}

function bearer(request) {
  const h = request.headers.get('Authorization') || '';
  return h.startsWith('Bearer ') ? h.slice(7).trim() : '';
}

// Per-isolate login throttle (Node: per process). Edge deployments should
// also add a Cloudflare rate-limiting rule on /api/auth/*.
const loginAttempts = new Map();
function throttleLogin(key) {
  const now = Date.now();
  const entry = loginAttempts.get(key) || { count: 0, start: now };
  if (now - entry.start > 15 * 60 * 1000) { entry.count = 0; entry.start = now; }
  entry.count++;
  loginAttempts.set(key, entry);
  if (loginAttempts.size > 5000) loginAttempts.clear();
  return entry.count <= 10;
}

export function createApi(env, { fetchImpl = fetch } = {}) {
  const cfg = {
    url: env.SUPABASE_URL,
    anonKey: env.SUPABASE_ANON_KEY,
    serviceKey: env.SUPABASE_SERVICE_ROLE_KEY,
    razorpayKeyId: env.RAZORPAY_KEY_ID || '',
    razorpayKeySecret: env.RAZORPAY_KEY_SECRET || '',
    razorpayWebhookSecret: env.RAZORPAY_WEBHOOK_SECRET || '',
    allowedOrigins: String(env.ALLOWED_ORIGINS || '').split(',').map(s => s.trim()).filter(Boolean),
  };
  let dbInstance = null;
  const db = () => (dbInstance ||= createDb({ url: cfg.url, anonKey: cfg.anonKey, serviceKey: cfg.serviceKey, fetchImpl }));
  const gateway = createRazorpay({ keyId: cfg.razorpayKeyId, keySecret: cfg.razorpayKeySecret, fetchImpl });

  // ------------------------------------------------------------------
  // Settings & catalog
  // ------------------------------------------------------------------
  async function getSetting(id) {
    const rows = await db().select('platform_settings', `id=eq.${enc(id)}&select=data`);
    return rows?.[0]?.data ?? null;
  }
  async function putSetting(id, data) {
    await db().insert('platform_settings', { id, data, updated_at: nowIso() }, { onConflict: 'id', upsert: true, returning: false });
    return data;
  }
  async function getPricing() {
    const data = (await getSetting('pricing_and_plans')) || {};
    let plans;
    try { plans = normalizePlans(data.plans || { tiers: DEFAULT_TIERS }); } catch (_) { plans = { tiers: DEFAULT_TIERS, planGst: 18 }; }
    return {
      plans,
      printerOptions: Array.isArray(data.printerOptions) ? data.printerOptions : DEFAULT_PRINTERS,
      subscriptionAddons: Array.isArray(data.subscriptionAddons) ? data.subscriptionAddons : DEFAULT_ADDONS,
    };
  }
  async function savePricing(pricing) {
    const data = {
      plans: pricing.plans,
      printerOptions: pricing.printerOptions,
      subscriptionAddons: pricing.subscriptionAddons,
      updatedAt: nowIso(),
    };
    return putSetting('pricing_and_plans', data);
  }
  async function getCoupons() {
    const data = await getSetting('coupons');
    return Array.isArray(data?.coupons) ? data.coupons : [];
  }
  const saveCoupons = coupons => putSetting('coupons', { coupons, updatedAt: nowIso() });
  async function getRemoteConfig() {
    return normalizeRemoteConfig({}, (await getSetting('remote_config')) || DEFAULT_REMOTE_CONFIG);
  }
  async function getBroadcast() {
    return { ...DEFAULT_BROADCAST, ...((await getSetting('broadcast')) || {}) };
  }
  async function getGeneralSettings() {
    return (await getSetting('general_settings')) || { defaultPlanId: 'startup', defaultTrialDays: 14, trialGracePeriodDays: 3, currency: 'INR' };
  }
  async function getCatalog() {
    const [pricing, coupons] = await Promise.all([getPricing(), getCoupons()]);
    return { ...pricing, coupons };
  }

  const checkout = () => createCheckoutService({ db: db(), gateway, getCatalog });

  // ------------------------------------------------------------------
  // Auth & audit
  // ------------------------------------------------------------------
  async function authenticate(request) {
    const token = bearer(request);
    if (!token) return null;
    const user = await db().getUser(token);
    if (!user?.id) return null;
    const rows = await db().select('profiles', `id=eq.${enc(user.id)}&select=id,name,email,role,tenant_id,account_status,is_active`);
    const profile = rows?.[0];
    if (!profile || profile.is_active === false || profile.account_status !== 'active') return null;
    return { ...profile, email: user.email || profile.email };
  }

  async function requireUser(ctx) {
    ctx.user ||= await authenticate(ctx.request);
    if (!ctx.user) fail(401, 'Sign in required.');
    return ctx.user;
  }
  async function requireAdmin(ctx) {
    const user = await requireUser(ctx);
    if (user.role !== 'super_admin') fail(403, 'Super Admin access required.');
    return user;
  }

  async function audit(ctx, category, action, details, { status = 'success', target = null } = {}) {
    try {
      await db().insert('admin_audit_logs', {
        category, action, details: str(details, 2000), status, target,
        actor_id: ctx.user?.id || null, actor_email: ctx.user?.email || 'system', ip: ctx.ip || null,
      }, { returning: false });
    } catch (err) {
      console.warn('[audit] could not record', action, err.message);
    }
  }

  // ------------------------------------------------------------------
  // Mapping DB rows -> admin UI shapes
  // ------------------------------------------------------------------
  function mapTenant(t, plans, stats = {}) {
    const s = stats[t.tenant_id] || {};
    const tier = tierFor(plans, t.plan_id);
    const suspended = t.subscription_status === 'suspended' || t.is_active === false;
    return {
      id: t.tenant_id, tenantId: t.tenant_id, userId: t.tenant_id,
      firmName: t.business_name, name: t.business_name, businessName: t.business_name,
      ownerName: t.contact_person || '', ownerUid: t.owner_uid || null,
      phone: t.mobile || '', email: t.email || '', gstin: t.gstin || '', pan: t.pan || '',
      address: t.address || t.warehouse_address || '', city: t.city || '', state: t.state || '',
      subscriptionStatus: t.subscription_status || 'active',
      subscriptionPlanId: t.plan_id || 'free',
      planName: tier ? `${tier.name} Plan` : (t.plan_id === 'free' ? 'Free Tier' : titleCase(t.plan_id || 'free')),
      expiryDate: dateOnly(t.subscription_end_date) || 'Never (Freemium)',
      subscription_end_date: t.subscription_end_date,
      isSuspended: suspended, isActive: !suspended,
      maxUsers: t.max_users ?? null, maxShops: t.max_shops ?? null,
      ordersCount: s.orders || 0, orderValue: Number(s.orderValue || 0), revenue: Number(s.invoiced || 0),
      collected: Number(s.collected || 0), outstanding: Number(s.outstanding || 0),
      shopsCount: s.shops || 0, usersCount: s.users || 0, lastOrderAt: s.lastOrderAt || null,
      freemiumSelling: true,
      createdAt: t.created_at, updatedAt: t.updated_at,
    };
  }
  function mapUser(p, tenantNames) {
    return {
      id: p.id, uid: p.id, name: p.name || '', email: p.email || '', phone: p.phone || '',
      role: p.role, tenantId: p.tenant_id || null,
      tenantName: p.tenant_id ? (tenantNames[p.tenant_id] || p.tenant_id) : (p.role === 'super_admin' ? 'Platform' : 'No agency'),
      status: p.account_status && p.account_status !== 'active' ? p.account_status : (p.is_active === false ? 'suspended' : 'active'),
      createdAt: p.created_at, updatedAt: p.updated_at, lastLoginAt: p.last_login_at || null,
    };
  }
  function mapPrinterOrder(po) {
    return {
      id: po.order_id, orderId: po.order_id, tenantId: po.tenant_id, userId: po.tenant_id,
      customerName: po.contact_person || po.business_name || '', agencyName: po.business_name || '',
      phone: po.phone || '', printerItem: po.printer_model || '', quantity: po.quantity || 1,
      price: Number(po.total_amount || 0), paymentStatus: po.payment_status || 'pending',
      shippingAddress: po.shipping_address || '', orderedAt: po.created_at, updatedAt: po.updated_at,
      status: titleCase(po.fulfillment_status || 'processing'),
      courierName: po.courier_name || '', trackingNumber: po.tracking_number || 'Unassigned', notes: po.notes || '',
    };
  }
  function mapNotification(n) {
    return {
      id: n.notification_id, title: n.title, message: n.message, type: n.type, category: n.type,
      severity: n.data?.severity || 'info', targetTenant: n.tenant_id || 'all', targetRole: n.target_role || 'all',
      targetPlan: n.data?.targetPlan || 'all', actionUrl: n.data?.actionUrl || '',
      isBroadcast: n.is_broadcast, read: n.is_read, timestamp: n.created_at,
    };
  }

  async function loadRetailOrders(limit = 200, tenantId = null) {
    const filter = tenantId ? `tenant_id=eq.${enc(tenantId)}&` : '';
    const orders = await db().select('orders', `${filter}select=*&order=order_date.desc&limit=${limit}`);
    if (!orders.length) return [];
    const ids = orders.map(o => o.id);
    const tenantIds = [...new Set(orders.map(o => o.tenant_id))];
    const shopIds = [...new Set(orders.map(o => o.shop_id).filter(Boolean))];
    const staffIds = [...new Set(orders.map(o => o.sales_person_uid).filter(Boolean))];
    const inList = arr => `(${arr.map(v => `"${String(v).replace(/"/g, '')}"`).join(',')})`;
    const [items, shops, staff, invoices, tenants] = await Promise.all([
      db().select('order_items', `order_id=in.${enc(inList(ids))}&select=*`),
      shopIds.length ? db().select('shops', `tenant_id=in.${enc(inList(tenantIds))}&shop_id=in.${enc(inList(shopIds))}&select=tenant_id,shop_id,shop_name,owner_name,phone,address`) : [],
      staffIds.length ? db().select('profiles', `id=in.${enc(inList(staffIds))}&select=id,name`) : [],
      db().select('invoices', `tenant_id=in.${enc(inList(tenantIds))}&order_id=in.${enc(inList(orders.map(o => o.order_id)))}&select=tenant_id,order_id,payment_status,amount_due,invoice_number`),
      db().select('tenants', `tenant_id=in.${enc(inList(tenantIds))}&select=tenant_id,business_name`),
    ]);
    const shopKey = (t, s) => `${t}::${s}`;
    const shopMap = new Map(shops.map(s => [shopKey(s.tenant_id, s.shop_id), s]));
    const staffMap = new Map(staff.map(s => [s.id, s.name]));
    const invMap = new Map(invoices.map(i => [shopKey(i.tenant_id, i.order_id), i]));
    const tenantMap = new Map(tenants.map(t => [t.tenant_id, t.business_name]));
    const itemsByOrder = new Map();
    for (const it of items) {
      if (!itemsByOrder.has(it.order_id)) itemsByOrder.set(it.order_id, []);
      itemsByOrder.get(it.order_id).push({ productId: it.product_id, productName: it.product_name, quantity: it.quantity, unitPrice: Number(it.unit_price), gstRate: Number(it.gst_rate), total: Number(it.total) });
    }
    return orders.map(o => {
      const shop = shopMap.get(shopKey(o.tenant_id, o.shop_id));
      const inv = invMap.get(shopKey(o.tenant_id, o.order_id));
      const lineItems = itemsByOrder.get(o.id) || (Array.isArray(o.items) ? o.items : []);
      return {
        id: o.id, orderId: o.order_id, orderNumber: o.order_id,
        tenantId: o.tenant_id, tenantName: tenantMap.get(o.tenant_id) || o.tenant_id,
        shopId: o.shop_id, shopName: shop?.shop_name || o.shop_id, ownerName: shop?.owner_name || '',
        phone: shop?.phone || '', address: shop?.address || '',
        salesmanName: staffMap.get(o.sales_person_uid) || '',
        subtotal: Number(o.subtotal || 0), totalGst: Number(o.total_gst || 0), grandTotal: Number(o.grand_total || 0),
        status: titleCase(o.status || 'confirmed'),
        paymentStatus: inv ? titleCase(inv.payment_status || 'unpaid') : 'Not billed',
        invoiceNumber: inv?.invoice_number || null,
        orderDate: o.order_date || o.created_at, notes: o.notes || '', items: lineItems,
      };
    });
  }

  async function platformSnapshot() {
    const [tenants, profiles, pricing, coupons, remoteConfig, broadcast, settings, printerRows, notifRows, stats, couponUse] = await Promise.all([
      db().select('tenants', 'select=*&order=created_at.desc'),
      db().select('profiles', 'select=id,name,email,phone,role,tenant_id,account_status,is_active,created_at,updated_at,last_login_at&order=created_at.desc'),
      getPricing(), getCoupons(), getRemoteConfig(), getBroadcast(), getGeneralSettings(),
      db().select('printer_hardware_orders', 'select=*&order=created_at.desc&limit=200'),
      db().select('notifications', 'select=*&order=created_at.desc&limit=100'),
      db().rpc('admin_platform_stats').catch(err => { console.warn('[stats]', err.message); return {}; }),
      db().select('subscription_checkouts', 'status=eq.paid&select=couponCode:quote->>couponCode').catch(() => []),
    ]);
    const used = {};
    for (const row of couponUse) { const code = row.couponCode; if (code) used[code] = (used[code] || 0) + 1; }
    const tenantNames = Object.fromEntries(tenants.map(t => [t.tenant_id, t.business_name]));
    return {
      tenants: tenants.map(t => mapTenant(t, pricing.plans, stats || {})),
      users: profiles.map(p => mapUser(p, tenantNames)),
      plans: pricing.plans,
      printerOptions: pricing.printerOptions,
      subscriptionAddons: pricing.subscriptionAddons,
      coupons: coupons.map(c => ({ ...c, usedCount: used[c.code] || 0 })),
      remoteConfig, broadcast, settings,
      printerOrders: printerRows.map(mapPrinterOrder),
      retailOrders: await loadRetailOrders(100),
      notifications: notifRows.map(mapNotification),
    };
  }

  async function findTenant(tenantId) {
    if (!SLUG_RE.test(tenantId || '')) fail(400, 'Invalid tenant id');
    const rows = await db().select('tenants', `tenant_id=eq.${enc(tenantId)}&select=*`);
    if (!rows.length) fail(404, 'Agency not found');
    return rows[0];
  }

  // ------------------------------------------------------------------
  // Accounts
  // ------------------------------------------------------------------
  function validateAccount(body, { requirePassword = true } = {}) {
    const email = str(body.email, 254).toLowerCase();
    const password = String(body.password || '');
    const name = str(body.name || body.representativeName || body.contactPerson || body.ownerName, 150);
    const phone = str(body.phone || body.mobile, 20);
    if (!EMAIL_RE.test(email)) fail(400, 'A valid email address is required.');
    if (requirePassword && (password.length < 8 || password.length > 72)) fail(400, 'Password must be 8-72 characters.');
    if (!name) fail(400, 'Name is required.');
    return { email, password, name, phone };
  }

  async function createAuthUser({ email, password, name, phone, role, tenantId }) {
    let created;
    try {
      created = await db().authAdmin('POST', 'admin/users', {
        email, password, email_confirm: true,
        user_metadata: { name, phone },
        app_metadata: { role, tenant_id: tenantId || null },
      });
    } catch (err) {
      if (/already|exists|registered/i.test(err.message)) fail(409, 'An account with this email already exists.');
      throw err;
    }
    if (!created?.id) fail(502, 'Authentication service did not create the account.');
    // handle_new_user inserted the profile from app_metadata; fill in details.
    await db().insert('profiles', {
      id: created.id, name, email, phone: phone || null, role, tenant_id: tenantId || null,
      account_status: 'active', is_active: true, updated_at: nowIso(),
    }, { onConflict: 'id', upsert: true, returning: false });
    return created.id;
  }

  async function deleteAuthUser(id) {
    try { await db().authAdmin('DELETE', `admin/users/${enc(id)}`); }
    catch (err) { if (err.details?.upstreamStatus !== 404) throw err; }
    await db().remove('profiles', `id=eq.${enc(id)}`).catch(() => {});
  }

  function slugTenantId(businessName) {
    const slug = businessName.toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '').slice(0, 24) || 'agency';
    return `tenant_${slug}_${crypto.randomUUID().replace(/-/g, '').slice(0, 8)}`;
  }

  async function createAgency(body, { byAdmin = false } = {}) {
    const account = validateAccount(body);
    const businessName = str(body.businessName || body.firmName, 255);
    if (!businessName) fail(400, 'Agency / business name is required.');
    if (!account.phone) fail(400, 'Mobile number is required.');
    const [settings, pricing] = await Promise.all([getGeneralSettings(), getPricing()]);
    let planId = settings.defaultPlanId || 'startup';
    let status = 'trial';
    if (byAdmin) {
      if (body.planId) planId = str(body.planId, 50);
      if (body.subscriptionStatus) status = str(body.subscriptionStatus, 30);
      if (!TENANT_STATUSES.includes(status)) fail(400, 'Invalid subscription status');
    }
    const tier = tierFor(pricing.plans, planId);
    if (!tier && planId !== 'free') fail(400, 'Unknown plan');
    const trialDays = Number(settings.defaultTrialDays ?? 14);
    const days = status === 'active' ? 365 : trialDays;
    const tenantId = slugTenantId(businessName);
    const tenantRow = {
      tenant_id: tenantId, business_name: businessName, contact_person: account.name, mobile: account.phone, email: account.email,
      gstin: str(body.gstin, 20).toUpperCase() || null, pan: str(body.pan, 20).toUpperCase() || null,
      address: str(body.address || body.warehouseAddress, 500) || null,
      city: str(body.city || body.territory, 100) || null, state: str(body.state, 100) || null,
      plan_id: planId, subscription_status: status,
      subscription_start_date: nowIso(),
      subscription_end_date: status === 'freemium' ? null : new Date(Date.now() + days * 86400000).toISOString(),
      max_users: tier?.maxUsers ?? 1, max_shops: tier?.maxShops ?? 200,
      is_active: status !== 'suspended',
    };
    await db().insert('tenants', tenantRow, { returning: false });
    let uid;
    try {
      uid = await createAuthUser({ ...account, role: 'owner', tenantId });
      await db().update('tenants', `tenant_id=eq.${enc(tenantId)}`, { owner_uid: uid });
    } catch (err) {
      await db().remove('tenants', `tenant_id=eq.${enc(tenantId)}`).catch(() => {});
      throw err;
    }
    return { tenantId, uid, tenant: tenantRow };
  }

  async function provisionStaff(ctx, body) {
    const caller = await requireUser(ctx);
    const isAdmin = caller.role === 'super_admin';
    if (!isAdmin && !['owner', 'distributor'].includes(caller.role)) fail(403, 'Only an agency owner or administrator can add staff.');
    const account = validateAccount(body);
    const role = canonicalRole(body.role || 'sales_person');
    const allowed = isAdmin ? ROLES : STAFF_ROLES;
    if (!allowed.includes(role)) fail(403, `You cannot assign the role "${role}".`);
    let tenantId = role === 'super_admin' ? null : str(body.tenantId || body.tenant_id, 64) || null;
    if (!isAdmin) tenantId = caller.tenant_id;
    if (role !== 'super_admin') {
      if (!tenantId) fail(400, 'Agency (tenant) is required for this role.');
      const tenant = await findTenant(tenantId);
      if (!isAdmin) {
        const members = await db().select('profiles', `tenant_id=eq.${enc(tenantId)}&is_active=eq.true&select=id`);
        if (tenant.max_users && members.length >= tenant.max_users) fail(409, `Your plan allows ${tenant.max_users} user(s). Upgrade to add more staff.`);
      }
    }
    const uid = await createAuthUser({ ...account, role, tenantId });
    await audit(ctx, 'SECURITY', 'USER_CREATED', `${account.email} created as ${role}${tenantId ? ` in ${tenantId}` : ''}`, { target: uid });
    return { uid, role, tenantId };
  }

  // ------------------------------------------------------------------
  // Routes
  // ------------------------------------------------------------------
  const routes = [];
  const route = (method, pattern, handler) => routes.push({ method, pattern, handler });

  // ---- Public -------------------------------------------------------
  route('GET', '/api/health', async () => json({ success: true, status: 'healthy', timestamp: nowIso() }));
  route('GET', '/api/platform/health', async () => {
    const started = Date.now();
    await db().select('platform_settings', 'select=id&limit=1');
    return json({ success: true, status: 'healthy', database: 'reachable', latencyMs: Date.now() - started, timestamp: nowIso() });
  });

  route('GET', '/api/config/supabase', async () => json({ success: true, supabaseUrl: cfg.url, supabaseAnonKey: cfg.anonKey }));

  route('GET', '/api/platform/public', async () => {
    const [pricing, remoteConfig, broadcast, settings] = await Promise.all([getPricing(), getRemoteConfig(), getBroadcast(), getGeneralSettings()]);
    return json({ success: true, timestamp: nowIso(), data: {
      ...pricing, remoteConfig, broadcast,
      settings: { supportPhone: settings.supportPhone || '', supportEmail: settings.supportEmail || '', companyName: settings.companyName || '' },
    } });
  });

  route('POST', '/api/auth/login', async ctx => {
    const body = await readJson(ctx.request);
    const email = str(body.email, 254).toLowerCase();
    const password = String(body.password || '');
    if (!email || !password) fail(400, 'Email and password are required.');
    if (!throttleLogin(`${email}|${ctx.ip || ''}`) || !throttleLogin(`email:${email}`)) fail(429, 'Too many sign-in attempts. Try again in 15 minutes.');
    let auth;
    try { auth = await db().passwordGrant(email, password); }
    catch (err) {
      if (err.status === 503) throw err;
      ctx.user = { email };
      await audit(ctx, 'SECURITY', 'LOGIN_FAILED', `Failed sign-in for ${email}`, { status: 'warning' });
      fail(401, 'Invalid email or password.');
    }
    const rows = await db().select('profiles', `id=eq.${enc(auth.user?.id)}&select=*`);
    const profile = rows[0];
    if (!profile || profile.is_active === false || profile.account_status !== 'active') fail(403, 'This account is not active. Contact your administrator.');
    let tenant = null;
    if (profile.tenant_id) tenant = (await db().select('tenants', `tenant_id=eq.${enc(profile.tenant_id)}&select=*`))[0] || null;
    await db().update('profiles', `id=eq.${enc(profile.id)}`, { last_login_at: nowIso() }).catch(() => {});
    if (profile.role === 'super_admin') {
      ctx.user = { id: profile.id, email };
      await audit(ctx, 'SECURITY', 'ADMIN_LOGIN', `Super admin signed in: ${email}`);
    }
    return json({
      success: true,
      token: auth.access_token, refreshToken: auth.refresh_token, expiresAt: auth.expires_at,
      user: {
        id: profile.id, uid: profile.id, name: profile.name, email: profile.email || email, phone: profile.phone,
        role: profile.role, tenantId: profile.tenant_id, tenant_id: profile.tenant_id, accountStatus: profile.account_status,
      },
      tenant,
    });
  });

  // Agency self-registration is public; staff accounts need an owner/admin.
  route('POST', '/api/auth/signup', async ctx => {
    const body = await readJson(ctx.request);
    const accountType = str(body.accountType || (body.businessName ? 'agency' : 'staff'), 20).toLowerCase();
    if (accountType === 'agency') {
      const token = bearer(ctx.request);
      if (token) ctx.user = await authenticate(ctx.request);
      const byAdmin = ctx.user?.role === 'super_admin';
      const result = await createAgency(body, { byAdmin });
      if (byAdmin) await audit(ctx, 'TENANT', 'TENANT_CREATED', `Agency ${result.tenant.business_name} (${result.tenantId}) created`, { target: result.tenantId });
      return json({ success: true, message: 'Agency registered.', tenant_id: result.tenantId, tenantId: result.tenantId, uid: result.uid, role: 'owner', tenant: result.tenant }, 201);
    }
    const result = await provisionStaff(ctx, body);
    return json({ success: true, message: 'Staff account created.', uid: result.uid, role: result.role, tenantId: result.tenantId, tenant_id: result.tenantId }, 201);
  });

  route('GET', '/api/auth/tenants', async ctx => {
    const user = await requireUser(ctx);
    const filter = user.role === 'super_admin' ? '' : `tenant_id=eq.${enc(user.tenant_id || '__none__')}&`;
    const rows = await db().select('tenants', `${filter}select=tenant_id,business_name,contact_person,city,plan_id,subscription_status&order=business_name.asc`);
    return json({ success: true, tenants: rows.map(t => ({ id: t.tenant_id, tenant_id: t.tenant_id, tenantId: t.tenant_id, business_name: t.business_name, businessName: t.business_name, contact_person: t.contact_person, city: t.city, planId: t.plan_id, subscriptionStatus: t.subscription_status })) });
  });

  // ---- Checkout (owners) ---------------------------------------------
  route('POST', '/api/checkout', async ctx => {
    const user = await requireUser(ctx);
    return json(await checkout().start(user, await readJson(ctx.request)));
  });
  route('GET', '/api/checkout', async ctx => {
    const user = await requireUser(ctx);
    return json(await checkout().status(user, ctx.url.searchParams.get('id') || ''));
  });
  route('POST', '/api/checkout/webhook', async ctx => {
    const raw = await ctx.request.text();
    if (raw.length > MAX_BODY) fail(413, 'Payload too large');
    try {
      const result = await checkout().webhook(raw, ctx.request.headers.get('x-razorpay-signature'), cfg.razorpayWebhookSecret);
      await audit(ctx, 'BILLING', 'WEBHOOK_PROCESSED', `Razorpay webhook processed${result?.ignored ? ` (ignored ${result.ignored})` : ''}`);
      return json({ success: true });
    } catch (err) {
      await audit(ctx, 'BILLING', 'WEBHOOK_REJECTED', err.message, { status: 'warning' });
      throw err;
    }
  });

  // ---- Admin: aggregate state ---------------------------------------
  route('GET', '/api/platform/all', async ctx => {
    await requireAdmin(ctx);
    const data = await platformSnapshot();
    return json({ success: true, timestamp: nowIso(), data });
  });
  route('GET', '/api/platform/tenants', async ctx => {
    await requireAdmin(ctx);
    const [rows, pricing, stats] = await Promise.all([
      db().select('tenants', 'select=*&order=created_at.desc'), getPricing(), db().rpc('admin_platform_stats').catch(() => ({})),
    ]);
    return json({ success: true, tenants: rows.map(t => mapTenant(t, pricing.plans, stats)) });
  });
  route('GET', '/api/platform/users', async ctx => {
    await requireAdmin(ctx);
    const [profiles, tenants] = await Promise.all([
      db().select('profiles', 'select=*&order=created_at.desc'), db().select('tenants', 'select=tenant_id,business_name'),
    ]);
    const names = Object.fromEntries(tenants.map(t => [t.tenant_id, t.business_name]));
    return json({ success: true, users: profiles.map(p => mapUser(p, names)) });
  });

  // ---- Admin: tenants ------------------------------------------------
  async function updateTenant(ctx, body) {
    const tid = str(body.id || body.tenantId || body.tenant_id, 64);
    const current = await findTenant(tid);
    const pricing = await getPricing();
    const patch = {};
    const pick = (keys, column, max = 255, transform = v => v) => {
      for (const k of keys) if (body[k] !== undefined) { patch[column] = transform(str(body[k], max)) || null; return; }
    };
    pick(['firmName', 'business_name', 'businessName'], 'business_name');
    pick(['ownerName', 'contact_person', 'representativeName'], 'contact_person', 150);
    pick(['phone', 'mobile'], 'mobile', 20);
    pick(['email'], 'email', 254, v => v.toLowerCase());
    pick(['gstin'], 'gstin', 20, v => v.toUpperCase());
    pick(['pan'], 'pan', 20, v => v.toUpperCase());
    pick(['address', 'warehouseAddress'], 'address', 500);
    pick(['city', 'territory'], 'city', 100);
    pick(['state'], 'state', 100);
    if (patch.business_name === null) fail(400, 'Agency name cannot be empty');
    if (patch.mobile === null) fail(400, 'Mobile number cannot be empty');
    if (patch.email && !EMAIL_RE.test(patch.email)) fail(400, 'Invalid email');

    const planId = body.subscriptionPlanId ?? body.plan_id ?? body.planId;
    if (planId !== undefined) {
      const p = str(planId, 50);
      const tier = tierFor(pricing.plans, p);
      if (!tier && p !== 'free') fail(400, `Unknown plan "${p}"`);
      if (p !== current.plan_id) {
        // Plan change resets limits to the tier's quota unless overridden below.
        patch.plan_id = p;
        patch.max_users = tier?.maxUsers ?? 1;
        patch.max_shops = tier?.maxShops ?? 200;
      }
    }
    const limit = v => { const n = parseInt(v, 10); if (!Number.isInteger(n) || n < 1 || n > 10000000) fail(400, 'Limits must be positive whole numbers'); return n; };
    const users = body.maxUsers ?? body.max_users;
    const shops = body.maxShops ?? body.max_shops;
    if (users !== undefined && users !== null && users !== '' && Number(users) !== current.max_users) patch.max_users = limit(users);
    if (shops !== undefined && shops !== null && shops !== '' && Number(shops) !== current.max_shops) patch.max_shops = limit(shops);

    const status = body.subscriptionStatus ?? body.subscription_status;
    if (status !== undefined) {
      if (!TENANT_STATUSES.includes(status)) fail(400, 'Invalid subscription status');
      patch.subscription_status = status;
      patch.is_active = status !== 'suspended';
    }
    if (body.isSuspended !== undefined) {
      patch.is_active = !body.isSuspended;
      if (body.isSuspended) patch.subscription_status = 'suspended';
      else if (current.subscription_status === 'suspended' && status === undefined) patch.subscription_status = 'active';
    }
    const end = body.subscription_end_date !== undefined ? body.subscription_end_date : body.expiryDate;
    if (end !== undefined) {
      if (end === null || end === '' || /never/i.test(String(end))) patch.subscription_end_date = null;
      else {
        const d = new Date(String(end).length <= 10 ? `${end}T23:59:59+05:30` : end);
        if (Number.isNaN(d.getTime())) fail(400, 'Invalid expiry date');
        patch.subscription_end_date = d.toISOString();
      }
    }
    if (body.extendDays !== undefined) {
      const days = parseInt(body.extendDays, 10);
      if (!Number.isInteger(days) || days < 1 || days > 3650) fail(400, 'extendDays must be 1-3650');
      const base = Math.max(Date.now(), current.subscription_end_date ? new Date(current.subscription_end_date).getTime() : 0);
      patch.subscription_end_date = new Date(base + days * 86400000).toISOString();
      if (status === undefined && ['expired', 'freemium'].includes(current.subscription_status)) patch.subscription_status = 'trial';
      patch.is_active = patch.is_active ?? true;
    }
    if (!Object.keys(patch).length) fail(400, 'Nothing to update');
    patch.updated_at = nowIso();
    const [row] = await db().update('tenants', `tenant_id=eq.${enc(tid)}`, patch);
    const changed = Object.keys(patch).filter(k => k !== 'updated_at').join(', ');
    await audit(ctx, 'TENANT', 'TENANT_UPDATED', `${current.business_name} (${tid}): ${changed}`, { target: tid });
    return mapTenant(row, pricing.plans);
  }
  for (const p of ['/api/platform/sync-tenant', '/api/platform/tenant']) {
    route('POST', p, async ctx => {
      await requireAdmin(ctx);
      return json({ success: true, tenant: await updateTenant(ctx, await readJson(ctx.request)) });
    });
  }
  route('DELETE', /^\/api\/platform\/tenant\/([^/]+)$/, async (ctx, [rawId]) => {
    await requireAdmin(ctx);
    const tenant = await findTenant(decodeURIComponent(rawId));
    if (ctx.url.searchParams.get('confirm') !== tenant.tenant_id) fail(400, 'Confirm deletion by passing ?confirm=<tenant id>.');
    const members = await db().select('profiles', `tenant_id=eq.${enc(tenant.tenant_id)}&select=id,role`);
    for (const m of members) if (m.role !== 'super_admin') await deleteAuthUser(m.id);
    await db().remove('tenants', `tenant_id=eq.${enc(tenant.tenant_id)}`);
    await audit(ctx, 'TENANT', 'TENANT_DELETED', `${tenant.business_name} (${tenant.tenant_id}) and ${members.length} user account(s) deleted`, { target: tenant.tenant_id, status: 'warning' });
    return json({ success: true, deleted: tenant.tenant_id, usersDeleted: members.length });
  });
  route('GET', /^\/api\/platform\/tenant\/([^/]+)\/overview$/, async (ctx, [rawId]) => {
    await requireAdmin(ctx);
    const tenant = await findTenant(decodeURIComponent(rawId));
    const q = `tenant_id=eq.${enc(tenant.tenant_id)}`;
    const [shops, products, invoices, payments, ledger, staff, checkouts, orders] = await Promise.all([
      db().select('shops', `${q}&select=*&order=created_at.desc&limit=200`),
      db().select('products', `${q}&select=*&order=name.asc&limit=200`),
      db().select('invoices', `${q}&select=*&order=invoice_date.desc&limit=100`),
      db().select('payments', `${q}&select=*&order=payment_date.desc&limit=100`),
      db().select('ledger_entries', `${q}&select=*&order=created_at.desc&limit=100`),
      db().select('profiles', `${q}&select=id,name,email,phone,role,account_status,is_active,last_login_at`),
      db().select('subscription_checkouts', `${q}&select=id,status,amount,quote,created_at,paid_at&order=created_at.desc&limit=20`),
      loadRetailOrders(100, tenant.tenant_id),
    ]);
    return json({ success: true, tenant, shops, products, orders, invoices, payments, ledger, staff, checkouts });
  });

  // ---- Admin: users -------------------------------------------------
  route('POST', '/api/platform/sync-user', async ctx => {
    const admin = await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const id = str(body.id || body.uid, 64);
    if (!UUID_RE.test(id)) {
      const result = await provisionStaff(ctx, body);
      return json({ success: true, created: true, user: { id: result.uid, uid: result.uid, role: result.role, tenantId: result.tenantId } }, 201);
    }
    const rows = await db().select('profiles', `id=eq.${enc(id)}&select=*`);
    if (!rows.length) fail(404, 'User not found');
    const current = rows[0];
    const patch = {};
    if (body.name !== undefined) patch.name = str(body.name, 150) || fail(400, 'Name cannot be empty');
    if (body.phone !== undefined) patch.phone = str(body.phone, 20) || null;
    if (body.role !== undefined) {
      const role = canonicalRole(body.role);
      if (!ROLES.includes(role)) fail(400, 'Invalid role');
      if (id === admin.id && role !== 'super_admin') fail(400, 'You cannot remove your own Super Admin role.');
      patch.role = role;
    }
    if (body.tenantId !== undefined || body.tenant_id !== undefined) {
      const tid = str(body.tenantId ?? body.tenant_id, 64) || null;
      if (tid) await findTenant(tid);
      patch.tenant_id = tid;
    }
    if ((patch.role ?? current.role) !== 'super_admin' && !(patch.tenant_id ?? current.tenant_id)) fail(400, 'Non-admin users must belong to an agency.');
    const status = body.status ?? body.accountStatus;
    if (status !== undefined) {
      if (!['active', 'suspended', 'inactive', 'pending'].includes(status)) fail(400, 'Invalid status');
      if (id === admin.id && status !== 'active') fail(400, 'You cannot suspend your own account.');
      patch.account_status = status === 'inactive' ? 'suspended' : status;
      patch.is_active = status === 'active';
    }
    const email = body.email !== undefined ? str(body.email, 254).toLowerCase() : undefined;
    if (email !== undefined && !EMAIL_RE.test(email)) fail(400, 'Invalid email');
    if (email && email !== current.email) patch.email = email;
    if (!Object.keys(patch).length) fail(400, 'Nothing to update');

    const authPatch = {};
    if (patch.email) { authPatch.email = patch.email; authPatch.email_confirm = true; }
    if (patch.role || patch.tenant_id !== undefined) authPatch.app_metadata = { role: patch.role ?? current.role, tenant_id: patch.tenant_id !== undefined ? patch.tenant_id : current.tenant_id };
    if (patch.name) authPatch.user_metadata = { name: patch.name };
    if (patch.is_active !== undefined) authPatch.ban_duration = patch.is_active ? 'none' : '876000h';
    if (Object.keys(authPatch).length) await db().authAdmin('PUT', `admin/users/${enc(id)}`, authPatch);
    patch.updated_at = nowIso();
    const [row] = await db().update('profiles', `id=eq.${enc(id)}`, patch);
    await audit(ctx, 'SECURITY', 'USER_UPDATED', `${row.email}: ${Object.keys(patch).filter(k => k !== 'updated_at').join(', ')}`, { target: id });
    return json({ success: true, user: mapUser(row, {}) });
  });
  route('DELETE', /^\/api\/platform\/user\/([^/]+)$/, async (ctx, [rawId]) => {
    const admin = await requireAdmin(ctx);
    const id = decodeURIComponent(rawId);
    if (!UUID_RE.test(id)) fail(400, 'Invalid user id');
    if (id === admin.id) fail(400, 'You cannot delete your own account.');
    const rows = await db().select('profiles', `id=eq.${enc(id)}&select=email,role`);
    await deleteAuthUser(id);
    await audit(ctx, 'SECURITY', 'USER_DELETED', `${rows[0]?.email || id} deleted`, { target: id, status: 'warning' });
    return json({ success: true, deleted: id });
  });
  route('POST', '/api/platform/user/reset-password', async ctx => {
    const caller = await requireUser(ctx);
    const body = await readJson(ctx.request);
    const userId = str(body.userId, 64);
    const newPassword = String(body.newPassword || '');
    if (!UUID_RE.test(userId)) fail(400, 'Invalid user id');
    if (newPassword.length < 8 || newPassword.length > 72) fail(400, 'Password must be 8-72 characters.');
    if (caller.role !== 'super_admin') {
      // Owners may reset passwords of their own staff; anyone may reset their own.
      if (userId !== caller.id) {
        if (!['owner', 'distributor'].includes(caller.role)) fail(403, 'Not allowed.');
        const target = (await db().select('profiles', `id=eq.${enc(userId)}&select=tenant_id,role`))[0];
        if (!target || target.tenant_id !== caller.tenant_id || !STAFF_ROLES.includes(target.role)) fail(403, 'You can only reset passwords of your own staff.');
      }
    }
    await db().authAdmin('PUT', `admin/users/${enc(userId)}`, { password: newPassword });
    await audit(ctx, 'SECURITY', 'PASSWORD_RESET', `Password reset for user ${userId}`, { target: userId });
    return json({ success: true, message: 'Password updated.' });
  });

  // ---- Admin: catalog, coupons, config -------------------------------
  route('POST', '/api/platform/update', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const allowed = ['plans', 'printerOptions', 'subscriptionAddons', 'coupons', 'remoteConfig', 'broadcast', 'settings'];
    const keys = Object.keys(body).filter(k => allowed.includes(k));
    const rejected = Object.keys(body).filter(k => !allowed.includes(k));
    if (rejected.length) fail(400, `Use the dedicated endpoints for: ${rejected.join(', ')}`);
    if (!keys.length) fail(400, 'Nothing to update');
    if (body.plans || body.printerOptions || body.subscriptionAddons) {
      const pricing = await getPricing();
      if (body.plans) pricing.plans = normalizePlans(body.plans);
      if (body.printerOptions) {
        if (!Array.isArray(body.printerOptions)) fail(400, 'printerOptions must be an array');
        pricing.printerOptions = body.printerOptions.map(normalizePrinter);
      }
      if (body.subscriptionAddons) {
        if (!Array.isArray(body.subscriptionAddons)) fail(400, 'subscriptionAddons must be an array');
        pricing.subscriptionAddons = body.subscriptionAddons.map(normalizeAddon);
      }
      await savePricing(pricing);
    }
    if (body.coupons) await saveCoupons(normalizeCoupons(body.coupons));
    if (body.remoteConfig) await putSetting('remote_config', normalizeRemoteConfig(body.remoteConfig, await getRemoteConfig()));
    if (body.broadcast) await putSetting('broadcast', normalizeBroadcast(body.broadcast, await getBroadcast()));
    if (body.settings) await putSetting('general_settings', normalizeSettings(body.settings, await getGeneralSettings()));
    await audit(ctx, 'CONFIG', 'PLATFORM_UPDATED', `Updated ${keys.join(', ')}`);
    return json({ success: true, updated: keys });
  });

  route('POST', '/api/platform/coupon', async ctx => {
    await requireAdmin(ctx);
    const coupon = normalizeCoupon(await readJson(ctx.request));
    const coupons = await getCoupons();
    const idx = coupons.findIndex(c => c.id === coupon.id || c.code === coupon.code);
    if (idx >= 0) coupons[idx] = { ...coupon, createdAt: coupons[idx].createdAt || coupon.createdAt };
    else coupons.unshift(coupon);
    await saveCoupons(normalizeCoupons(coupons));
    await audit(ctx, 'BILLING', idx >= 0 ? 'COUPON_UPDATED' : 'COUPON_CREATED', `${coupon.code} (${coupon.type} ${coupon.value})`, { target: coupon.code });
    return json({ success: true, coupon });
  });
  route('DELETE', /^\/api\/platform\/coupon\/([^/]+)$/, async (ctx, [raw]) => {
    await requireAdmin(ctx);
    const key = decodeURIComponent(raw);
    const coupons = await getCoupons();
    const next = coupons.filter(c => c.code !== key.toUpperCase() && c.id !== key);
    if (next.length === coupons.length) fail(404, 'Coupon not found');
    await saveCoupons(next);
    await audit(ctx, 'BILLING', 'COUPON_DELETED', key, { target: key });
    return json({ success: true, deleted: key });
  });

  async function upsertCatalogItem(ctx, listKey, normalize, label) {
    await requireAdmin(ctx);
    const item = normalize(await readJson(ctx.request));
    const pricing = await getPricing();
    const items = [...pricing[listKey]];
    const idx = items.findIndex(x => x.id === item.id);
    if (idx >= 0) items[idx] = item; else items.push(item);
    if (listKey === 'printerOptions') {
      if (item.isDefault) items.forEach(p => { p.isDefault = p.id === item.id; });
      if (!items.some(p => p.isDefault) && items.length) items[0].isDefault = true;
    }
    pricing[listKey] = items;
    await savePricing(pricing);
    await audit(ctx, 'CONFIG', `${label}_SAVED`, `${item.name || item.title} (${item.id})`, { target: item.id });
    return item;
  }
  async function deleteCatalogItem(ctx, listKey, rawId, label) {
    await requireAdmin(ctx);
    const itemId = decodeURIComponent(rawId);
    const pricing = await getPricing();
    const items = pricing[listKey].filter(x => x.id !== itemId);
    if (items.length === pricing[listKey].length) fail(404, 'Item not found');
    if (listKey === 'printerOptions' && items.length && !items.some(p => p.isDefault)) items[0].isDefault = true;
    pricing[listKey] = items;
    await savePricing(pricing);
    await audit(ctx, 'CONFIG', `${label}_DELETED`, itemId, { target: itemId });
    return itemId;
  }
  route('POST', '/api/platform/printer-option', async ctx => json({ success: true, printerOption: await upsertCatalogItem(ctx, 'printerOptions', normalizePrinter, 'PRINTER_OPTION') }));
  route('DELETE', /^\/api\/platform\/printer-option\/([^/]+)$/, async (ctx, [id]) => json({ success: true, deleted: await deleteCatalogItem(ctx, 'printerOptions', id, 'PRINTER_OPTION') }));
  route('POST', '/api/platform/subscription-addon', async ctx => json({ success: true, subscriptionAddon: await upsertCatalogItem(ctx, 'subscriptionAddons', normalizeAddon, 'ADDON') }));
  route('DELETE', /^\/api\/platform\/subscription-addon\/([^/]+)$/, async (ctx, [id]) => json({ success: true, deleted: await deleteCatalogItem(ctx, 'subscriptionAddons', id, 'ADDON') }));

  route('POST', '/api/platform/settings', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const settings = normalizeSettings(body.data && body.id === 'general_settings' ? body.data : body, await getGeneralSettings());
    if (settings.defaultPlanId && settings.defaultPlanId !== 'free' && !tierFor((await getPricing()).plans, settings.defaultPlanId)) fail(400, 'Default plan does not exist');
    settings.updatedAt = nowIso();
    await putSetting('general_settings', settings);
    await audit(ctx, 'CONFIG', 'SETTINGS_UPDATED', 'General platform settings saved');
    return json({ success: true, settings });
  });

  route('GET', '/api/platform/remote-config', async ctx => {
    await requireAdmin(ctx);
    const config = await getRemoteConfig();
    return json({ success: true, config, featureFlags: config.featureFlags });
  });
  route('POST', '/api/platform/remote-config', async ctx => {
    await requireAdmin(ctx);
    const config = normalizeRemoteConfig(await readJson(ctx.request), await getRemoteConfig());
    await putSetting('remote_config', config);
    await audit(ctx, 'CONFIG', 'REMOTE_CONFIG_UPDATED', `Maintenance ${config.maintenance?.active ? 'ON' : 'off'}; disabled modules: ${Object.entries(config.featureFlags).filter(([, v]) => !v).map(([k]) => k).join(', ') || 'none'}`);
    return json({ success: true, config });
  });

  route('GET', '/api/platform/broadcast', async ctx => { await requireAdmin(ctx); return json({ success: true, broadcast: await getBroadcast() }); });
  route('POST', '/api/platform/broadcast', async ctx => {
    await requireAdmin(ctx);
    const broadcast = normalizeBroadcast(await readJson(ctx.request), await getBroadcast());
    await putSetting('broadcast', broadcast);
    await audit(ctx, 'BROADCAST', broadcast.active ? 'BROADCAST_PUBLISHED' : 'BROADCAST_CLEARED', broadcast.active ? `${broadcast.severity}: ${broadcast.title || broadcast.message}` : 'Banner removed');
    return json({ success: true, broadcast });
  });

  // ---- Admin: notifications -----------------------------------------
  route('GET', '/api/platform/notifications', async ctx => {
    await requireAdmin(ctx);
    const rows = await db().select('notifications', 'select=*&order=created_at.desc&limit=200');
    return json({ success: true, count: rows.length, notifications: rows.map(mapNotification) });
  });
  route('POST', '/api/platform/notifications', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const title = str(body.title, 255);
    const message = str(body.message, 2000);
    if (!title || !message) fail(400, 'Title and message are required');
    const targetTenant = str(body.targetTenant || body.tenantId, 64) || 'all';
    if (targetTenant !== 'all') await findTenant(targetTenant);
    const targetRole = canonicalRole(body.targetRole || 'all') || 'all';
    if (targetRole !== 'all' && !ROLES.includes(targetRole)) fail(400, 'Invalid target role');
    const severity = ['info', 'warning', 'critical', 'success', 'promo'].includes(body.severity) ? body.severity : 'info';
    const actionUrl = str(body.actionUrl, 300);
    if (actionUrl && !/^(https:\/\/|\/)/i.test(actionUrl)) fail(400, 'Action URL must be https:// or an in-app path');
    const row = {
      notification_id: `notif_${crypto.randomUUID()}`,
      tenant_id: targetTenant === 'all' ? null : targetTenant,
      target_role: targetRole, type: str(body.type || body.category || 'broadcast', 50),
      title, message, data: { severity, actionUrl, targetPlan: str(body.targetPlan, 40) || 'all' },
      is_read: false, is_broadcast: targetTenant === 'all', created_by: ctx.user.email,
    };
    const [saved] = await db().insert('notifications', row);
    await audit(ctx, 'BROADCAST', 'NOTIFICATION_SENT', `${title} → ${targetTenant}/${targetRole}`, { target: saved.notification_id });
    return json({ success: true, notification: mapNotification(saved) }, 201);
  });
  route('DELETE', /^\/api\/platform\/notifications\/([^/]+)$/, async (ctx, [raw]) => {
    await requireAdmin(ctx);
    const nid = decodeURIComponent(raw);
    const removed = await db().remove('notifications', `notification_id=eq.${enc(nid)}`);
    if (!removed.length) fail(404, 'Notification not found');
    await audit(ctx, 'BROADCAST', 'NOTIFICATION_DELETED', nid, { target: nid });
    return json({ success: true, id: nid });
  });

  // ---- Admin: hardware fulfilment -----------------------------------
  for (const p of ['/api/platform/order-hardware', '/api/platform/hardware-orders']) {
    route('POST', p, async ctx => {
      await requireAdmin(ctx);
      const body = await readJson(ctx.request);
      const tenant = await findTenant(str(body.tenantId || body.userId, 64));
      const pricing = await getPricing();
      const printer = pricing.printerOptions.find(x => x.id === body.printerId || x.name === body.printerItem);
      if (!printer) fail(400, 'Select a printer model from the catalog');
      const qty = Math.min(100, Math.max(1, parseInt(body.quantity || 1, 10) || 1));
      const unit = Math.round(printer.price * (1 + (printer.gstRate ?? 18) / 100) * 100) / 100;
      const address = str(body.shippingAddress, 500);
      if (address.length < 10) fail(400, 'A full shipping address is required');
      const row = {
        order_id: `HW-${Date.now().toString(36).toUpperCase()}-${crypto.randomUUID().slice(0, 4).toUpperCase()}`,
        tenant_id: tenant.tenant_id, business_name: tenant.business_name,
        contact_person: str(body.customerName, 150) || tenant.contact_person || '',
        phone: str(body.phone, 20) || tenant.mobile, shipping_address: address,
        printer_model: printer.name, quantity: qty, unit_price: unit, total_amount: Math.round(unit * qty * 100) / 100,
        payment_status: ['paid', 'pending', 'cod'].includes(body.paymentStatus) ? body.paymentStatus : 'pending',
        fulfillment_status: 'processing', notes: str(body.notes, 500) || null,
      };
      const [saved] = await db().insert('printer_hardware_orders', row);
      await audit(ctx, 'HARDWARE', 'HARDWARE_ORDER_CREATED', `${row.printer_model} x${qty} for ${tenant.business_name}`, { target: row.order_id });
      return json({ success: true, order: mapPrinterOrder(saved) }, 201);
    });
  }
  route('POST', '/api/platform/printer-order/status', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const orderId = str(body.orderId, 64);
    if (!SLUG_RE.test(orderId)) fail(400, 'Invalid order id');
    const patch = { updated_at: nowIso() };
    if (body.status !== undefined) {
      const st = String(body.status).toLowerCase().replace(/\s+/g, '_');
      const status = st === 'dispatched' ? 'shipped' : st;
      if (!HARDWARE_STATUSES.includes(status)) fail(400, 'Invalid fulfilment status');
      patch.fulfillment_status = status;
    }
    if (body.courierName !== undefined) patch.courier_name = str(body.courierName, 60) || null;
    if (body.trackingNumber !== undefined) patch.tracking_number = str(body.trackingNumber, 100) || null;
    if (body.paymentStatus !== undefined) {
      if (!['paid', 'pending', 'cod', 'refunded'].includes(body.paymentStatus)) fail(400, 'Invalid payment status');
      patch.payment_status = body.paymentStatus;
    }
    const rows = await db().update('printer_hardware_orders', `order_id=eq.${enc(orderId)}`, patch);
    if (!rows.length) fail(404, 'Hardware order not found');
    await audit(ctx, 'HARDWARE', 'HARDWARE_ORDER_UPDATED', `${orderId}: ${Object.keys(patch).filter(k => k !== 'updated_at').join(', ')}`, { target: orderId });
    return json({ success: true, order: mapPrinterOrder(rows[0]) });
  });

  // ---- Admin: retail orders -----------------------------------------
  route('GET', '/api/platform/retail-orders', async ctx => {
    await requireAdmin(ctx);
    const tenantId = ctx.url.searchParams.get('tenantId');
    if (tenantId) await findTenant(tenantId);
    let orders = await loadRetailOrders(500, tenantId);
    const status = (ctx.url.searchParams.get('status') || '').toLowerCase();
    if (status && status !== 'all') orders = orders.filter(o => o.status.toLowerCase() === status);
    return json({ success: true, count: orders.length, orders });
  });
  route('POST', '/api/platform/retail-orders/status', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const id = str(body.id || body.orderUuid || body.orderId, 64);
    if (!UUID_RE.test(id)) fail(400, 'Invalid order id');
    const status = String(body.status || '').toLowerCase();
    if (!ORDER_STATUSES.includes(status)) fail(400, `Status must be one of: ${ORDER_STATUSES.join(', ')}`);
    const rows = await db().update('orders', `id=eq.${enc(id)}`, { status, updated_at: nowIso() });
    if (!rows.length) fail(404, 'Order not found');
    await audit(ctx, 'ORDERS', 'ORDER_STATUS_UPDATED', `${rows[0].order_id} (${rows[0].tenant_id}) → ${status}`, { target: id });
    return json({ success: true, order: { id, status: titleCase(status) } });
  });
  for (const p of ['/api/platform/sync-order', '/api/platform/retail-orders']) {
    route('POST', p, async ctx => {
      await requireAdmin(ctx);
      const body = await readJson(ctx.request);
      const tenant = await findTenant(str(body.tenantId, 64));
      if (!Array.isArray(body.items) || !body.items.length || body.items.length > 200) fail(400, 'Add 1-200 line items');
      let subtotal = 0, gst = 0;
      const items = body.items.map((it, i) => {
        const qty = Number(it.quantity), price = Number(it.unitPrice), rate = Number(it.gstRate ?? 0);
        const name = str(it.productName, 255);
        if (!name || !Number.isInteger(qty) || qty <= 0 || !Number.isFinite(price) || price < 0 || ![0, 5, 12, 18, 28].includes(rate)) fail(400, `Invalid line item ${i + 1}`);
        const taxable = Math.round(qty * price * 100) / 100, tax = Math.round(taxable * rate) / 100;
        subtotal += taxable; gst += tax;
        return { product_id: str(it.productId, 64) || `admin_item_${i + 1}`, product_name: name, quantity: qty, unit_price: price, gst_rate: rate, taxable_amount: taxable, gst_amount: tax, total: Math.round((taxable + tax) * 100) / 100 };
      });
      const status = String(body.status || 'confirmed').toLowerCase();
      if (!ORDER_STATUSES.includes(status)) fail(400, 'Invalid order status');
      const shopName = str(body.shopName, 255) || 'Walk-in customer';
      const orderId = str(body.orderNumber, 64) || `ADM-${Date.now().toString(36).toUpperCase()}`;
      if (!SLUG_RE.test(orderId)) fail(400, 'Order number may contain letters, digits, - and _ only');
      const shopId = str(body.shopId, 64) || `admin_${shopName.toLowerCase().replace(/[^a-z0-9]+/g, '_').slice(0, 40)}`;
      const notes = [
        `Admin order for ${shopName}`, body.ownerName && `Owner: ${str(body.ownerName, 100)}`, body.phone && `Phone: ${str(body.phone, 20)}`,
        body.address && `Address: ${str(body.address, 300)}`, body.paymentMethod && `Payment: ${str(body.paymentMethod, 30)}`, body.notes && str(body.notes, 500),
      ].filter(Boolean).join(' | ');
      const [order] = await db().insert('orders', {
        order_id: orderId, tenant_id: tenant.tenant_id, shop_id: shopId, status, notes,
        subtotal: Math.round(subtotal * 100) / 100, total_gst: Math.round(gst * 100) / 100,
        grand_total: Math.round((subtotal + gst) * 100) / 100, items: items.map(i => ({ productName: i.product_name, quantity: i.quantity, unitPrice: i.unit_price, gstRate: i.gst_rate, total: i.total })),
      });
      try {
        await db().insert('order_items', items.map(i => ({ ...i, order_id: order.id })), { returning: false });
      } catch (err) {
        await db().remove('orders', `id=eq.${enc(order.id)}`).catch(() => {});
        throw err;
      }
      await audit(ctx, 'ORDERS', 'ORDER_CREATED', `${orderId} for ${tenant.business_name} (₹${order.grand_total})`, { target: order.id });
      return json({ success: true, order: { id: order.id, orderNumber: orderId } }, 201);
    });
  }
  route('DELETE', /^\/api\/platform\/retail-orders\/([^/]+)$/, async (ctx, [raw]) => {
    await requireAdmin(ctx);
    const id = decodeURIComponent(raw);
    if (!UUID_RE.test(id)) fail(400, 'Invalid order id');
    const [order] = await db().select('orders', `id=eq.${enc(id)}&select=order_id,tenant_id`);
    if (!order) fail(404, 'Order not found');
    const billed = await db().select('invoices', `tenant_id=eq.${enc(order.tenant_id)}&order_id=eq.${enc(order.order_id)}&cancelled_at=is.null&select=invoice_id`);
    if (billed.length) fail(409, 'This order has an active invoice. Cancel the invoice in the agency app first.');
    await db().remove('orders', `id=eq.${enc(id)}`);
    await audit(ctx, 'ORDERS', 'ORDER_DELETED', `${order.order_id} (${order.tenant_id})`, { target: id, status: 'warning' });
    return json({ success: true, id });
  });

  // ---- Admin: subscriptions & billing -------------------------------
  route('GET', '/api/platform/subscriptions', async ctx => {
    await requireAdmin(ctx);
    const soon = new Date(Date.now() - 30 * 86400000).toISOString();
    const [pending, paid, renewals] = await Promise.all([
      db().select('subscription_checkouts', 'status=eq.pending&select=*&order=created_at.desc&limit=100'),
      db().select('subscription_checkouts', 'status=eq.paid&select=*&order=paid_at.desc&limit=50'),
      db().select('tenants', `subscription_end_date=gte.${enc(soon)}&select=tenant_id,business_name,plan_id,subscription_status,subscription_end_date&order=subscription_end_date.asc&limit=200`),
    ]);
    const stale = Date.now() - 72 * 3600 * 1000;
    return json({
      success: true,
      pending: pending.filter(p => new Date(p.created_at).getTime() >= stale),
      expired: pending.filter(p => new Date(p.created_at).getTime() < stale),
      paid, renewals, failed: [],
    });
  });
  route('POST', '/api/platform/subscriptions/settle', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const checkoutId = str(body.checkoutId, 64);
    const reference = str(body.paymentReference || body.paymentId, 100);
    if (!UUID_RE.test(checkoutId)) fail(400, 'Invalid checkout id');
    if (!reference) fail(400, 'Payment reference (UTR / transaction id) is required');
    const mode = ['upi', 'bank', 'cash', 'cheque', 'manual'].includes(body.paymentMode) ? body.paymentMode : 'manual';
    const result = await db().rpc('admin_settle_checkout_manual', { p_id: checkoutId, p_reference: reference, p_mode: mode });
    await audit(ctx, 'BILLING', 'CHECKOUT_SETTLED_MANUALLY', `${checkoutId} settled via ${mode} ref ${reference}`, { target: checkoutId });
    return json({ success: true, result });
  });

  // ---- Admin: payment gateway ---------------------------------------
  async function gatewayView() {
    const stored = (await getSetting('gateway_config')) || {};
    return {
      provider: 'razorpay',
      mode: cfg.razorpayKeyId.startsWith('rzp_live_') ? 'live' : 'test',
      keyId: cfg.razorpayKeyId,
      hasSecret: Boolean(cfg.razorpayKeySecret),
      hasWebhookSecret: Boolean(cfg.razorpayWebhookSecret),
      managedBy: 'environment',
      autoCapture: stored.autoCapture !== false,
      currency: 'INR',
      upiVpa: stored.upiVpa || '',
      merchantName: stored.merchantName || '',
      lastTested: stored.lastTested || null,
      testStatus: stored.testStatus || 'untested',
      webhookUrl: '/api/checkout/webhook',
    };
  }
  route('GET', '/api/platform/gateway/config', async ctx => { await requireAdmin(ctx); return json({ success: true, config: await gatewayView() }); });
  route('POST', '/api/platform/gateway/config', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    if (body.keySecret || body.webhookSecret || (body.keyId && body.keyId !== cfg.razorpayKeyId)) {
      fail(400, 'Razorpay keys are configured as server secrets (RAZORPAY_KEY_ID, RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET), not in the database.');
    }
    const stored = (await getSetting('gateway_config')) || {};
    const next = {
      ...stored,
      autoCapture: body.autoCapture !== false,
      upiVpa: body.upiVpa !== undefined ? str(body.upiVpa, 100) : stored.upiVpa || '',
      merchantName: body.merchantName !== undefined ? str(body.merchantName, 150) : stored.merchantName || '',
    };
    await putSetting('gateway_config', next);
    await audit(ctx, 'GATEWAY', 'GATEWAY_CONFIG_UPDATED', 'Gateway display settings saved');
    return json({ success: true, config: await gatewayView() });
  });
  route('POST', '/api/platform/gateway/test', async ctx => {
    await requireAdmin(ctx);
    const started = Date.now();
    let ok = false, message;
    try {
      await gateway('GET', 'payments?count=1');
      ok = true; message = `Razorpay accepted the configured credentials (${Date.now() - started}ms).`;
    } catch (err) { message = err.message; }
    const stored = (await getSetting('gateway_config')) || {};
    await putSetting('gateway_config', { ...stored, lastTested: nowIso(), testStatus: ok ? 'connected' : 'failed' });
    await audit(ctx, 'GATEWAY', ok ? 'GATEWAY_TEST_PASSED' : 'GATEWAY_TEST_FAILED', message, { status: ok ? 'success' : 'warning' });
    return json({ success: ok, status: ok ? 'connected' : 'failed', latencyMs: Date.now() - started, message, error: ok ? undefined : message });
  });
  route('POST', '/api/platform/gateway/create-link', async ctx => {
    const admin = await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const tenant = await findTenant(str(body.tenantId, 64));
    const result = await checkout().start({ id: admin.id, role: 'super_admin', tenant_id: tenant.tenant_id }, {
      planId: str(body.planId, 50), yearly: body.yearly === true, couponCode: str(body.couponCode, 32) || undefined,
      printerId: str(body.printerId, 64) || undefined, shippingAddress: body.shippingAddress,
    });
    await audit(ctx, 'BILLING', 'PAYMENT_LINK_CREATED', `${tenant.business_name}: ${body.planId} ${body.yearly ? 'yearly' : 'monthly'} ₹${((result.amount || 0) / 100).toFixed(2)}`, { target: result.id });
    return json({ success: true, checkoutId: result.id, checkoutUrl: result.url || null, amount: (result.amount || 0) / 100, status: result.status, tenantName: tenant.business_name });
  });

  // ---- Admin: audit, integrity, export ------------------------------
  route('GET', '/api/platform/audit-logs', async ctx => {
    await requireAdmin(ctx);
    const category = (ctx.url.searchParams.get('category') || '').toUpperCase();
    const limit = Math.min(500, Math.max(1, parseInt(ctx.url.searchParams.get('limit') || '200', 10) || 200));
    const filter = category && category !== 'ALL' && /^[A-Z_]{1,30}$/.test(category) ? `category=eq.${enc(category)}&` : '';
    const rows = await db().select('admin_audit_logs', `${filter}select=*&order=created_at.desc&limit=${limit}`);
    return json({ success: true, count: rows.length, logs: rows.map(r => ({ id: r.id, timestamp: r.created_at, category: r.category, action: r.action, details: r.details, actor: r.actor_email, ip: r.ip, status: r.status, target: r.target })) });
  });
  route('POST', '/api/platform/audit-logs', async ctx => {
    await requireAdmin(ctx);
    const body = await readJson(ctx.request);
    const action = str(body.action, 60).toUpperCase().replace(/[^A-Z0-9_]/g, '_') || 'ADMIN_NOTE';
    await audit(ctx, 'ADMIN', action, str(body.details, 2000), { status: 'info' });
    return json({ success: true }, 201);
  });
  route('POST', '/api/platform/reconcile', async ctx => {
    await requireAdmin(ctx);
    const started = Date.now();
    const report = await db().rpc('admin_integrity_report');
    const drift = report.ledgerDrift || [];
    await audit(ctx, 'SYSTEM', 'INTEGRITY_CHECK', `${drift.length} shop balance(s) differ from ledger`, { status: drift.length ? 'warning' : 'success' });
    return json({ success: true, status: drift.length ? 'DRIFT_DETECTED' : 'HEALTHY', latencyMs: Date.now() - started, ...report });
  });
  route('GET', '/api/platform/export', async ctx => {
    await requireAdmin(ctx);
    const entity = ctx.url.searchParams.get('entity') || 'tenants';
    const stamp = new Date().toISOString().slice(0, 10);
    let rows;
    if (entity === 'tenants') rows = (await db().select('tenants', 'select=tenant_id,business_name,contact_person,mobile,email,gstin,city,state,plan_id,subscription_status,subscription_end_date,max_users,max_shops,is_active,created_at&order=created_at.desc'));
    else if (entity === 'users') rows = await db().select('profiles', 'select=id,name,email,phone,role,tenant_id,account_status,is_active,last_login_at,created_at&order=created_at.desc');
    else if (entity === 'orders') rows = (await loadRetailOrders(5000)).map(({ items, ...o }) => ({ ...o, itemCount: items.length }));
    else if (entity === 'printers') rows = await db().select('printer_hardware_orders', 'select=*&order=created_at.desc');
    else if (entity === 'coupons') rows = await getCoupons();
    else if (entity === 'audit') rows = await db().select('admin_audit_logs', 'select=*&order=created_at.desc&limit=5000');
    else fail(400, 'Unknown export entity');
    await audit(ctx, 'SECURITY', 'DATA_EXPORTED', `${entity} (${rows.length} rows)`);
    if (ctx.url.searchParams.get('format') === 'json') return json(rows, 200, { 'Content-Disposition': `attachment; filename="salesarmy_${entity}_${stamp}.json"` });
    return csv(rows, `salesarmy_${entity}_${stamp}.csv`);
  });

  // ------------------------------------------------------------------
  // Dispatcher
  // ------------------------------------------------------------------
  function corsHeaders(request) {
    const origin = request.headers.get('Origin');
    if (!origin || !cfg.allowedOrigins.includes(origin)) return {};
    return {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
      'Access-Control-Max-Age': '600',
      Vary: 'Origin',
    };
  }

  async function handle(request, { ip = null } = {}) {
    const url = new URL(request.url);
    const cors = corsHeaders(request);
    const withCors = res => { for (const [k, v] of Object.entries(cors)) res.headers.set(k, v); return res; };
    if (request.method === 'OPTIONS') return withCors(new Response(null, { status: 204 }));

    const origin = request.headers.get('Origin');
    const sameOrigin = origin && origin === url.origin;
    if (origin && !sameOrigin && !cfg.allowedOrigins.includes(origin) && url.pathname !== '/api/checkout/webhook') {
      return json({ success: false, error: 'Origin not allowed' }, 403);
    }

    const ctx = { request, url, ip, user: null };
    for (const r of routes) {
      if (r.method !== request.method) continue;
      let params = null;
      if (typeof r.pattern === 'string') { if (r.pattern === url.pathname) params = []; }
      else { const m = url.pathname.match(r.pattern); if (m) params = m.slice(1); }
      if (!params) continue;
      try {
        return withCors(await r.handler(ctx, params));
      } catch (err) {
        if (err instanceof HttpError) {
          return withCors(json({ success: false, error: err.message }, err.status));
        }
        console.error('[api] unhandled', request.method, url.pathname, err);
        return withCors(json({ success: false, error: 'Internal server error' }, 500));
      }
    }
    return withCors(json({ success: false, error: `Endpoint not found: ${request.method} ${url.pathname}` }, 404));
  }

  return { handle };
}
