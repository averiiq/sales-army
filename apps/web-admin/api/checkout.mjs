// Subscription checkout: server-side quote, Razorpay payment link, and
// settlement only after the captured payment is verified with Razorpay.
import { HttpError } from './supabase.mjs';

const fail = (message, status = 400) => { throw new HttpError(status, message); };

export function quoteCheckout(catalog, input, now = new Date()) {
  const tiers = Array.isArray(catalog.plans) ? catalog.plans : catalog.plans?.tiers;
  const plan = tiers?.find(p => (p.id || p.planId) === input.planId && p.isActive !== false);
  if (!plan) fail('The selected plan is unavailable');
  const money = value => {
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) fail('Invalid catalog price');
    return Math.round(value * 100);
  };
  const rate = value => {
    const number = value ?? 18;
    if (typeof number !== 'number' || !Number.isFinite(number) || number < 0 || number > 100) fail('Invalid tax rate');
    return number;
  };
  let base = money(input.yearly === true ? (plan.yearlyPrice ?? plan.annualPrice) : plan.monthlyPrice);
  let days = input.yearly === true ? 365 : 30;
  let coupon = null;
  if (input.couponCode) {
    const wanted = String(input.couponCode).trim().toUpperCase();
    coupon = (catalog.coupons || []).find(c => String(c.code || '').toUpperCase() === wanted);
    const expiry = coupon?.expiryDate || coupon?.validUntil;
    if (!coupon || coupon.isActive === false || coupon.isPaused === true ||
      (expiry && new Date(`${expiry}`.length <= 10 ? `${expiry}T23:59:59+05:30` : expiry) <= now) ||
      base < money(coupon.minAmount ?? coupon.minOrderValue ?? 0)) fail('Coupon is unavailable');
    if (!Number.isFinite(coupon.value) || coupon.value < 0) fail('Invalid coupon');
    if (coupon.type === 'trial') {
      if (!Number.isInteger(coupon.value) || coupon.value < 1 || coupon.value > 365) fail('Invalid trial duration');
      base = 0; days = coupon.value;
    } else if (coupon.type === 'flat') base = Math.max(0, base - money(coupon.value));
    else if (coupon.type === 'percentage' || coupon.type === 'percent') base = Math.round(base * (1 - Math.min(100, coupon.value) / 100));
    else fail('Unsupported coupon');
  }
  const hardware = [];
  if (input.printerId) {
    const printer = catalog.printerOptions?.find(p => p.id === input.printerId && p.isAvailable !== false && p.isActive !== false);
    if (!printer) fail('Printer is unavailable');
    hardware.push({ ...printer, title: printer.name });
  }
  if (input.addonIds !== undefined && !Array.isArray(input.addonIds)) fail('Invalid add-ons');
  for (const addonId of new Set(input.addonIds || [])) {
    const addon = catalog.subscriptionAddons?.find(a => a.id === addonId && a.isAvailable !== false && a.isActive !== false);
    if (!addon) fail('Add-on is unavailable');
    hardware.push(addon);
  }
  if (hardware.length && (typeof input.shippingAddress !== 'string' || input.shippingAddress.trim().length < 10)) fail('Shipping address is required');
  let amount = base + Math.round(base * rate(catalog.plans?.planGst ?? catalog.planGstRate) / 100);
  let hardwareAmount = 0;
  for (const item of hardware) {
    const price = money(item.price);
    hardwareAmount += price + Math.round(price * rate(item.gstRate) / 100);
  }
  amount += hardwareAmount;
  if (!Number.isSafeInteger(amount) || amount > 100000000) fail('Invalid checkout amount');
  return {
    amount, currency: 'INR', planId: plan.id || plan.planId, planName: plan.name,
    maxUsers: plan.maxUsers ?? 1, maxShops: plan.maxShops ?? 200, days,
    couponCode: coupon?.code || null, couponLimit: coupon?.maxUses ?? 1000,
    trial: coupon?.type === 'trial', hardwareAmount, hardware,
    shippingAddress: hardware.length ? input.shippingAddress.trim() : null,
  };
}

const hex = buf => [...new Uint8Array(buf)].map(b => b.toString(16).padStart(2, '0')).join('');

export async function verifyWebhook(raw, signature, secret) {
  if (!secret || typeof signature !== 'string' || !/^[a-f0-9]{64}$/i.test(signature)) return false;
  const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
  const digest = hex(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw)));
  // constant-time compare
  const a = digest, b = signature.toLowerCase();
  let diff = a.length ^ b.length;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export function createRazorpay({ keyId, keySecret, fetchImpl = fetch }) {
  const call = async (method, endpoint, body) => {
    if (!keyId || !keySecret) fail('Razorpay is not configured. Set RAZORPAY_KEY_ID and RAZORPAY_KEY_SECRET on the server.', 503);
    let response;
    try {
      response = await fetchImpl(`https://api.razorpay.com/v1/${endpoint}`, {
        method,
        headers: { Authorization: `Basic ${btoa(`${keyId}:${keySecret}`)}`, 'Content-Type': 'application/json' },
        body: body ? JSON.stringify(body) : undefined,
        signal: AbortSignal.timeout(15000),
      });
    } catch (err) {
      fail('Payment provider is unreachable', 503);
    }
    const data = await response.json().catch(() => ({}));
    if (!response.ok) fail(data?.error?.description || 'Payment provider rejected the request', 502);
    return data;
  };
  call.configured = Boolean(keyId && keySecret);
  return call;
}

export function createCheckoutService({ db, gateway, getCatalog }) {
  async function start(user, input) {
    if (!['owner', 'distributor', 'super_admin'].includes(user.role) || !user.tenant_id) fail('Only a workspace owner can purchase a subscription', 403);
    const quote = quoteCheckout(await getCatalog(), input || {});
    // Refuse paid checkouts before reserving anything (coupon holds, rows)
    // when the gateway is not configured.
    if (quote.amount > 0 && gateway.configured === false) fail('Online payments are not configured yet. Set the Razorpay keys on the server.', 503);
    const id = crypto.randomUUID();
    await db.rpc('reserve_subscription_checkout', { p_id: id, p_tenant: user.tenant_id, p_user: user.id, p_quote: quote });
    if (quote.amount === 0) {
      return db.rpc('settle_subscription_checkout', { p_id: id, p_link: null, p_payment: null, p_amount: 0 });
    }
    const link = await gateway('POST', 'payment_links', {
      amount: quote.amount, currency: 'INR', accept_partial: false, reference_id: id,
      expire_by: Math.floor(Date.now() / 1000) + 72 * 3600,
      description: `SalesArmy ${quote.planName}`, notes: { checkout_id: id, tenant_id: user.tenant_id },
    });
    if (!link.id || !link.short_url) fail('Payment provider did not return a checkout link', 502);
    await db.update('subscription_checkouts', `id=eq.${id}`, { gateway_link_id: link.id, checkout_url: link.short_url });
    return { id, status: 'pending', url: link.short_url, amount: quote.amount, quote };
  }

  async function status(user, id) {
    if (!/^[0-9a-f-]{36}$/i.test(id || '')) fail('Invalid checkout ID');
    const tenantFilter = user.role === 'super_admin' && !user.tenant_id ? '' : `&tenant_id=eq.${encodeURIComponent(user.tenant_id)}`;
    const rows = await db.select('subscription_checkouts', `id=eq.${id}${tenantFilter}&select=*`);
    const checkout = rows[0];
    if (!checkout) fail('Checkout not found', 404);
    if (checkout.status === 'paid') return { id, status: 'paid', paymentId: checkout.payment_id, expiresAt: checkout.subscription_end_date };
    if (!checkout.gateway_link_id) return { id, status: 'pending' };
    const link = await gateway('GET', `payment_links/${encodeURIComponent(checkout.gateway_link_id)}`);
    if (link.status !== 'paid') return { id, status: link.status, url: checkout.checkout_url };
    if (link.currency !== 'INR' || link.amount !== checkout.amount || link.amount_paid !== checkout.amount || link.reference_id !== id) fail('Payment does not match checkout', 409);
    const payment = link.payments?.find(p => p.status === 'captured' && p.amount === checkout.amount);
    if (!payment) fail('Captured payment not found', 409);
    return db.rpc('settle_subscription_checkout', { p_id: id, p_link: link.id, p_payment: payment.payment_id, p_amount: link.amount_paid });
  }

  async function webhook(raw, signature, secret) {
    if (!(await verifyWebhook(raw, signature, secret))) fail('Invalid webhook signature', 401);
    const event = JSON.parse(raw);
    if (event.event !== 'payment_link.paid') return { ignored: event.event };
    const link = event.payload?.payment_link?.entity;
    if (!link?.reference_id || !/^[0-9a-f-]{36}$/i.test(link.reference_id)) fail('Invalid payment reference');
    const rows = await db.select('subscription_checkouts', `id=eq.${link.reference_id}&select=tenant_id`);
    if (!rows.length) fail('Checkout not found', 404);
    // The webhook only triggers reconciliation; the captured payment is
    // re-fetched from Razorpay before anything is activated.
    return status({ role: 'owner', tenant_id: rows[0].tenant_id }, link.reference_id);
  }

  return { start, status, webhook };
}
