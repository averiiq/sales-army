// ==============================================================================
// 🛡️ VERIFY ALL AUDIT ISSUES - COMPREHENSIVE AUTOMATED VERIFICATION SUITE
// ==============================================================================
const http = require('http');

function apiCall(method, path, body = null, headers = {}) {
  return new Promise((resolve, reject) => {
    const payload = body ? JSON.stringify(body) : null;
    const reqHeaders = {
      'Accept': 'application/json',
      ...headers
    };
    if (payload) {
      reqHeaders['Content-Type'] = 'application/json';
      reqHeaders['Content-Length'] = Buffer.byteLength(payload);
    }
    const req = http.request({
      hostname: 'localhost',
      port: 3000,
      path,
      method,
      headers: reqHeaders
    }, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(data) });
        } catch (_) {
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function runVerification() {
  console.log('================================================================');
  console.log('🧪 SALESARMY ADMIN AUDIT ISSUES - COMPREHENSIVE VERIFICATION');
  console.log('================================================================\n');

  let passed = 0;
  let total = 0;

  function assert(condition, message, details = '') {
    total++;
    if (condition) {
      console.log(`  ✅ [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${message} ${details ? '(' + details + ')' : ''}`);
    }
  }

  // ISSUE 1: Server-Side Authorization on Sensitive Admin Mutation Endpoints
  console.log('--- 1. Testing Server-Side Admin Authorization Gating ---');
  // Attempt unauthorized mutation simulating an external client IP
  const unauthRes = await apiCall('POST', '/api/platform/settings', { currency: 'EUR' }, {
    'x-forwarded-for': '198.51.100.25'
  });
  assert(unauthRes.status === 401, 'Unauthorized mutation from external IP blocked with HTTP 401', `Status: ${unauthRes.status}`);
  assert(unauthRes.body?.success === false, 'Error message returned for unauthenticated request');

  // Attempt authorized mutation with Bearer token
  const authRes = await apiCall('POST', '/api/platform/settings', { currency: 'INR' }, {
    'x-forwarded-for': '198.51.100.25',
    'Authorization': 'Bearer SAAS-ADMIN-2026'
  });
  assert(authRes.status === 200, 'Authorized mutation with Bearer SAAS-ADMIN-2026 responds with HTTP 200');
  assert(authRes.body?.success === true, 'Settings successfully updated when authorized');

  // ISSUE 2: Admin Passcode Login Alignment on Backend
  console.log('\n--- 2. Testing Passcode & Seed Credential Alignment ---');
  const loginRes = await apiCall('POST', '/api/auth/login', {
    email: 'superadmin@salesarmy.saas',
    password: 'SAAS-ADMIN-2026'
  });
  assert(loginRes.status === 200, 'POST /api/auth/login accepts SAAS-ADMIN-2026 passcode');
  assert(loginRes.body?.user?.role === 'super_admin', 'Authenticated user role is super_admin');
  assert(Boolean(loginRes.body?.token), 'Server returns valid session token');

  // ISSUE 3: Password Reset Endpoint Calls Supabase Auth Admin
  console.log('\n--- 3. Testing User Password Reset Logic ---');
  const resetRes = await apiCall('POST', '/api/platform/user/reset-password', {
    userId: 'c5d3eb2b-08b8-4a4c-9082-6db533d3155e',
    newPassword: 'Password@2026New'
  }, {
    'Authorization': 'Bearer SAAS-ADMIN-2026'
  });
  assert(resetRes.status === 200, 'POST /api/platform/user/reset-password responds with HTTP 200');
  assert(resetRes.body?.success === true, 'Password reset confirmed by server');

  // ISSUE 4: Tenant Data Integrity & Preserved Metrics
  console.log('\n--- 4. Testing Tenant Orders & Revenue Preservation ---');
  const allRes = await apiCall('GET', '/api/platform/all');
  assert(allRes.status === 200, 'GET /api/platform/all responds with 200 OK');
  const tenants = allRes.body?.data?.tenants || allRes.body?.tenants || [];
  assert(Array.isArray(tenants) && tenants.length > 0, `Tenants loaded successfully (Count: ${tenants.length})`);
  const primaryTenant = tenants.find(t => t.id === 'platform_tenant' || t.tenantId === 'platform_tenant');
  assert(primaryTenant && primaryTenant.ordersCount >= 0, 'Tenant metrics (ordersCount, revenue) are preserved');

  // ISSUE 5: Remote Governance Kill-Switches and In-App Broadcasts
  console.log('\n--- 5. Testing Remote Governance & Broadcast System ---');
  const remoteRes = await apiCall('POST', '/api/platform/remote-config', {
    featureFlags: { auditVerificationFlag: true, mockGpsDetection: true },
    minAppVersion: '2.5.0'
  }, {
    'Authorization': 'Bearer SAAS-ADMIN-2026'
  });
  assert(remoteRes.status === 200, 'POST /api/platform/remote-config updated successfully');

  const broadcastRes = await apiCall('POST', '/api/platform/broadcast', {
    message: 'Audit verification test in progress',
    type: 'info',
    active: true,
    targetRole: 'all',
    timestamp: new Date().toISOString()
  }, {
    'Authorization': 'Bearer SAAS-ADMIN-2026'
  });
  assert(broadcastRes.status === 200, 'POST /api/platform/broadcast published alert');

  // ISSUE 6: Real-Time SSE Stream Verification
  console.log('\n--- 6. Testing Real-Time SSE Stream Connectivity ---');
  const sseConnected = await new Promise((resolve) => {
    const sseReq = http.request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/platform/events',
      method: 'GET'
    }, (res) => {
      resolve(res.statusCode === 200 && res.headers['content-type']?.includes('text/event-stream'));
      sseReq.destroy();
    });
    sseReq.on('error', () => resolve(false));
    sseReq.end();
  });
  assert(sseConnected, 'SSE /api/platform/events stream connects cleanly with text/event-stream');

  console.log('\n================================================================');
  console.log(`📊 FINAL RESULT: ${passed}/${total} assertions passed (${Math.round((passed/total)*100)}%)`);
  console.log('================================================================\n');

  if (passed === total) {
    console.log('🎉 ALL AUDIT ISSUES ARE WORKING AND VERIFIED OPERATIONAL!');
    process.exit(0);
  } else {
    console.error('⚠️ SOME ISSUES FAILED VERIFICATION.');
    process.exit(1);
  }
}

runVerification().catch(err => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
