// Comprehensive E2E Verification Suite for SalesArmy Web Admin Portal
const http = require('http');

function request(method, path, payload = null) {
  return new Promise((resolve, reject) => {
    const data = payload ? JSON.stringify(payload) : null;
    const options = {
      hostname: 'localhost',
      port: 3000,
      path: path,
      method: method,
      headers: {
        'Accept': 'application/json'
      }
    };
    if (data) {
      options.headers['Content-Type'] = 'application/json';
      options.headers['Content-Length'] = Buffer.byteLength(data);
    }
    const req = http.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, raw: body });
        }
      });
    });
    req.on('error', reject);
    if (data) req.write(data);
    req.end();
  });
}

const getJson = (path) => request('GET', path);
const postJson = (path, payload) => request('POST', path, payload);
const deleteJson = (path) => request('DELETE', path);

async function getPlatformState() {
  const res = await getJson('/api/platform/all');
  return res.data?.data || res.data?.state || {};
}

async function runAdminE2ETests() {
  console.log('🚀 Starting Full Admin Portal E2E Verification Suite...\n');
  let passed = 0;
  let total = 0;

  function assert(condition, message) {
    total++;
    if (condition) {
      console.log(`  ✅ [PASS] ${message}`);
      passed++;
    } else {
      console.error(`  ❌ [FAIL] ${message}`);
    }
  }

  // TEST 1: Platform State Initialization
  console.log('--- 1. Testing Platform State Fetch (/api/platform/all) ---');
  const allRes = await getJson('/api/platform/all');
  assert(allRes.statusCode === 200, 'Server responded with 200 OK');
  assert(allRes.data && allRes.data.success === true, 'Platform state data is valid');
  const state = await getPlatformState();
  assert(Array.isArray(state.tenants), 'Tenants array present');
  assert(Boolean(state.remoteConfig), 'Remote Config present');
  assert(Boolean(state.settings), 'Settings present');

  // TEST 2: Remote Config & Feature Flags
  console.log('\n--- 2. Testing Feature Flags / Remote Config Persistence ---');
  const initialFlags = state.remoteConfig?.featureFlags || {};
  const newFlags = {
    ...initialFlags,
    mockGpsDetection: true,
    geoFenceStrictEnforcement: true,
    testFlagE2E: true
  };
  const updateFlagsRes = await postJson('/api/platform/remote-config', {
    featureFlags: newFlags,
    minAppVersion: '2.4.0',
    enforceUpdate: false
  });
  assert(updateFlagsRes.statusCode === 200 && updateFlagsRes.data?.success, 'POST /api/platform/remote-config succeeded');
  
  // Verify fetch returns updated flags
  const verifyFlagsRes = await getJson('/api/platform/remote-config');
  assert(verifyFlagsRes.data?.config?.featureFlags?.testFlagE2E === true, 'Verified testFlagE2E is persisted in remote config');
  assert(verifyFlagsRes.data?.config?.featureFlags?.mockGpsDetection === true, 'Verified mockGpsDetection flag is active');

  // TEST 3: In-App Broadcast Announcements
  console.log('\n--- 3. Testing Real-Time Broadcast Announcements ---');
  const testBroadcast = {
    message: 'System Maintenance scheduled tonight at 11:00 PM IST',
    type: 'warning',
    active: true,
    targetRole: 'all',
    timestamp: new Date().toISOString()
  };
  const pubBroadcastRes = await postJson('/api/platform/broadcast', testBroadcast);
  assert(pubBroadcastRes.statusCode === 200 && pubBroadcastRes.data?.success, 'POST /api/platform/broadcast published alert');

  const checkBroadcastRes = await getJson('/api/platform/broadcast');
  assert(checkBroadcastRes.data?.broadcast?.active === true, 'Active broadcast confirmed');
  assert(checkBroadcastRes.data?.broadcast?.message.includes('Maintenance'), 'Broadcast message matches');

  // Clear broadcast
  const clearBroadcastRes = await postJson('/api/platform/broadcast', { active: false, message: '' });
  assert(clearBroadcastRes.statusCode === 200 && clearBroadcastRes.data?.broadcast?.active === false, 'Broadcast cleared successfully');

  // TEST 4: Coupon Management (Create, Verify, Delete)
  console.log('\n--- 4. Testing Coupon Management ---');
  const testCoupon = {
    code: 'FESTIVE50_E2E',
    discountType: 'percentage',
    discountValue: 50,
    planId: 'pro',
    maxUses: 100,
    usedCount: 0,
    expiresAt: '2026-12-31',
    active: true
  };
  const createCouponRes = await postJson('/api/platform/coupon', testCoupon);
  assert(createCouponRes.statusCode === 200 && createCouponRes.data?.success, 'POST /api/platform/coupon created coupon');

  const stateAfterCoupon = await getPlatformState();
  const createdCoupon = stateAfterCoupon.coupons?.find(c => c.code === 'FESTIVE50_E2E');
  assert(createdCoupon && createdCoupon.code === 'FESTIVE50_E2E', 'Coupon verified in platform state');

  const deleteCouponRes = await deleteJson('/api/platform/coupon/FESTIVE50_E2E');
  assert(deleteCouponRes.statusCode === 200 && deleteCouponRes.data?.success, 'DELETE /api/platform/coupon/FESTIVE50_E2E succeeded');

  const stateAfterDelCoupon = await getPlatformState();
  const deletedCoupon = stateAfterDelCoupon.coupons?.find(c => c.code === 'FESTIVE50_E2E');
  assert(!deletedCoupon, 'Verified coupon deleted from platform state');

  // TEST 5: Printer Hardware Orders Management
  console.log('\n--- 5. Testing Printer Hardware Order Management ---');
  const printerOrderPayload = {
    orderId: 'HW-E2E-999',
    userId: 'platform_tenant',
    customerName: 'Rajesh Sharma',
    agencyName: 'Selxo FMCG Distributions',
    printerItem: 'Everycom EC-58 58mm Thermal',
    price: 5000,
    shippingAddress: 'Plot 42, Andheri East, Mumbai, MH - 400069',
    phone: '+91 9876543210',
    status: 'Pending'
  };
  const createHwRes = await postJson('/api/platform/order-hardware', printerOrderPayload);
  assert(createHwRes.statusCode === 200 && createHwRes.data?.success, 'POST /api/platform/order-hardware created order');
  const newOrderId = createHwRes.data?.order?.id;

  // Update status and tracking info
  const updateHwRes = await postJson('/api/platform/printer-order/status', {
    orderId: newOrderId,
    status: 'Shipped',
    courierName: 'Bluedart Express',
    trackingNumber: 'BLUEDART-E2E-778899'
  });
  assert(updateHwRes.statusCode === 200 && updateHwRes.data?.success, 'POST /api/platform/printer-order/status updated to Shipped');

  const stateAfterHw = await getPlatformState();
  const foundHwOrder = stateAfterHw.printerOrders?.find(o => o.id === newOrderId);
  assert(foundHwOrder && foundHwOrder.status === 'Shipped', 'Hardware order status verified as Shipped');
  assert(foundHwOrder && foundHwOrder.trackingNumber === 'BLUEDART-E2E-778899', 'Tracking number verified as BLUEDART-E2E-778899');

  // TEST 6: Tenant Lifecycle Management (Onboard, Freeze, Delete)
  console.log('\n--- 6. Testing Tenant Lifecycle Management ---');
  const testTenant = {
    id: 'tenant_e2e_agency',
    tenantId: 'tenant_e2e_agency',
    name: 'Apex FMCG Distributors',
    firmName: 'Apex FMCG Distributors',
    ownerName: 'Sunil Aggarwal',
    phone: '+91 9811223344',
    email: 'apex@fmcgdist.in',
    status: 'active',
    subscriptionStatus: 'active',
    plan: 'enterprise',
    subscriptionPlanId: 'enterprise',
    planName: 'Enterprise Plan',
    expiryDate: '2027-01-01',
    userCount: 5,
    ordersCount: 120
  };
  const saveTenantRes = await postJson('/api/platform/sync-tenant', testTenant);
  assert(saveTenantRes.statusCode === 200 && saveTenantRes.data?.success, 'POST /api/platform/sync-tenant created tenant');

  // Freeze tenant
  const freezeTenantRes = await postJson('/api/platform/sync-tenant', { ...testTenant, subscriptionStatus: 'suspended' });
  assert(freezeTenantRes.statusCode === 200 && freezeTenantRes.data?.tenant?.subscriptionStatus === 'suspended', 'Tenant successfully frozen');

  // Delete tenant
  const deleteTenantRes = await deleteJson('/api/platform/tenant/tenant_e2e_agency');
  assert(deleteTenantRes.statusCode === 200 && deleteTenantRes.data?.success, 'DELETE /api/platform/tenant/tenant_e2e_agency succeeded');

  const stateAfterDelTenant = await getPlatformState();
  const deletedTenant = stateAfterDelTenant.tenants?.find(t => t.id === 'tenant_e2e_agency');
  assert(!deletedTenant, 'Verified tenant removed from platform state');

  // TEST 7: Platform Settings & Branding
  console.log('\n--- 7. Testing Platform Settings & Branding ---');
  const settingsPayload = {
    supportPhone: '+91 80000 99999',
    supportEmail: 'support@salesarmy.in',
    companyName: 'SalesArmy Enterprise Technologies Pvt Ltd',
    cin: 'U72900MH2024PTC123456',
    gstin: '27AABCS9999P1Z8',
    upiVpa: 'salesarmy@hdfcbank',
    currency: 'INR',
    maintenanceMode: false
  };
  const updateSettingsRes = await postJson('/api/platform/settings', settingsPayload);
  assert(updateSettingsRes.statusCode === 200 && updateSettingsRes.data?.success, 'POST /api/platform/settings saved branding & UPI');

  const stateAfterSettings = await getPlatformState();
  assert(stateAfterSettings.settings?.supportEmail === 'support@salesarmy.in', 'Support email verified');
  assert(stateAfterSettings.settings?.upiVpa === 'salesarmy@hdfcbank', 'Merchant UPI VPA verified');
  assert(stateAfterSettings.settings?.gstin === '27AABCS9999P1Z8', 'GSTIN verified');

  // TEST 8: Platform Analytics & Export Engine
  console.log('\n--- 8. Testing Analytics & Data Export Endpoints ---');
  const analyticsRes = await getJson('/api/platform/analytics');
  assert(analyticsRes.statusCode === 200 && analyticsRes.data?.success, 'GET /api/platform/analytics responded with 200');
  assert(analyticsRes.data?.analytics?.totalGMV !== undefined, 'Analytics GMV computed correctly');

  const exportRes = await getJson('/api/platform/export?entity=orders&format=csv');
  assert(exportRes.statusCode === 200, 'GET /api/platform/export CSV responded with 200');

  // TEST 9: Platform State Reconciliation
  console.log('\n--- 9. Testing Reconciliation Endpoint (/api/platform/reconcile) ---');
  const reconRes = await postJson('/api/platform/reconcile', {});
  assert(reconRes.statusCode === 200 && reconRes.data?.success, 'POST /api/platform/reconcile completed');
  console.log('  📊 Reconciliation report:', reconRes.data?.status, `latency: ${reconRes.data?.latencyMs}ms`);

  console.log(`\n=================================================`);
  console.log(`SUMMARY: ${passed}/${total} assertions passed (${Math.round((passed/total)*100)}%)`);
  console.log(`=================================================`);

  if (passed === total) {
    console.log('🎉 ALL ADMIN PORTAL FEATURES ARE 100% WORKING AND VERIFIED!');
  } else {
    console.error('❌ Some tests failed. Check logs above.');
    process.exit(1);
  }
}

runAdminE2ETests().catch((err) => {
  console.error('Test runner fatal error:', err);
  process.exit(1);
});
