// Smoke test for the Cloudflare Worker entry (_worker.js) against the real
// Supabase project. NO keys or passwords live in this file: they are read
// from apps/web-admin/.env (git-ignored). Without them the test is skipped.
const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

function loadEnv() {
  const env = { ...process.env };
  const file = path.join(__dirname, '..', '.env');
  if (fs.existsSync(file)) {
    for (const line of fs.readFileSync(file, 'utf8').split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (m && !line.trim().startsWith('#') && env[m[1]] === undefined) env[m[1]] = m[2].replace(/^["']|["']$/g, '');
    }
  }
  return {
    SUPABASE_URL: env.SUPABASE_URL,
    SUPABASE_ANON_KEY: env.SUPABASE_ANON_KEY,
    SUPABASE_SERVICE_ROLE_KEY: env.SUPABASE_SERVICE_ROLE_KEY,
  };
}

const env = loadEnv();
const configured = Boolean(env.SUPABASE_URL && env.SUPABASE_ANON_KEY && env.SUPABASE_SERVICE_ROLE_KEY);

test('Production _worker.js: public endpoints work, admin endpoints require sign-in', { skip: !configured && 'Supabase keys not in .env' }, async () => {
  const worker = (await import('../_worker.js')).default;
  const call = (p, init) => worker.fetch(new Request(`https://admin.example${p}`, init), env);

  const config = await call('/api/config/supabase');
  assert.equal(config.status, 200);
  const jConfig = await config.json();
  assert.equal(jConfig.supabaseUrl, env.SUPABASE_URL);
  assert.ok(jConfig.supabaseAnonKey);

  const health = await call('/api/platform/health');
  assert.equal(health.status, 200);
  assert.equal((await health.json()).database, 'reachable');

  const pub = await call('/api/platform/public');
  assert.equal(pub.status, 200);
  assert.ok(Array.isArray((await pub.json()).data?.plans?.tiers));

  // Admin data is never served without a Super Admin token.
  for (const p of ['/api/platform/all', '/api/platform/tenants', '/api/platform/users', '/api/platform/gateway/config']) {
    assert.equal((await call(p)).status, 401, p);
  }

  // Wrong password is rejected normally (proves the auth path reaches Supabase).
  const login = await call('/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'nobody@example.com', password: 'not-a-real-password' }),
  });
  assert.equal(login.status, 401);

  // Responses carry the security headers.
  assert.equal(health.headers.get('X-Frame-Options'), 'DENY');
  assert.match(health.headers.get('Content-Security-Policy') || '', /default-src 'self'/);
});
