// Coupon improvements: plan / billing-cycle limits, start date, status, and
// the per-coupon usage report for the admin console.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { quoteCheckout } from '../api/checkout.mjs';
import { normalizeCoupon, couponStatus, DEFAULT_TIERS } from '../api/catalog.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

const catalogWith = (...coupons) => ({ plans: { tiers: DEFAULT_TIERS, planGst: 18 }, coupons });
const coupon = (code, extra = {}) => normalizeCoupon({ code, type: 'flat', value: 100, maxUses: 10, expiryDate: '2099-12-31', ...extra });

test('a coupon limited to plans only works on those plans', () => {
  const c = coupon('GROWONLY', { planIds: ['grow', 'enterprise'] });
  assert.throws(() => quoteCheckout(catalogWith(c), { planId: 'startup', couponCode: 'GROWONLY' }), /not valid for this plan — only for Grow, Enterprise/);
  assert.equal(quoteCheckout(catalogWith(c), { planId: 'grow', couponCode: 'GROWONLY' }).couponCode, 'GROWONLY');
});

test('a coupon limited to a billing cycle only works on that cycle', () => {
  const yearly = coupon('YEARLY', { billingCycle: 'yearly' });
  assert.throws(() => quoteCheckout(catalogWith(yearly), { planId: 'grow', couponCode: 'YEARLY' }), /not valid for monthly billing — yearly only/);
  assert.equal(quoteCheckout(catalogWith(yearly), { planId: 'grow', yearly: true, couponCode: 'YEARLY' }).couponCode, 'YEARLY');
  const monthly = coupon('MONTHLY', { billingCycle: 'monthly' });
  assert.throws(() => quoteCheckout(catalogWith(monthly), { planId: 'grow', yearly: true, couponCode: 'MONTHLY' }), /monthly only/);
});

test('a scheduled coupon is refused until its start date', () => {
  const c = coupon('LATER', { startDate: '2099-01-01' });
  assert.throws(() => quoteCheckout(catalogWith(c), { planId: 'grow', couponCode: 'LATER' }), /not valid yet — it starts on 2099-01-01/);
  const now = new Date('2099-01-02T10:00:00+05:30');
  assert.equal(quoteCheckout(catalogWith(c), { planId: 'grow', couponCode: 'LATER' }, now).couponCode, 'LATER');
});

test('start date must not be after expiry, and restrictions are validated', () => {
  assert.throws(() => normalizeCoupon({ code: 'BAD1', type: 'flat', value: 10, startDate: '2099-02-01', expiryDate: '2099-01-01' }), /start date must be before/);
  assert.throws(() => normalizeCoupon({ code: 'BAD2', type: 'flat', value: 10, billingCycle: 'weekly' }), /Billing cycle/);
  const ok = normalizeCoupon({ code: 'OK1', type: 'flat', value: 10, planIds: ['grow', 'grow', ''] });
  assert.deepEqual(ok.planIds, ['grow']);
  assert.equal(ok.billingCycle, 'any');
});

test('status: paused, scheduled, expired, used up, active', () => {
  const now = new Date('2026-11-26T12:00:00+05:30');
  assert.equal(couponStatus(coupon('CPA', { isActive: false }), 0, now), 'paused');
  assert.equal(couponStatus(coupon('CPB', { startDate: '2026-12-01' }), 0, now), 'scheduled');
  assert.equal(couponStatus(coupon('CPC', { expiryDate: '2026-11-25' }), 0, now), 'expired');
  assert.equal(couponStatus(coupon('CPD', { maxUses: 2 }), 2, now), 'used_up');
  assert.equal(couponStatus(coupon('CPE', { expiryDate: '2026-11-26' }), 0, now), 'active', 'valid through the whole expiry day');
});

test('checkout records how much the coupon saved (incl. GST)', () => {
  const half = coupon('HALF', { type: 'percentage', value: 50 });
  const q = quoteCheckout(catalogWith(half), { planId: 'grow', couponCode: 'HALF' });
  const full = quoteCheckout(catalogWith(), { planId: 'grow' });
  assert.equal(q.discountAmount, full.amount - q.amount);
  assert.ok(q.discountAmount > 0);
  assert.equal(quoteCheckout(catalogWith(), { planId: 'grow' }).discountAmount, 0);
});

test('admin usage report lists agencies, discount and revenue per coupon', async () => {
  const fake = createFakeSupabase();
  fake.tables.platform_settings.push({ id: 'coupons', data: { coupons: [coupon('DIWALI', { maxUses: 5 })] } });
  fake.tables.tenants.push({ tenant_id: 't1', business_name: 'Agency One' }, { tenant_id: 't2', business_name: 'Agency Two' });
  fake.tables.subscription_checkouts.push(
    { id: 'c1', tenant_id: 't1', status: 'paid', amount: 58682, created_at: '2026-11-20T10:00:00Z', paid_at: '2026-11-20T10:05:00Z', quote: { couponCode: 'DIWALI', planId: 'grow', planName: 'Grow', days: 30, discountAmount: 11800 } },
    { id: 'c2', tenant_id: 't2', status: 'pending', amount: 58682, created_at: '2026-11-21T10:00:00Z', quote: { couponCode: 'DIWALI', planId: 'grow', planName: 'Grow', days: 30 } },
    { id: 'c3', tenant_id: 't2', status: 'paid', amount: 1000, created_at: '2026-11-21T10:00:00Z', quote: { couponCode: 'OTHER' } },
  );
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin' });
  const owner = fake.addUser({ email: 'o@one.co', role: 'owner', tenant_id: 't1' });
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const get = token => api.handle(new Request('http://admin.test/api/platform/coupon/diwali/usage', { headers: { Authorization: `Bearer ${token}` } }));

  assert.equal((await get(owner.token)).status, 403, 'admins only');
  const res = await get(admin.token);
  const body = await res.json();
  assert.equal(res.status, 200, JSON.stringify(body));
  assert.equal(body.uses.length, 2, 'only this coupon');
  assert.equal(body.uses[0].tenantName, 'Agency Two');
  assert.deepEqual(body.summary, { redemptions: 1, agencies: 1, revenue: 586.82, discountGiven: 118, pending: 1, remaining: 4 });
});
