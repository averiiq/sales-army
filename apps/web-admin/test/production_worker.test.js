const { test } = require('node:test');
const assert = require('node:assert/strict');

const env = {
  SUPABASE_URL: 'https://ivwvqpeivnltshrxjhjx.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3ZxcGVpdm5sdHNocnhqaGp4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTE4MTcyNTgsImV4cCI6MjEwNzM5MzI1OH0.pkwOLQUyP0Te719UKV5s6wZ_GNXDe9AOMaeqkH0H-iY',
  SUPABASE_SERVICE_ROLE_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Iml2d3ZxcGVpdm5sdHNocnhqaGp4Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc5MTgxNzI1OCwiZXhwIjoyMTA3MzkzMjU4fQ.swVBzLlo-fQ3xc1ezYD_VcPKElnTKa6ZyBMjeU1sjxM',
  ENABLE_DEMO_AUTH: 'true'
};

test('Production _worker.js endpoints are functional and return real data from Supabase', async () => {
  const mod = await import('../_worker.js');
  const worker = mod.default;

  // 1. Supabase Client Discovery
  const rConfig = await worker.fetch(new Request('http://localhost/api/config/supabase'), env);
  assert.equal(rConfig.status, 200);
  const jConfig = await rConfig.json();
  assert.equal(jConfig.success, true);
  assert.ok(jConfig.supabaseUrl);
  assert.ok(jConfig.supabaseAnonKey);

  // 2. Authentication: Super Admin Login
  const rLogin = await worker.fetch(new Request('http://localhost/api/auth/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: 'superadmin@salesarmy.saas', password: 'Password@123' })
  }), env);
  assert.equal(rLogin.status, 200);
  const jLogin = await rLogin.json();
  assert.equal(jLogin.success, true);
  assert.ok(jLogin.token);
  assert.equal(jLogin.user?.role, 'super_admin');

  // 3. Platform State Aggregation: GET /api/platform/all
  const rAll = await worker.fetch(new Request('http://localhost/api/platform/all'), env);
  assert.equal(rAll.status, 200);
  const jAll = await rAll.json();
  assert.equal(jAll.success, true);
  assert.ok(Array.isArray(jAll.data?.tenants));
  assert.ok(jAll.data.tenants.length >= 1, 'Should load live tenants from Supabase');
  assert.ok(Array.isArray(jAll.data?.users));
  assert.ok(jAll.data.users.length >= 1, 'Should load live profiles from Supabase');
  assert.ok(Array.isArray(jAll.data?.plans?.tiers));

  // 4. Live Tenants: GET /api/platform/tenants
  const rTenants = await worker.fetch(new Request('http://localhost/api/platform/tenants'), env);
  assert.equal(rTenants.status, 200);
  const jTenants = await rTenants.json();
  assert.equal(jTenants.success, true);
  assert.ok(Array.isArray(jTenants.tenants));
  assert.ok(jTenants.tenants.length >= 1);

  // 5. Live Users: GET /api/platform/users
  const rUsers = await worker.fetch(new Request('http://localhost/api/platform/users'), env);
  assert.equal(rUsers.status, 200);
  const jUsers = await rUsers.json();
  assert.equal(jUsers.success, true);
  assert.ok(Array.isArray(jUsers.users));
  assert.ok(jUsers.users.length >= 1);

  // 6. Broadcast Announcement: GET /api/platform/broadcast
  const rBroadcast = await worker.fetch(new Request('http://localhost/api/platform/broadcast'), env);
  assert.equal(rBroadcast.status, 200);
  const jBroadcast = await rBroadcast.json();
  assert.equal(jBroadcast.success, true);
  assert.ok(jBroadcast.broadcast);

  // 7. Gateway Settings: GET /api/platform/gateway/config
  const rGateway = await worker.fetch(new Request('http://localhost/api/platform/gateway/config'), env);
  assert.equal(rGateway.status, 200);
  const jGateway = await rGateway.json();
  assert.equal(jGateway.success, true);
  assert.ok(jGateway.config);

  // 8. Health Probe: GET /api/platform/health
  const rHealth = await worker.fetch(new Request('http://localhost/api/platform/health'), env);
  assert.equal(rHealth.status, 200);
  const jHealth = await rHealth.json();
  assert.equal(jHealth.success, true);
  assert.equal(jHealth.status, 'healthy');
});

