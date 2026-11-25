// Section 2 (Clients / Subscribers): 30-day usage activity flag and agency report downloads.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

const DAY = 86400000;
const ago = days => new Date(Date.now() - days * DAY).toISOString();

function setup() {
  const fake = createFakeSupabase();
  fake.tables.purchases = [];
  fake.tables.expenses = [];
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const call = async (path, token = admin.token) => {
    const res = await api.handle(new Request(`http://admin.test${path}`, {
      headers: token ? { Authorization: `Bearer ${token}` } : {},
    }), { ip: '127.0.0.1' });
    return { status: res.status, json: await res.json() };
  };
  const tenant = (id, extra = {}) => fake.tables.tenants.push({ tenant_id: id, business_name: id.toUpperCase(), plan_id: 'startup', subscription_status: 'active', subscription_end_date: ago(-30), is_active: true, ...extra });
  return { fake, call, tenant };
}

test('usage activity: login, order or bill in the last 30 days makes an agency Active', async () => {
  const { fake, call, tenant } = setup();
  ['t_login', 't_order', 't_bill', 't_old', 't_none'].forEach(id => tenant(id));
  fake.tables.profiles.push({ id: 'p1', tenant_id: 't_login', role: 'owner', last_login_at: ago(3) });
  fake.tables.orders.push({ id: 'o1', order_id: 'O1', tenant_id: 't_order', order_date: ago(10) });
  fake.tables.invoices.push({ id: 'i1', invoice_id: 'I1', tenant_id: 't_bill', created_at: ago(29) });
  // Activity older than 30 days does not count
  fake.tables.profiles.push({ id: 'p2', tenant_id: 't_old', role: 'owner', last_login_at: ago(45) });
  fake.tables.orders.push({ id: 'o2', order_id: 'O2', tenant_id: 't_old', order_date: ago(60) });

  for (const path of ['/api/platform/tenants', '/api/platform/all']) {
    const r = await call(path);
    assert.equal(r.status, 200, path);
    const list = path.endsWith('all') ? r.json.data.tenants : r.json.tenants;
    const by = Object.fromEntries(list.map(t => [t.tenantId, t]));
    assert.equal(by.t_login.usageActive, true, `${path} login`);
    assert.equal(by.t_order.usageActive, true, `${path} order`);
    assert.equal(by.t_bill.usageActive, true, `${path} bill`);
    assert.equal(by.t_old.usageActive, false, `${path} old activity`);
    assert.equal(by.t_none.usageActive, false, `${path} no activity`);
    assert.equal(by.t_none.lastActiveAt, null);
    assert.ok(by.t_login.lastActiveAt);
  }
});

test('agency reports: ledger, purchases, expenses, orders and invoices return rows for that agency only', async () => {
  const { fake, call, tenant } = setup();
  tenant('t_a'); tenant('t_b');
  fake.tables.shops.push({ tenant_id: 't_a', shop_id: 's1', shop_name: 'Tata Store' });
  fake.tables.ledger_entries.push(
    { entry_id: 'L1', tenant_id: 't_a', shop_id: 's1', transaction_type: 'invoice', debit: 500, credit: 0, balance_after: 500, description: 'Bill', created_at: ago(2) },
    { entry_id: 'L2', tenant_id: 't_b', shop_id: 'x', transaction_type: 'invoice', debit: 9, credit: 0, balance_after: 9, created_at: ago(2) },
  );
  fake.tables.purchases.push({ purchase_id: 'P1', tenant_id: 't_a', supplier_name: 'HUL', total_amount: 1200, items: [{}, {}], date: ago(5) });
  fake.tables.expenses.push({ expense_id: 'E1', tenant_id: 't_a', category: 'Fuel', title: 'Diesel', amount: 300, payment_mode: 'cash', date: ago(1) });
  fake.tables.invoices.push({ invoice_id: 'I1', invoice_number: 'INV-1', tenant_id: 't_a', shop_id: 's1', invoice_type: 'estimate', grand_total: 500, amount_paid: 200, amount_due: 300, payment_status: 'partial', invoice_date: ago(2) });

  const ledger = await call('/api/platform/tenant/t_a/report?type=ledger');
  assert.equal(ledger.status, 200);
  assert.equal(ledger.json.rows.length, 1, 'other agency rows excluded');
  assert.equal(ledger.json.rows[0].party, 'Tata Store');
  assert.equal(ledger.json.rows[0].debit, 500);
  assert.deepEqual(ledger.json.columns.map(c => c.key), ['date', 'party', 'type', 'description', 'debit', 'credit', 'balance']);

  const purchases = await call('/api/platform/tenant/t_a/report?type=purchases');
  assert.equal(purchases.json.rows[0].supplier, 'HUL');
  assert.equal(purchases.json.rows[0].items, 2);

  const expenses = await call('/api/platform/tenant/t_a/report?type=expenses');
  assert.equal(expenses.json.rows[0].amount, 300);

  const invoices = await call('/api/platform/tenant/t_a/report?type=invoices');
  assert.equal(invoices.json.rows[0].billType, 'Estimate');
  assert.equal(invoices.json.rows[0].due, 300);

  const orders = await call('/api/platform/tenant/t_a/report?type=orders');
  assert.equal(orders.status, 200);
  assert.deepEqual(orders.json.rows, []);

  assert.equal((await call('/api/platform/tenant/t_a/report?type=bogus')).status, 400);
  assert.equal((await call('/api/platform/tenant/t_a/report?type=ledger', null)).status, 401);
  assert.ok(fake.tables.admin_audit_logs.some(l => /Ledger/.test(l.details || l.description || JSON.stringify(l))), 'export is audited');
});

test('saving platform settings drops the stale maintenanceMode copy (maintenance lives only in remote_config)', async () => {
  const fake = createFakeSupabase();
  fake.tables.platform_settings.push({ id: 'general_settings', data: { supportPhone: '1', maintenanceMode: false, defaultPlanId: 'startup' } });
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const res = await api.handle(new Request('http://admin.test/api/platform/settings', {
    method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${admin.token}` },
    body: JSON.stringify({ supportPhone: '9999999999', maintenanceMode: false }),
  }), { ip: '127.0.0.1' });
  assert.equal(res.status, 200);
  const saved = fake.tables.platform_settings.find(r => r.id === 'general_settings').data;
  assert.equal(saved.supportPhone, '9999999999');
  assert.equal('maintenanceMode' in saved, false);
});

test('maintenance message and ETA are saved with the maintenance switch', async () => {
  const { normalizeRemoteConfig } = await import('../api/catalog.mjs');
  const next = normalizeRemoteConfig({ maintenance: { active: true, message: 'Back at 6 PM', eta: '45 minutes' } }, {});
  assert.deepEqual(next.maintenance, { active: true, message: 'Back at 6 PM', eta: '45 minutes' });
});
