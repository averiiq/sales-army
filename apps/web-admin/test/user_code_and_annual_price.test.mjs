// Unique User ID (tenants.user_code, SA-USR-XXXX) is what the admin shows for
// agencies and their users, and edited annual prices are not reverted.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { normalizeTier } from '../api/catalog.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

test('admin shows the agency SA-USR code as the Unique User ID (agencies + users)', async () => {
  const fake = createFakeSupabase();
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const call = async path => {
    const res = await api.handle(new Request(`http://admin.test${path}`, { headers: { Authorization: `Bearer ${admin.token}` } }), { ip: '127.0.0.1' });
    return { status: res.status, json: await res.json() };
  };
  fake.tables.tenants.push(
    { tenant_id: 'tenant_sharma_ab12cd34', user_code: 'SA-USR-1001', business_name: 'Sharma', plan_id: 'startup', subscription_status: 'active', is_active: true },
    { tenant_id: 'tenant_legacy', business_name: 'Legacy', plan_id: 'startup', subscription_status: 'active', is_active: true },
  );
  fake.tables.profiles.push({ id: 'p1', name: 'Owner', email: 'o@example.com', role: 'owner', tenant_id: 'tenant_sharma_ab12cd34', account_status: 'active', is_active: true });

  const all = await call('/api/platform/all');
  assert.equal(all.status, 200);
  const byId = Object.fromEntries(all.json.data.tenants.map(t => [t.tenantId, t]));
  assert.equal(byId.tenant_sharma_ab12cd34.userId, 'SA-USR-1001');
  assert.equal(byId.tenant_sharma_ab12cd34.userCode, 'SA-USR-1001');
  assert.equal(byId.tenant_legacy.userId, 'tenant_legacy', 'falls back to tenant_id before the migration runs');
  assert.equal(all.json.data.users.find(u => u.id === 'p1').userId, 'SA-USR-1001');

  const users = await call('/api/platform/users');
  assert.equal(users.json.users.find(u => u.id === 'p1').userId, 'SA-USR-1001');
});

test('edited annual price survives server normalisation', () => {
  const stored = normalizeTier({ id: 'startup', name: 'Startup', monthlyPrice: 399, yearlyPrice: 3828 });
  // What the admin plan editor now sends after changing the annual rate to ₹399/mo.
  const edited = { ...stored, monthlyPrice: 499, yearlyMonthlyEquivalent: 399, annualPrice: 4788, yearlyPrice: 4788 };
  const saved = normalizeTier(edited);
  assert.equal(saved.yearlyPrice, 4788);
  assert.equal(saved.yearlyMonthlyEquivalent, 399);
});
