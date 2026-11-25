// Razorpay keys managed from the admin panel (Payment Gateway page):
// verified before saving, write-only (never returned), used by checkout and
// the webhook, environment keys as fallback, super admins only.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createApi } from '../api/handler.mjs';
import { createFakeSupabase, ENV } from './fake-supabase.mjs';

const GOOD = { keyId: 'rzp_test_AbCdEf123456', keySecret: 'SuperSecretValue9876' };

function setup({ env = ENV } = {}) {
  const fake = createFakeSupabase();
  const razorpayCalls = [];
  const fetchImpl = async (input, init = {}) => {
    const url = typeof input === 'string' ? input : input.url;
    if (url.startsWith('https://api.razorpay.com/')) {
      const auth = new Headers(init.headers).get('Authorization') || '';
      const creds = Buffer.from(auth.replace(/^Basic /, ''), 'base64').toString();
      razorpayCalls.push({ url, method: init.method || 'GET', creds });
      if (creds !== `${GOOD.keyId}:${GOOD.keySecret}`) {
        return new Response(JSON.stringify({ error: { description: 'Authentication failed' } }), { status: 401 });
      }
      if ((init.method || 'GET') === 'POST' && url.endsWith('/payment_links')) {
        return new Response(JSON.stringify({ id: 'plink_1', short_url: 'https://rzp.io/l/1', status: 'created' }), { status: 200 });
      }
      return new Response(JSON.stringify({ items: [], count: 0 }), { status: 200 });
    }
    return fake.fetchImpl(input, init);
  };
  const api = createApi(env, { fetchImpl });
  const admin = fake.addUser({ email: 'root@example.com', role: 'super_admin' });
  const owner = fake.addUser({ email: 'o@one.co', role: 'owner', tenant_id: 't1' });
  fake.tables.tenants.push({ tenant_id: 't1', business_name: 'Agency One', plan_id: 'startup', subscription_status: 'active', is_active: true });
  const call = async (method, path, { token = admin.token, body } = {}) => {
    const res = await api.handle(new Request(`http://admin.test${path}`, {
      method, headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: body === undefined ? undefined : JSON.stringify(body),
    }), { ip: '127.0.0.1' });
    const text = await res.text();
    return { status: res.status, text, json: JSON.parse(text) };
  };
  const stored = () => fake.tables.platform_settings.find(r => r.id === 'gateway_secrets')?.data;
  const webhook = async (raw, signature) => {
    const res = await api.handle(new Request('http://admin.test/api/checkout/webhook', {
      method: 'POST', headers: { 'Content-Type': 'application/json', 'x-razorpay-signature': signature }, body: raw,
    }), { ip: '127.0.0.1' });
    return res.status;
  };
  return { call, fake, admin, owner, razorpayCalls, stored, webhook };
}

test('invalid or incomplete keys are refused and nothing is saved', async () => {
  const { call, stored } = setup();
  assert.equal((await call('POST', '/api/platform/gateway/config', { body: { keyId: 'abc', keySecret: GOOD.keySecret } })).status, 400);
  assert.equal((await call('POST', '/api/platform/gateway/config', { body: { keySecret: 'leak' } })).status, 400);
  assert.equal((await call('POST', '/api/platform/gateway/config', { body: { keyId: GOOD.keyId, keySecret: 'has space here' } })).status, 400);
  assert.equal(stored(), undefined);
});

test('keys Razorpay rejects are not saved', async () => {
  const { call, stored } = setup();
  const r = await call('POST', '/api/platform/gateway/config', { body: { keyId: GOOD.keyId, keySecret: 'WrongSecret12345' } });
  assert.equal(r.status, 400);
  assert.match(r.json.error, /Razorpay rejected these keys/);
  assert.equal(stored(), undefined);
});

test('verified keys are saved, used, and the secret is never returned', async () => {
  const { call, stored, razorpayCalls } = setup();
  const r = await call('POST', '/api/platform/gateway/config', { body: { ...GOOD, webhookSecret: 'whsec_fromadmin', merchantName: 'SalesArmy' } });
  assert.equal(r.status, 200, r.text);
  assert.equal(stored().keySecret, GOOD.keySecret);
  assert.equal(r.text.includes(GOOD.keySecret), false, 'save response must not echo the secret');

  const view = await call('GET', '/api/platform/gateway/config');
  assert.equal(view.json.config.keyId, GOOD.keyId);
  assert.equal(view.json.config.managedBy, 'admin');
  assert.equal(view.json.config.hasSecret, true);
  assert.equal(view.json.config.secretHint, '••••9876');
  assert.equal(view.json.config.hasWebhookSecret, true);
  assert.equal(view.text.includes(GOOD.keySecret), false);
  assert.equal(view.text.includes('whsec_fromadmin'), false);

  // Connection test uses the saved keys
  const t = await call('POST', '/api/platform/gateway/test');
  assert.equal(t.json.success, true);
  assert.equal(razorpayCalls.at(-1).creds, `${GOOD.keyId}:${GOOD.keySecret}`);

  // Audit log never contains the secret
  const audit = JSON.stringify((await call('GET', '/api/platform/audit-logs')).json);
  assert.equal(audit.includes(GOOD.keySecret), false);
  assert.match(audit, /GATEWAY_KEYS_UPDATED/);

  // Leaving the secret empty keeps the saved one
  const keep = await call('POST', '/api/platform/gateway/config', { body: { merchantName: 'SalesArmy Pvt' } });
  assert.equal(keep.status, 200);
  assert.equal(stored().keySecret, GOOD.keySecret);
});

test('webhook signature is checked with the admin-panel webhook secret', async () => {
  const { call, webhook } = setup();
  const raw = JSON.stringify({ event: 'payment.authorized' });
  const sign = async secret => {
    const key = await crypto.subtle.importKey('raw', new TextEncoder().encode(secret), { name: 'HMAC', hash: 'SHA-256' }, false, ['sign']);
    return Buffer.from(await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(raw))).toString('hex');
  };
  // Before: only the environment webhook secret (ENV: whsec_test) is valid
  assert.equal(await webhook(raw, await sign('whsec_test')), 200);
  assert.equal(await webhook(raw, await sign('whsec_fromadmin')), 401);
  // After saving a webhook secret in the admin panel, that one is used
  const saved = await call('POST', '/api/platform/gateway/config', { body: { ...GOOD, webhookSecret: 'whsec_fromadmin' } });
  assert.equal(saved.status, 200, saved.text);
  assert.equal(await webhook(raw, await sign('whsec_fromadmin')), 200);
  assert.equal(await webhook(raw, await sign('whsec_test')), 401);
});

test('removing saved keys falls back to the environment keys', async () => {
  const env = { ...ENV, RAZORPAY_KEY_ID: 'rzp_test_EnvKey000000', RAZORPAY_KEY_SECRET: 'EnvSecretValue000' };
  const { call } = setup({ env });
  assert.equal((await call('GET', '/api/platform/gateway/config')).json.config.managedBy, 'environment');
  await call('POST', '/api/platform/gateway/config', { body: GOOD });
  assert.equal((await call('GET', '/api/platform/gateway/config')).json.config.keyId, GOOD.keyId);
  const cleared = await call('POST', '/api/platform/gateway/config', { body: { clearKeys: true } });
  assert.equal(cleared.status, 200);
  const view = (await call('GET', '/api/platform/gateway/config')).json.config;
  assert.equal(view.managedBy, 'environment');
  assert.equal(view.keyId, 'rzp_test_EnvKey000000');
});

test('only super admins can change keys', async () => {
  const { call, owner, stored } = setup();
  const r = await call('POST', '/api/platform/gateway/config', { token: owner.token, body: GOOD });
  assert.equal(r.status, 403);
  assert.equal(stored(), undefined);
});
