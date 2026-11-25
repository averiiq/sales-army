import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { resolvePublicPath } from '../api/static.mjs';
import { quoteCheckout, verifyWebhook } from '../api/checkout.mjs';
import { normalizeCoupon } from '../api/catalog.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

function setup() {
  const fake = createFakeSupabase();
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  fake.tables.tenants.push({ tenant_id: 'tenant_a', business_name: 'Agency A', mobile: '9999999999', plan_id: 'startup', subscription_status: 'active', is_active: true, max_users: 2, max_shops: 200 });
  fake.tables.tenants.push({ tenant_id: 'tenant_b', business_name: 'Agency B', mobile: '8888888888', plan_id: 'grow', subscription_status: 'trial', is_active: true, max_users: 5, max_shops: 1000 });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const owner = fake.addUser({ email: 'owner@a.com', role: 'owner', tenant_id: 'tenant_a', name: 'Owner A' });
  const sales = fake.addUser({ email: 'sales@a.com', role: 'sales_person', tenant_id: 'tenant_a', name: 'Sales A' });
  const call = async (method, path, { token, body, headers = {} } = {}) => {
    const res = await api.handle(new Request(`http://admin.test${path}`, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}), ...headers },
      body: body === undefined ? undefined : typeof body === 'string' ? body : JSON.stringify(body),
    }), { ip: '127.0.0.1' });
    const text = await res.text();
    let json; try { json = JSON.parse(text); } catch (_) { json = text; }
    return { status: res.status, json, headers: res.headers };
  };
  return { fake, api, call, admin, owner, sales };
}

const ADMIN_ROUTES = [
  ['GET', '/api/platform/all'], ['GET', '/api/platform/tenants'], ['GET', '/api/platform/users'],
  ['POST', '/api/platform/sync-tenant'], ['DELETE', '/api/platform/tenant/tenant_a'], ['POST', '/api/platform/sync-user'],
  ['DELETE', '/api/platform/user/00000000-0000-4000-8000-000000000001'], ['POST', '/api/platform/update'],
  ['POST', '/api/platform/coupon'], ['POST', '/api/platform/remote-config'], ['POST', '/api/platform/broadcast'],
  ['POST', '/api/platform/notifications'], ['POST', '/api/platform/subscriptions/settle'], ['GET', '/api/platform/gateway/config'],
  ['GET', '/api/platform/audit-logs'], ['POST', '/api/platform/reconcile'], ['GET', '/api/platform/export'],
  ['GET', '/api/platform/tenant/tenant_a/overview'], ['POST', '/api/platform/printer-order/status'],
];

test('every admin route rejects anonymous callers (401) and non-admins (403)', async () => {
  const { call, owner, sales } = setup();
  for (const [method, path] of ADMIN_ROUTES) {
    const anon = await call(method, path, { body: method === 'GET' || method === 'DELETE' ? undefined : {} });
    assert.equal(anon.status, 401, `${method} ${path} anonymous`);
    for (const who of [owner, sales]) {
      const r = await call(method, path, { token: who.token, body: method === 'GET' || method === 'DELETE' ? undefined : {} });
      assert.equal(r.status, 403, `${method} ${path} as non-admin`);
    }
  }
});

test('invalid and suspended sessions are rejected', async () => {
  const { call, fake } = setup();
  assert.equal((await call('GET', '/api/platform/all', { token: 'forged' })).status, 401);
  const suspended = fake.addUser({ email: 'gone@example.com', role: 'super_admin', status: 'suspended' });
  assert.equal((await call('GET', '/api/platform/all', { token: suspended.token })).status, 401);
});

test('admin snapshot returns live data without coupons leaking to public catalog', async () => {
  const { call, admin, fake } = setup();
  fake.tables.platform_settings.push({ id: 'coupons', data: { coupons: [normalizeCoupon({ code: 'HALF', type: 'percentage', value: 50 })] } });
  const all = await call('GET', '/api/platform/all', { token: admin.token });
  assert.equal(all.status, 200);
  assert.equal(all.json.data.tenants.length, 2);
  assert.equal(all.json.data.users.length, 3);
  assert.equal(all.json.data.coupons[0].code, 'HALF');
  const pub = await call('GET', '/api/platform/public');
  assert.equal(pub.status, 200);
  assert.equal(pub.json.data.coupons, undefined);
  assert.equal(pub.json.data.users, undefined);
  assert.ok(Array.isArray(pub.json.data.plans.tiers));
});

test('login never invents a role; admin UI only gets super_admin from the profile', async () => {
  const { call, fake } = setup();
  const bad = await call('POST', '/api/auth/login', { body: { email: 'root@example.com', password: 'wrong' } });
  assert.equal(bad.status, 401);
  const ok = await call('POST', '/api/auth/login', { body: { email: 'owner@a.com', password: 'Secret#12345' } });
  assert.equal(ok.status, 200);
  assert.equal(ok.json.user.role, 'owner');
  // Auth user without a profile row must NOT become super_admin.
  fake.users.set('orphan', { id: 'orphan', email: 'orphan@x.com', password: 'Secret#12345' });
  const orphan = await call('POST', '/api/auth/login', { body: { email: 'orphan@x.com', password: 'Secret#12345' } });
  assert.equal(orphan.status, 403);
});

test('public signup creates only an agency owner; staff/admin roles need an owner or admin', async () => {
  const { call, fake, owner, sales } = setup();
  const agency = await call('POST', '/api/auth/signup', { body: { accountType: 'agency', businessName: 'New Co', name: 'Neha', email: 'neha@new.co', phone: '9000000000', password: 'LongPass#1', role: 'super_admin', planId: 'enterprise' } });
  assert.equal(agency.status, 201);
  const profile = fake.tables.profiles.find(p => p.email === 'neha@new.co');
  assert.equal(profile.role, 'owner');
  assert.equal(fake.tables.tenants.find(t => t.tenant_id === agency.json.tenantId).plan_id, 'startup', 'public signup cannot pick its plan');

  const anonStaff = await call('POST', '/api/auth/signup', { body: { accountType: 'staff', name: 'X', email: 'x@x.com', password: 'LongPass#1', role: 'super_admin', tenantId: 'tenant_b' } });
  assert.equal(anonStaff.status, 401);
  const salesTries = await call('POST', '/api/auth/signup', { token: sales.token, body: { accountType: 'staff', name: 'X', email: 'x@x.com', password: 'LongPass#1', role: 'sales_person' } });
  assert.equal(salesTries.status, 403);
  const ownerAdmin = await call('POST', '/api/auth/signup', { token: owner.token, body: { accountType: 'staff', name: 'X', email: 'x@x.com', password: 'LongPass#1', role: 'super_admin' } });
  assert.equal(ownerAdmin.status, 403);
  // owner of tenant_a (max_users 2, already 2 members) hits the seat limit
  const full = await call('POST', '/api/auth/signup', { token: owner.token, body: { accountType: 'staff', name: 'X', email: 'x@x.com', password: 'LongPass#1', role: 'sales_person', tenantId: 'tenant_b' } });
  assert.equal(full.status, 409);
});

test('admin tenant update is a partial patch with validation and audit', async () => {
  const { call, admin, fake } = setup();
  const r = await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'tenant_a', subscriptionPlanId: 'grow', extendDays: 30 } });
  assert.equal(r.status, 200);
  const t = fake.tables.tenants.find(x => x.tenant_id === 'tenant_a');
  assert.equal(t.plan_id, 'grow');
  assert.equal(t.max_users, 5);
  assert.equal(t.mobile, '9999999999', 'untouched fields stay as they were');
  assert.ok(new Date(t.subscription_end_date) > new Date(Date.now() + 29 * 86400000));
  assert.ok(fake.tables.admin_audit_logs.some(l => l.action === 'TENANT_UPDATED' && l.actor_email === 'root@example.com'));
  assert.equal((await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'tenant_a', subscriptionPlanId: 'platinum_hack' } })).status, 400);
  assert.equal((await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'tenant_a', subscriptionStatus: 'god' } })).status, 400);
  assert.equal((await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'nope', firmName: 'X' } })).status, 404);
});

test('suspending a user bans the auth account; deleting removes the auth user', async () => {
  const { call, admin, sales, fake } = setup();
  const s = await call('POST', '/api/platform/sync-user', { token: admin.token, body: { id: sales.id, status: 'suspended' } });
  assert.equal(s.status, 200);
  assert.equal(fake.users.get(sales.id).banned, true);
  assert.equal(fake.tables.profiles.find(p => p.id === sales.id).is_active, false);
  const self = await call('DELETE', `/api/platform/user/${admin.id}`, { token: admin.token });
  assert.equal(self.status, 400, 'admin cannot delete themselves');
  const d = await call('DELETE', `/api/platform/user/${sales.id}`, { token: admin.token });
  assert.equal(d.status, 200);
  assert.equal(fake.users.has(sales.id), false);
});

test('tenant deletion needs explicit confirmation and removes member logins', async () => {
  const { call, admin, owner, fake } = setup();
  assert.equal((await call('DELETE', '/api/platform/tenant/tenant_a', { token: admin.token })).status, 400);
  const r = await call('DELETE', '/api/platform/tenant/tenant_a?confirm=tenant_a', { token: admin.token });
  assert.equal(r.status, 200);
  assert.equal(r.json.usersDeleted, 2);
  assert.equal(fake.users.has(owner.id), false);
  assert.ok(!fake.tables.tenants.some(t => t.tenant_id === 'tenant_a'));
});

test('platform update rejects tenants/users arrays and validates catalog', async () => {
  const { call, admin } = setup();
  assert.equal((await call('POST', '/api/platform/update', { token: admin.token, body: { tenants: [] } })).status, 400);
  assert.equal((await call('POST', '/api/platform/update', { token: admin.token, body: { plans: { tiers: [{ id: 'x', name: 'X', monthlyPrice: -5 }] } } })).status, 400);
  assert.equal((await call('POST', '/api/platform/update', { token: admin.token, body: { coupons: [{ code: 'A', type: 'flat', value: 10 }] } })).status, 400, 'code too short');
  const ok = await call('POST', '/api/platform/update', { token: admin.token, body: { remoteConfig: { maintenance: { active: true, message: 'Down' }, featureFlags: { reports: false } } } });
  assert.equal(ok.status, 200);
  const rc = await call('GET', '/api/platform/remote-config', { token: admin.token });
  assert.equal(rc.json.config.maintenance.active, true);
  assert.equal(rc.json.config.featureFlags.reports, false);
  assert.equal(rc.json.config.featureFlags.order_taking, true);
});

test('coupons are normalised so checkout enforces expiry and minimum amount', async () => {
  const c = normalizeCoupon({ code: 'old10', type: 'percent', value: 10, validUntil: '2020-01-01', minOrderValue: 500 });
  assert.equal(c.code, 'OLD10');
  assert.equal(c.type, 'percentage');
  assert.equal(c.expiryDate, '2020-01-01');
  assert.equal(c.minAmount, 500);
  const catalog = { plans: { tiers: [{ id: 'startup', name: 'Startup', monthlyPrice: 399, yearlyPrice: 3828 }] }, coupons: [c] };
  assert.throws(() => quoteCheckout(catalog, { planId: 'startup', couponCode: 'OLD10' }), /Coupon ".*" is not valid/);
  const big = normalizeCoupon({ code: 'BIG', type: 'flat', value: 50, minOrderValue: 1000 });
  assert.throws(() => quoteCheckout({ ...catalog, coupons: [big] }, { planId: 'startup', couponCode: 'BIG' }), /Coupon ".*" is not valid/);
  const q = quoteCheckout(catalog, { planId: 'startup' });
  assert.equal(q.amount, Math.round(39900 * 1.18));
});

test('webhook signature is verified with HMAC-SHA256', async () => {
  const raw = '{"event":"payment_link.paid"}';
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode('whsec_test'), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const sig = [...new Uint8Array(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw)))].map(b => b.toString(16).padStart(2, '0')).join('');
  assert.equal(await verifyWebhook(raw, sig, 'whsec_test'), true);
  assert.equal(await verifyWebhook(raw, sig.replace(/^./, c => (c === 'a' ? 'b' : 'a')), 'whsec_test'), false);
  assert.equal(await verifyWebhook(raw, sig, ''), false);
  const { call } = setup();
  assert.equal((await call('POST', '/api/checkout/webhook', { body: raw, headers: { 'x-razorpay-signature': 'f'.repeat(64) } })).status, 401);
});

test('manual settlement requires a payment reference and uses the admin RPC', async () => {
  const { call, admin, fake } = setup();
  const id = '11111111-1111-4111-8111-111111111111';
  fake.tables.subscription_checkouts.push({ id, tenant_id: 'tenant_a', status: 'pending', amount: 47082, quote: { days: 30 } });
  assert.equal((await call('POST', '/api/platform/subscriptions/settle', { token: admin.token, body: { checkoutId: id } })).status, 400);
  const r = await call('POST', '/api/platform/subscriptions/settle', { token: admin.token, body: { checkoutId: id, paymentReference: 'UTR123', paymentMode: 'bank' } });
  assert.equal(r.status, 200);
  assert.ok(fake.calls.some(c => c.path === '/rest/v1/rpc/admin_settle_checkout_manual' && c.body.p_reference === 'UTR123'));
});

test('gateway: an incomplete key is refused and secrets are never returned', async () => {
  const { call, admin } = setup();
  const r = await call('POST', '/api/platform/gateway/config', { token: admin.token, body: { keySecret: 'leak' } });
  assert.equal(r.status, 400);
  const view = await call('GET', '/api/platform/gateway/config', { token: admin.token });
  assert.notEqual(view.json.config.managedBy, 'admin');
  assert.equal(JSON.stringify(view.json).includes('whsec_test'), false);
});

test('admin-created orders compute totals server side', async () => {
  const { call, admin, fake } = setup();
  const r = await call('POST', '/api/platform/sync-order', { token: admin.token, body: {
    tenantId: 'tenant_a', shopName: 'Ganesh Kirana', status: 'confirmed', grandTotal: 1,
    items: [{ productName: 'Biscuits', quantity: 2, unitPrice: 100, gstRate: 18 }],
  } });
  assert.equal(r.status, 201);
  const order = fake.tables.orders[0];
  assert.equal(order.grand_total, 236);
  assert.equal(fake.tables.order_items.length, 1);
  assert.equal((await call('POST', '/api/platform/sync-order', { token: admin.token, body: { tenantId: 'tenant_a', items: [{ productName: 'X', quantity: -1, unitPrice: 1 }] } })).status, 400);
});

test('cross-origin API calls are refused unless allow-listed', async () => {
  const { call } = setup();
  const r = await call('GET', '/api/platform/public', { headers: { Origin: 'https://evil.example' } });
  assert.equal(r.status, 403);
  const same = await call('GET', '/api/platform/public', { headers: { Origin: 'http://admin.test' } });
  assert.equal(same.status, 200);
});

test('only the SPA files are ever served as static assets', () => {
  assert.equal(resolvePublicPath('/'), 'index.html');
  assert.equal(resolvePublicPath('/app.js'), 'app.js');
  assert.equal(resolvePublicPath('/vendor/supabase.min.js'), 'vendor/supabase.min.js');
  for (const p of ['/.env', '/data/gateway_config.json', '/data/platform_state.json', '/server.js', '/api/handler.mjs',
    '/test/api.test.mjs', '/wrangler.toml', '/package.json', '/../.env', '/vendor/../.env', '/%2e%2e/.env', '/security.js']) {
    assert.equal(resolvePublicPath(p), null, p);
  }
});
