import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

function setup() {
  const fake = createFakeSupabase();
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  fake.tables.tenants.push({ tenant_id: 'tenant_a', business_name: 'Agency A', mobile: '9999999999', plan_id: 'startup', subscription_status: 'active', is_active: true, max_users: 2, max_shops: 200 });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const call = async (method, path, { token, body } = {}) => {
    const res = await api.handle(new Request(`http://admin.test${path}`, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    }), { ip: '127.0.0.1' });
    return { status: res.status, json: await res.json() };
  };
  return { fake, call, admin };
}

test('dashboard snapshot warns (instead of silently showing zeros) when the admin DB functions are missing', async () => {
  const { fake, call, admin } = setup();
  const ok = await call('GET', '/api/platform/all', { token: admin.token });
  assert.equal(ok.status, 200);
  assert.deepEqual(ok.json.data.warnings, []);

  delete fake.rpcs.admin_platform_stats; // live DB without 20261123000000
  const missing = await call('GET', '/api/platform/all', { token: admin.token });
  assert.equal(missing.status, 200);
  assert.equal(missing.json.data.warnings.length, 1);
  assert.match(missing.json.data.warnings[0], /20261123000000_admin_platform_hardening/);
});

test('per-agency limits accept 0 (= unlimited), like plan limits, and still reject negatives', async () => {
  const { fake, call, admin } = setup();
  const r = await call('POST', '/api/platform/tenant', { token: admin.token, body: { id: 'tenant_a', maxUsers: 0, maxShops: 0 } });
  assert.equal(r.status, 200, JSON.stringify(r.json));
  const row = fake.tables.tenants.find(t => t.tenant_id === 'tenant_a');
  assert.equal(row.max_users, 0);
  assert.equal(row.max_shops, 0);

  const bad = await call('POST', '/api/platform/tenant', { token: admin.token, body: { id: 'tenant_a', maxUsers: -1 } });
  assert.equal(bad.status, 400);
});
