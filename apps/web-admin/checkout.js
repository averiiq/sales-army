'use strict';
const crypto = require('node:crypto');

function quoteCheckout(catalog, input, now = new Date()) {
  const tiers = Array.isArray(catalog.plans) ? catalog.plans : catalog.plans?.tiers;
  const plan = tiers?.find(p => (p.id || p.planId) === input.planId && p.isActive !== false);
  if (!plan) throw new Error('The selected plan is unavailable');
  const money = value => {
    if (typeof value !== 'number' || !Number.isFinite(value) || value < 0) throw new Error('Invalid catalog price');
    return Math.round(value * 100);
  };
  const rate = value => {
    const number = value ?? 18;
    if (typeof number !== 'number' || !Number.isFinite(number) || number < 0 || number > 100) throw new Error('Invalid tax rate');
    return number;
  };
  let base = money(input.yearly === true ? (plan.yearlyPrice ?? plan.annualPrice) : plan.monthlyPrice);
  let days = input.yearly === true ? 365 : 30;
  let coupon = null;
  if (input.couponCode) {
    coupon = catalog.coupons?.find(c => c.code.toUpperCase() === String(input.couponCode).trim().toUpperCase());
    if (!coupon || coupon.isActive === false || coupon.isPaused === true ||
      (coupon.expiryDate && new Date(coupon.expiryDate) <= now) || base < money(coupon.minAmount ?? 0)) throw new Error('Coupon is unavailable');
    if (!Number.isFinite(coupon.value) || coupon.value < 0) throw new Error('Invalid coupon');
    if (coupon.type === 'trial') {
      if (!Number.isInteger(coupon.value) || coupon.value < 1 || coupon.value > 365) throw new Error('Invalid trial duration');
      base = 0; days = coupon.value;
    } else if (coupon.type === 'flat') base = Math.max(0, base - money(coupon.value));
    else if (coupon.type === 'percentage') base = Math.round(base * (1 - Math.min(100, coupon.value) / 100));
    else throw new Error('Unsupported coupon');
  }
  const hardware = [];
  if (input.printerId) {
    const printer = catalog.printerOptions?.find(p => p.id === input.printerId && p.isAvailable !== false);
    if (!printer) throw new Error('Printer is unavailable');
    hardware.push({ ...printer, title: printer.name });
  }
  if (input.addonIds !== undefined && !Array.isArray(input.addonIds)) throw new Error('Invalid add-ons');
  for (const id of new Set(input.addonIds || [])) {
    const addon = catalog.subscriptionAddons?.find(a => a.id === id && a.isAvailable !== false);
    if (!addon) throw new Error('Add-on is unavailable');
    hardware.push(addon);
  }
  if (hardware.length && (typeof input.shippingAddress !== 'string' || input.shippingAddress.trim().length < 10)) throw new Error('Shipping address is required');
  let amount = base + Math.round(base * rate(catalog.plans?.planGst ?? catalog.planGstRate) / 100);
  let hardwareAmount = 0;
  for (const item of hardware) {
    const price = money(item.price);
    hardwareAmount += price + Math.round(price * rate(item.gstRate) / 100);
  }
  amount += hardwareAmount;
  if (!Number.isSafeInteger(amount) || amount > 100000000) throw new Error('Invalid checkout amount');
  return {
    amount, currency: 'INR', planId: plan.id || plan.planId, planName: plan.name,
    maxUsers: plan.maxUsers ?? 1, maxShops: plan.maxShops ?? 200, days,
    couponCode: coupon?.code || null, couponLimit: coupon?.maxUses ?? 1000,
    trial: coupon?.type === 'trial', hardwareAmount, hardware,
    shippingAddress: hardware.length ? input.shippingAddress.trim() : null
  };
}

function verifyWebhook(raw, signature, secret) {
  if (!secret || typeof signature !== 'string' || !/^[a-f0-9]{64}$/i.test(signature)) return false;
  const digest = crypto.createHmac('sha256', secret).update(raw).digest();
  return crypto.timingSafeEqual(digest, Buffer.from(signature, 'hex'));
}

function createCheckoutService({ database, gateway, getCatalog }) {
  async function start(user, input) {
    if (!['owner', 'distributor', 'super_admin'].includes(user.role) || !user.tenant_id) throw new Error('Only a workspace owner can purchase a subscription');
    const quote = quoteCheckout(await getCatalog(), input);
    const id = crypto.randomUUID();
    await database('POST', 'rpc/reserve_subscription_checkout', { p_id: id, p_tenant: user.tenant_id, p_user: user.id, p_quote: quote });
    if (quote.amount === 0) return database('POST', 'rpc/settle_subscription_checkout', { p_id: id, p_link: null, p_payment: null, p_amount: 0 });
    const link = await gateway('POST', 'payment_links', {
      amount: quote.amount, currency: 'INR', accept_partial: false, reference_id: id,
      expire_by: Math.floor(Date.now() / 1000) + 1800,
      description: `SalesArmy ${quote.planName}`, notes: { checkout_id: id },
    });
    if (!link.id || !link.short_url) throw new Error('Payment provider did not return a checkout link');
    await database('PATCH', `subscription_checkouts?id=eq.${id}`, { gateway_link_id: link.id, checkout_url: link.short_url });
    return { id, status: 'pending', url: link.short_url, amount: quote.amount };
  }
  async function status(user, id) {
    if (!/^[0-9a-f-]{36}$/i.test(id)) throw new Error('Invalid checkout ID');
    const rows = await database('GET', `subscription_checkouts?id=eq.${id}&tenant_id=eq.${encodeURIComponent(user.tenant_id)}&select=*`);
    const checkout = rows[0];
    if (!checkout) throw new Error('Checkout not found');
    if (checkout.status === 'paid') return { id, status: 'paid', paymentId: checkout.payment_id, expiresAt: checkout.subscription_end_date };
    if (!checkout.gateway_link_id) return { id, status: 'pending' };
    const link = await gateway('GET', `payment_links/${encodeURIComponent(checkout.gateway_link_id)}`);
    if (link.status !== 'paid') return { id, status: link.status, url: checkout.checkout_url };
    if (link.currency !== 'INR' || link.amount !== checkout.amount || link.amount_paid !== checkout.amount || link.reference_id !== id) throw new Error('Payment does not match checkout');
    const payment = link.payments?.find(p => p.status === 'captured' && p.amount === checkout.amount);
    if (!payment) throw new Error('Captured payment not found');
    return database('POST', 'rpc/settle_subscription_checkout', {
      p_id: id, p_link: link.id, p_payment: payment.payment_id, p_amount: link.amount_paid,
    });
  }
  async function webhook(raw, signature, secret) {
    if (!verifyWebhook(raw, signature, secret)) throw new Error('Invalid webhook signature');
    const event = JSON.parse(raw);
    if (event.event !== 'payment_link.paid') return;
    const link = event.payload?.payment_link?.entity;
    if (!link?.reference_id || !/^[0-9a-f-]{36}$/i.test(link.reference_id)) throw new Error('Invalid payment reference');
    const rows = await database('GET', `subscription_checkouts?id=eq.${link.reference_id}&select=tenant_id`);
    if (!rows.length) throw new Error('Checkout not found');
    // Retrieve captured payment directly from Razorpay; the webhook only triggers reconciliation.
    await status({ tenant_id: rows[0].tenant_id }, link.reference_id);
  }
  return { start, status, webhook };
}

module.exports = { quoteCheckout, verifyWebhook, createCheckoutService };
