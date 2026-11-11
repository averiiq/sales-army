const { test } = require('node:test');
const assert = require('node:assert/strict');
const http = require('node:http');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { fork } = require('node:child_process');
const { once } = require('node:events');

test('real HTTP admin routes reject bypasses and persist dynamic configuration', { timeout: 30000 }, async () => {
  const settings = new Map();
  let rejectWrites = false;
  const upstream = http.createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    const body = raw ? JSON.parse(raw) : null;
    const url = new URL(req.url, 'http://localhost');
    res.setHeader('Content-Type', 'application/json');
    if (url.pathname === '/auth/v1/user') {
      const token = req.headers.authorization;
      if (!['Bearer admin-valid', 'Bearer staff-valid'].includes(token)) {
        res.writeHead(401); res.end('{}'); return;
      }
      res.end(JSON.stringify({ id: token === 'Bearer admin-valid' ? 'admin' : 'staff', user_metadata: { role: 'super_admin' } })); return;
    }
    if (url.pathname.startsWith('/auth/v1/admin/users/')) { res.writeHead(422); res.end('{}'); return; }
    if (url.pathname === '/rest/v1/profiles' && url.searchParams.has('id')) {
      res.end(JSON.stringify([{ id: url.searchParams.get('id').slice(3), role: url.searchParams.get('id') === 'eq.admin' ? 'super_admin' : 'sales_person', account_status: 'active', is_active: true }])); return;
    }
    if (req.method === 'GET') {
      res.end(JSON.stringify(url.pathname.endsWith('/platform_settings') ? [...settings.values()] : [])); return;
    }
    if (rejectWrites) { res.writeHead(503); res.end('{}'); return; }
    if (url.pathname.endsWith('/rpc/admin_apply_changes')) {
      for (const job of body.p_jobs) {
        if (job.table === 'platform_settings') for (const row of job.rows) settings.set(row.id, row);
      }
    }
    if (url.pathname.endsWith('/platform_settings')) settings.set(body.id, body);
    res.writeHead(201); res.end('{}');
  });
  upstream.listen(0, '127.0.0.1');
  await once(upstream, 'listening');
  const baseTempDir = process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'Temp') : os.tmpdir();
  fs.mkdirSync(baseTempDir, { recursive: true });
  const directory = fs.mkdtempSync(path.join(baseTempDir, 'admin-api-'));
  const child = fork(path.join(__dirname, '../server.js'), [], {
    env: { ...process.env, PORT: '0', HOST: '127.0.0.1', STATE_DIRECTORY: directory,
      NODE_ENV: 'test', SUPABASE_URL: `http://127.0.0.1:${upstream.address().port}`,
      SUPABASE_ANON_KEY: 'test-anon', SUPABASE_SERVICE_ROLE_KEY: 'test-service', ALLOWED_ORIGINS: '', ENABLE_DEMO_AUTH: 'false' },
    stdio: ['ignore', 'ignore', 'pipe', 'ipc'],
  });
  child.stderr.on('data', () => {});
  try {
    const [{ port }] = await once(child, 'message');
    const request = (route, method = 'GET', body, token) => fetch(`http://127.0.0.1:${port}${route}`, {
      method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    for (const token of [undefined, 'SAAS-ADMIN-2026', 'demo_access_token_owner_forged', 'staff-valid']) {
      assert.equal((await request('/api/platform/update', 'POST', { coupons: [] }, token)).status, 401);
    }
    assert.equal((await request('/api/platform/all')).status, 401);
    assert.equal((await request('/server.js')).status, 403);
    const publicData = await (await request('/api/platform/public')).json();
    assert.equal('users' in publicData.data, false);
    const updated = await request('/api/platform/update', 'POST', {
      coupons: [], printerOptions: [], subscriptionAddons: [{ id: 'roll', title: 'Paper', price: 99 }],
      plans: { tiers: [{ id: 'launch', name: 'Launch', monthlyPrice: 123, yearlyPrice: 1230 }] },
      remoteConfig: { maintenance: { active: true }, featureFlags: { purchases: false } },
    }, 'admin-valid');
    assert.equal(updated.status, 200, await updated.text());
    assert.equal(settings.get('pricing_and_plans').data.plans.tiers[0].monthlyPrice, 123);
    assert.equal(settings.get('remote_config').data.maintenance.active, true);
    const state = JSON.parse(fs.readFileSync(path.join(directory, 'platform_state.json'), 'utf8'));
    assert.equal(state.subscriptionAddons[0].price, 99);
    assert.deepEqual(state.coupons, []);
    assert.equal((await request('/api/platform/user/reset-password', 'POST', { userId: 'admin', newPassword: 'test-password-123' }, 'admin-valid')).status, 500);
    rejectWrites = true;
    assert.equal((await request('/api/platform/update', 'POST', { remoteConfig: { maintenance: { active: false } } }, 'admin-valid')).status, 500);
    const afterFailure = await (await request('/api/platform/all', 'GET', undefined, 'admin-valid')).json();
    assert.equal(afterFailure.data.remoteConfig.maintenance.active, true);
  } finally {
    child.kill();
    await once(child, 'exit');
    await new Promise(resolve => upstream.close(resolve));
    fs.rmSync(directory, { recursive: true });
  }
});
