// App "Apply coupon": the server checks the typed code with the same rules as checkout.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

const future = '2099-12-31';
function setup(coupons) {
  const fake = createFakeSupabase();
  fake.tables.platform_settings.push({ id: 'coupons', data: { coupons } });
  fake.tables.tenants.push({ tenant_id: 't1', business_name: 'Agency One', plan_id: 'startup', subscription_status: 'trial', is_active: true, subscription_end_date: future });
  fake.tables.tenants.push({ tenant_id: 't2', business_name: 'Agency Two', plan_id: 'startup', subscription_status: 'trial', is_active: true, subscription_end_date: future });
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const owner = fake.addUser({ email: 'owner@one.co', role: 'owner', tenant_id: 't1' });
  const staff = fake.addUser({ email: 'rep@one.co', role: 'sales_person', tenant_id: 't1' });
  const apply = async (body, token = owner.token) => {
    const res = await api.handle(new Request('http://admin.test/api/checkout/coupon', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: JSON.stringify(body),
    }), { ip: '127.0.0.1' });
    return { status: res.status, json: await res.json() };
  };
  return { fake, apply, owner, staff };
}

const coupon = (code, extra = {}) => ({ id: code, code, type: 'trial', value: 30, title: `${code} title`, minAmount: 0, maxUses: 10, expiryDate: future, isActive: true, ...extra });

test('a valid admin coupon is accepted and returns its details', async () => {
  const { apply } = setup([coupon('PROMO70'), coupon('FLAT50', { type: 'flat', value: 50 }), coupon('HALF', { type: 'percentage', value: 50 })]);
  const r = await apply({ couponCode: 'promo70', planId: 'startup', yearly: false });
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.equal(r.json.coupon.code, 'PROMO70');
  assert.equal(r.json.coupon.type, 'trial');
  assert.equal(r.json.coupon.value, 30);
  assert.equal(r.json.days, 30);
  assert.equal(r.json.amountWithCoupon, 0, 'trial coupon makes the plan free');

  const flat = await apply({ couponCode: 'FLAT50', planId: 'startup' });
  assert.equal(flat.status, 200);
  assert.ok(flat.json.amountWithCoupon < flat.json.regularAmount);
  const half = await apply({ couponCode: 'HALF', planId: 'startup' });
  assert.equal(half.status, 200);
  assert.ok(Math.abs(half.json.amountWithCoupon - half.json.regularAmount / 2) < 1);
});

test('unknown, paused, expired and under-minimum coupons are refused with a reason', async () => {
  const { apply } = setup([
    coupon('PAUSED1', { isActive: false, isPaused: true }),
    coupon('OLD1', { expiryDate: '2020-01-01' }),
    coupon('BIGMIN', { type: 'flat', value: 100, minAmount: 999999 }),
  ]);
  for (const code of ['TRIAL30', 'PAUSED1', 'OLD1', 'BIGMIN']) {
    const r = await apply({ couponCode: code, planId: 'startup' });
    assert.equal(r.status, 400, code);
    assert.match(r.json.error, new RegExp(`${code}.*not valid`), code);
  }
});

test('usage limit and one use per workspace are enforced like checkout', async () => {
  const { fake, apply } = setup([coupon('ONCE', { maxUses: 1 }), coupon('MULTI', { maxUses: 5 })]);
  // Another agency already paid with ONCE -> limit reached
  fake.tables.subscription_checkouts.push({ id: 'a', tenant_id: 't2', status: 'paid', created_at: '2026-01-01T00:00:00Z', quote: { couponCode: 'ONCE' } });
  const limit = await apply({ couponCode: 'ONCE', planId: 'startup' });
  assert.equal(limit.status, 400);
  assert.match(limit.json.error, /usage limit/);
  // This agency already used MULTI -> refused for this agency
  fake.tables.subscription_checkouts.push({ id: 'b', tenant_id: 't1', status: 'paid', created_at: '2026-01-01T00:00:00Z', quote: { couponCode: 'MULTI' } });
  const mine = await apply({ couponCode: 'MULTI', planId: 'startup' });
  assert.equal(mine.status, 400);
  assert.match(mine.json.error, /already used by your workspace/);
  // An old, never-paid checkout does not count
  fake.tables.subscription_checkouts.push({ id: 'c', tenant_id: 't2', status: 'expired', created_at: '2026-01-01T00:00:00Z', quote: { couponCode: 'MULTI' } });
});

test('coupon check needs a signed-in workspace owner and a real plan', async () => {
  const { apply, staff } = setup([coupon('PROMO70')]);
  assert.equal((await apply({ couponCode: 'PROMO70', planId: 'startup' }, null)).status, 401);
  assert.equal((await apply({ couponCode: 'PROMO70', planId: 'startup' }, staff.token)).status, 403);
  assert.equal((await apply({ couponCode: '', planId: 'startup' })).status, 400);
  assert.equal((await apply({ couponCode: 'PROMO70', planId: 'ghost' })).status, 400);
});
