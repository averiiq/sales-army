// Subscriber profile reports (client spec): Parties, All Orders, Orders party / city /
// state-wise, Ledger all / party-wise — called exactly as the profile page does
// (type + partyId | city | state query parameters).
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

const ago = d => new Date(Date.now() - d * 86400000).toISOString();

function setup() {
  const fake = createFakeSupabase();
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  fake.tables.tenants.push(
    { tenant_id: 't_a', business_name: 'Agency A', plan_id: 'grow', subscription_status: 'active', is_active: true },
    { tenant_id: 't_b', business_name: 'Agency B', plan_id: 'grow', subscription_status: 'active', is_active: true },
  );
  fake.tables.shops.push(
    { tenant_id: 't_a', shop_id: 's1', shop_name: 'Tata Store', city: 'Indore', state: 'Madhya Pradesh', current_outstanding: 500 },
    { tenant_id: 't_a', shop_id: 's2', shop_name: 'Ram Kirana', city: 'Bhopal', state: 'Madhya Pradesh', current_outstanding: 0 },
    { tenant_id: 't_a', shop_id: 's3', shop_name: 'Pune Mart', city: 'Pune', state: 'Maharashtra', current_outstanding: 0 },
    { tenant_id: 't_b', shop_id: 'x1', shop_name: 'Other Agency Shop', city: 'Indore', state: 'Madhya Pradesh' },
  );
  const order = (id, tenant, shop) => ({ id, order_id: id, tenant_id: tenant, shop_id: shop, status: 'confirmed', grand_total: 100, order_date: ago(1), items: [] });
  fake.tables.orders.push(order('O1', 't_a', 's1'), order('O2', 't_a', 's2'), order('O3', 't_a', 's3'), order('O4', 't_a', 's1'), order('X1', 't_b', 'x1'));
  fake.tables.ledger_entries.push(
    { entry_id: 'L1', tenant_id: 't_a', shop_id: 's1', transaction_type: 'invoice', debit: 500, credit: 0, balance_after: 500, created_at: ago(2) },
    { entry_id: 'L2', tenant_id: 't_a', shop_id: 's2', transaction_type: 'invoice', debit: 200, credit: 0, balance_after: 200, created_at: ago(2) },
  );
  const report = async query => {
    const res = await api.handle(new Request(`http://admin.test/api/platform/tenant/t_a/report?${query}`, {
      headers: { Authorization: `Bearer ${admin.token}` },
    }), { ip: '127.0.0.1' });
    return { status: res.status, json: await res.json() };
  };
  const overview = async () => {
    const res = await api.handle(new Request('http://admin.test/api/platform/tenant/t_a/overview', {
      headers: { Authorization: `Bearer ${admin.token}` },
    }), { ip: '127.0.0.1' });
    return res.json();
  };
  return { report, overview };
}

const ids = r => r.json.rows.map(x => x.orderId).sort();

test('profile pickers get parties with city and state from the overview', async () => {
  const { overview } = setup();
  const o = await overview();
  assert.equal(o.success, true);
  assert.deepEqual(o.shops.map(s => s.shop_id).sort(), ['s1', 's2', 's3'], 'only this agency');
  assert.ok(o.shops.every(s => 'city' in s && 'state' in s));
});

test('Parties report lists this agency\'s parties only', async () => {
  const { report } = setup();
  const r = await report('type=parties');
  assert.equal(r.status, 200, JSON.stringify(r.json));
  assert.deepEqual(r.json.rows.map(x => x.shopId).sort(), ['s1', 's2', 's3']);
});

test('Orders: all, party-wise, city-wise and state-wise', async () => {
  const { report } = setup();
  assert.deepEqual(ids(await report('type=orders')), ['O1', 'O2', 'O3', 'O4']);
  assert.deepEqual(ids(await report('type=orders&partyId=s1')), ['O1', 'O4']);
  assert.deepEqual(ids(await report('type=orders&city=Bhopal')), ['O2']);
  assert.deepEqual(ids(await report('type=orders&state=Madhya+Pradesh')), ['O1', 'O2', 'O4']);
});

test('Ledger: all parties and party-wise', async () => {
  const { report } = setup();
  assert.equal((await report('type=ledger')).json.rows.length, 2);
  const one = await report('type=ledger&partyId=s2');
  assert.equal(one.json.rows.length, 1);
  assert.equal(one.json.rows[0].party, 'Ram Kirana');
});
