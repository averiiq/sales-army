const { test } = require('node:test');
const assert = require('node:assert/strict');
const { authenticate, validatePlatformUpdate, publicPlatformState, PUBLIC_ROUTES } = require('../security');

test('authentication passes the caller token and uses database role, not metadata', async () => {
  const calls = [];
  const fetchImpl = async (url, options) => {
    calls.push({ url, options });
    return { ok: true, json: async () => calls.length === 1
      ? { id: 'user-1', email: 'superadmin@example.test', user_metadata: { role: 'super_admin' } }
      : [{ id: 'user-1', role: 'sales_person', account_status: 'active', is_active: true }] };
  };
  const result = await authenticate({ headers: { authorization: 'Bearer caller-token' } }, { url: 'https://example.test', anonKey: 'anon', serviceKey: 'service', fetchImpl });
  assert.equal(calls[0].options.headers.Authorization, 'Bearer caller-token');
  assert.equal(result.role, 'sales_person');
});

test('missing credentials, suspended accounts and invalid tokens fail closed', async () => {
  const config = { url: 'https://example.test', anonKey: 'anon', serviceKey: 'service' };
  assert.equal(await authenticate({ headers: {} }, config), null);
  assert.equal(await authenticate({ headers: { authorization: 'Bearer invalid' } }, { ...config, fetchImpl: async () => ({ ok: false }) }), null);
  let count = 0;
  const fetchImpl = async () => ({ ok: true, json: async () => ++count === 1 ? { id: 'u' } : [{ account_status: 'suspended', role: 'super_admin' }] });
  assert.equal(await authenticate({ headers: { authorization: 'Bearer token' } }, { ...config, fetchImpl }), null);
});

test('administrative state and operational mutations are never public routes', () => {
  for (const route of ['POST /api/platform/update', 'POST /api/platform/sync-user', 'GET /api/platform/all', 'GET /api/platform/events', 'DELETE /api/platform/tenant/one']) assert.equal(PUBLIC_ROUTES.has(route), false);
});

test('public configuration excludes personal data and credential settings', () => {
  const result = publicPlatformState({ plans: {}, users: ['private'], tenants: ['private'], settings: { passcode: 'private' }, printerOrders: ['private'] });
  assert.equal('users' in result, false);
  assert.equal('settings' in result, false);
  assert.equal('tenants' in result, false);
});

test('catalog validation permits empty deletable catalogs but rejects corrupt state and credentials', () => {
  assert.deepEqual(validatePlatformUpdate({ coupons: [], printerOptions: [] }), { coupons: [], printerOptions: [] });
  assert.throws(() => validatePlatformUpdate({ settings: { passcode: 'secret' } }));
  assert.throws(() => validatePlatformUpdate({ plans: { tiers: [] } }));
  assert.throws(() => validatePlatformUpdate({ printerOptions: [{ id: 'p', name: 'Printer', price: -1 }] }));
  assert.throws(() => validatePlatformUpdate({ users: {} }));
});
