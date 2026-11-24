// Plan governance: no free plan, admin-controlled signup trial, capabilities
// and limits that the API enforces.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { normalizeTier, normalizePlans, signupTrial, CAPABILITY_KEYS, LEGACY_IMPLICIT_FEATURES, TENANT_STATUSES } from '../api/catalog.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

function setup({ settings, plans } = {}) {
  const fake = createFakeSupabase();
  const api = createApi(ENV, { fetchImpl: fake.fetchImpl });
  if (settings) fake.tables.platform_settings.push({ id: 'general_settings', data: settings });
  if (plans) fake.tables.platform_settings.push({ id: 'pricing_and_plans', data: { plans } });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin', name: 'Root' });
  const call = async (method, path, { token, body } = {}) => {
    const res = await api.handle(new Request(`http://admin.test${path}`, {
      method,
      headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    }), { ip: '127.0.0.1' });
    const text = await res.text();
    let json; try { json = JSON.parse(text); } catch (_) { json = text; }
    return { status: res.status, json };
  };
  return { fake, call, admin };
}

const agency = email => ({ accountType: 'agency', businessName: 'Trial Traders', name: 'Asha', email, phone: '9000000001', password: 'LongPass#123', city: 'Pune' });

test('there is no free plan or freemium status', () => {
  assert.ok(!TENANT_STATUSES.includes('freemium'));
  assert.throws(() => normalizeTier({ id: 'free', name: 'Free' }), /free/);
});

test('self-signup gets the admin signup trial plan for the configured days', async () => {
  const { fake, call } = setup({ settings: { defaultPlanId: 'grow', defaultTrialDays: 21, trialGracePeriodDays: 2 } });
  const before = Date.now();
  const r = await call('POST', '/api/auth/signup', { body: agency('asha@trial.co') });
  assert.equal(r.status, 201);
  const t = fake.tables.tenants.find(x => x.tenant_id === r.json.tenantId);
  assert.equal(t.plan_id, 'grow');
  assert.equal(t.subscription_status, 'trial');
  const days = (new Date(t.subscription_end_date).getTime() - before) / 86400000;
  assert.ok(days > 20.9 && days < 21.1, `trial length ${days}`);
  assert.equal(t.max_users, 5, 'seat mirror comes from the plan');
});

test('a stale "free" default falls back to a real plan', async () => {
  const { fake, call } = setup({ settings: { defaultPlanId: 'free', defaultTrialDays: 14 } });
  const r = await call('POST', '/api/auth/signup', { body: agency('old@free.co') });
  assert.equal(r.status, 201);
  assert.equal(fake.tables.tenants.find(x => x.tenant_id === r.json.tenantId).plan_id, 'startup');
});

test('signup trial plan must be an existing plan', async () => {
  const { call, admin } = setup();
  assert.equal((await call('POST', '/api/platform/settings', { token: admin.token, body: { defaultPlanId: 'free' } })).status, 400);
  assert.equal((await call('POST', '/api/platform/settings', { token: admin.token, body: { defaultPlanId: 'ghost' } })).status, 400);
  assert.equal((await call('POST', '/api/platform/settings', { token: admin.token, body: { defaultPlanId: 'enterprise', defaultTrialDays: 7 } })).status, 200);
});

test('admins cannot move an agency to a free plan / freemium status', async () => {
  const { fake, call, admin } = setup();
  fake.tables.tenants.push({ tenant_id: 'tenant_x', business_name: 'X', mobile: '9', plan_id: 'startup', subscription_status: 'trial', is_active: true });
  assert.equal((await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'tenant_x', subscriptionPlanId: 'free' } })).status, 400);
  assert.equal((await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'tenant_x', subscriptionStatus: 'freemium' } })).status, 400);
  const ok = await call('POST', '/api/platform/sync-tenant', { token: admin.token, body: { id: 'tenant_x', subscriptionStatus: 'expired' } });
  assert.equal(ok.status, 200);
  assert.equal(ok.json.tenant.isReadOnly, true);
});

test('a lapsed trial is reported as expired (after grace)', async () => {
  const { fake, call, admin } = setup({ settings: { defaultPlanId: 'startup', defaultTrialDays: 14, trialGracePeriodDays: 3 } });
  const day = 86400000;
  fake.tables.tenants.push(
    { tenant_id: 'in_grace', business_name: 'G', mobile: '1', plan_id: 'startup', subscription_status: 'trial', is_active: true, subscription_end_date: new Date(Date.now() - 2 * day).toISOString() },
    { tenant_id: 'lapsed', business_name: 'L', mobile: '2', plan_id: 'startup', subscription_status: 'trial', is_active: true, subscription_end_date: new Date(Date.now() - 4 * day).toISOString() },
  );
  const r = await call('GET', '/api/platform/tenants', { token: admin.token });
  const byId = Object.fromEntries(r.json.tenants.map(t => [t.id, t]));
  assert.equal(byId.in_grace.subscriptionStatus, 'trial');
  assert.equal(byId.lapsed.subscriptionStatus, 'expired');
});

test('expired agencies and plans without staff logins cannot add staff', async () => {
  const { fake, call } = setup();
  fake.tables.tenants.push({ tenant_id: 'tenant_e', business_name: 'E', mobile: '1', plan_id: 'grow', subscription_status: 'expired', is_active: true, max_users: 5 });
  const owner = fake.addUser({ email: 'owner@e.com', role: 'owner', tenant_id: 'tenant_e', name: 'Owner E' });
  const staff = { accountType: 'staff', name: 'S', email: 's@e.com', password: 'LongPass#1', role: 'sales_person' };
  assert.equal((await call('POST', '/api/auth/signup', { token: owner.token, body: staff })).status, 402);

  const plans = { tiers: [{ id: 'solo', name: 'Solo', monthlyPrice: 99, maxStaff: 10, allowedFeatures: ['order_taking'], featuresVersion: 2 }] };
  const s2 = setup({ plans });
  s2.fake.tables.tenants.push({ tenant_id: 'tenant_s', business_name: 'S', mobile: '1', plan_id: 'solo', subscription_status: 'active', is_active: true });
  const owner2 = s2.fake.addUser({ email: 'owner@s.com', role: 'owner', tenant_id: 'tenant_s', name: 'Owner S' });
  assert.equal((await s2.call('POST', '/api/auth/signup', { token: owner2.token, body: staff })).status, 402);
});

test('saving plans updates every tenant mirror on that plan', async () => {
  const { fake, call, admin } = setup();
  fake.tables.tenants.push({ tenant_id: 'tenant_g', business_name: 'G', mobile: '1', plan_id: 'grow', subscription_status: 'active', is_active: true, max_users: 5, max_shops: 1000 });
  const tiers = normalizePlans({ tiers: [{ id: 'grow', name: 'Grow', monthlyPrice: 599, maxStaff: 8, maxShops: 1500 }] }).tiers;
  const r = await call('POST', '/api/platform/update', { token: admin.token, body: { plans: { tiers } } });
  assert.equal(r.status, 200);
  const t = fake.tables.tenants.find(x => x.tenant_id === 'tenant_g');
  assert.equal(t.max_users, 8);
  assert.equal(t.max_shops, 1500);
});

test('capabilities: unknown keys dropped, legacy plans keep what the app never locked', () => {
  const legacy = normalizeTier({ id: 'grow', name: 'Grow', monthlyPrice: 1, allowedFeatures: ['invoicing', 'hack_everything'] });
  assert.ok(!legacy.allowedFeatures.includes('hack_everything'));
  for (const k of LEGACY_IMPLICIT_FEATURES) assert.ok(legacy.allowedFeatures.includes(k), k);
  assert.equal(legacy.featuresVersion, 2);

  // Once v2, the admin's ticks are authoritative (can lock order taking).
  const v2 = normalizeTier({ id: 'grow', name: 'Grow', monthlyPrice: 1, allowedFeatures: ['invoicing'], featuresVersion: 2 });
  assert.deepEqual(v2.allowedFeatures, ['invoicing']);
  assert.ok(CAPABILITY_KEYS.includes('order_taking'));
});

test('limits: 0 means unlimited, staff and users stay in sync', () => {
  const t = normalizeTier({ id: 'big', name: 'Big', monthlyPrice: 1, maxStaff: 0, maxProducts: 0, maxShops: 0, maxOrdersPerMonth: 0 });
  assert.equal(t.maxStaff, 0);
  assert.equal(t.maxUsers, 0);
  assert.equal(t.maxProducts, 0);
  const u = normalizeTier({ id: 'old', name: 'Old', monthlyPrice: 1, maxUsers: 7 });
  assert.equal(u.maxStaff, 7);
  assert.throws(() => normalizeTier({ id: 'neg', name: 'Neg', monthlyPrice: 1, maxShops: -1 }));
});

test('signupTrial helper', () => {
  const trial = signupTrial({ defaultPlanId: 'enterprise', defaultTrialDays: 10 }, null, 0);
  assert.equal(trial.planId, 'enterprise');
  assert.equal(trial.status, 'trial');
  assert.equal(trial.endDate, new Date(10 * 86400000).toISOString());
  assert.equal(signupTrial({ defaultPlanId: 'nope' }, null).planId, 'startup');
});
