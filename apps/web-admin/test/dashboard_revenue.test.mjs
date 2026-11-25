// Dashboard revenue summary: paid plans + paid hardware/add-ons, no double count.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

function setup() {
  const fake = createFakeSupabase();
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const call = async (path, token) => {
    const res = await api.handle(new Request(`http://admin.test${path}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    }), { ip: '127.0.0.1' });
    return { status: res.status, json: await res.json() };
  };
  return { fake, call, admin };
}

test('revenue summary splits paid plan and hardware revenue without double counting', async () => {
  const { fake, call, admin } = setup();
  // Paid checkout: ₹500 plan + ₹1,180 printer (amounts in paise)
  fake.tables.subscription_checkouts.push({ id: 'c1', status: 'paid', amount: 168000, quote: { hardwareAmount: 118000 } });
  // Paid plan-only checkout: ₹399
  fake.tables.subscription_checkouts.push({ id: 'c2', status: 'paid', amount: 39900, quote: {} });
  // Unpaid checkout is ignored
  fake.tables.subscription_checkouts.push({ id: 'c3', status: 'pending', amount: 99900, quote: {} });
  // Hardware row created by checkout c1 (rupees) + a paid paper-roll order + an unpaid order
  fake.tables.printer_hardware_orders.push({ order_id: 'c1', payment_status: 'paid', total_amount: 1180 });
  fake.tables.printer_hardware_orders.push({ order_id: 'HW-1', payment_status: 'paid', total_amount: 600 });
  fake.tables.printer_hardware_orders.push({ order_id: 'HW-2', payment_status: 'pending', total_amount: 5000 });

  const r = await call('/api/platform/revenue-summary', admin.token);
  assert.equal(r.status, 200);
  assert.equal(r.json.planRevenue, 899);
  assert.equal(r.json.hardwareRevenue, 1780);
  assert.equal(r.json.totalRevenue, 2679);
  assert.equal(r.json.paidSubscriptions, 2);
  assert.equal(r.json.paidHardwareOrders, 2);
  assert.equal(r.json.subscriptions.length, 2, 'only paid checkouts are listed');
  assert.deepEqual(r.json.subscriptions.map(s => s.amount).sort((a, b) => a - b), [399, 500], 'listed amount is the plan part only');
  // Revenue Reports page needs every hardware order (paid and unpaid) for order counts
  assert.equal(r.json.hardwareOrders.length, 3);
  assert.deepEqual(r.json.hardwareOrders.map(h => h.paymentStatus).sort(), ['paid', 'paid', 'pending']);
});

test('revenue summary lists plan period and validity for Plans Purchased', async () => {
  const { fake, call, admin } = setup();
  fake.tables.subscription_checkouts.push({ id: 'y1', tenant_id: 't1', status: 'paid', amount: 382800, paid_at: '2026-11-01T10:00:00Z', subscription_end_date: '2027-11-01T10:00:00Z', quote: { planName: 'Startup Plan', days: 365, couponCode: 'SAVE10' } });
  const r = await call('/api/platform/revenue-summary', admin.token);
  const s = r.json.subscriptions[0];
  assert.equal(s.tenantId, 't1');
  assert.equal(s.planName, 'Startup Plan');
  assert.equal(s.days, 365);
  assert.equal(s.validTill, '2027-11-01T10:00:00Z');
  assert.equal(s.amount, 3828);
  assert.equal(s.trial, false);
});

test('revenue summary requires a super admin', async () => {
  const { call } = setup();
  assert.equal((await call('/api/platform/revenue-summary')).status, 401);
});
