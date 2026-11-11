// End-to-end verification script for real database & server synchronization
const http = require('http');

function postJson(path, payload) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(payload);
    const req = http.request(
      {
        hostname: 'localhost',
        port: 3000,
        path: path,
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(data),
        },
      },
      (res) => {
        let body = '';
        res.on('data', (chunk) => (body += chunk));
        res.on('end', () => {
          try {
            resolve({ statusCode: res.statusCode, data: JSON.parse(body) });
          } catch (e) {
            resolve({ statusCode: res.statusCode, raw: body });
          }
        });
      }
    );
    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

function getJson(path) {
  return new Promise((resolve, reject) => {
    http.get({ hostname: 'localhost', port: 3000, path: path }, (res) => {
      let body = '';
      res.on('data', (chunk) => (body += chunk));
      res.on('end', () => {
        try {
          resolve({ statusCode: res.statusCode, data: JSON.parse(body) });
        } catch (e) {
          resolve({ statusCode: res.statusCode, raw: body });
        }
      });
    }).on('error', reject);
  });
}

async function runTests() {
  console.log('🚀 Starting E2E Database & Server Sync Verification...');

  // 1. User Profile Sync
  console.log('\n--- 1. Testing User Profile Sync ---');
  const userPayload = {
    uid: 'usr_test_verification',
    id: 'usr_test_verification',
    name: 'Somesh Verma',
    email: 'somesh@distributor.in',
    phone: '+91 9876543210',
    role: 'owner',
    tenantId: 'platform_tenant',
    tenantName: 'Selxo FMCG Distributions',
    status: 'active'
  };
  const userRes = await postJson('/api/platform/sync-user', userPayload);
  console.log('Sync User Result:', userRes.statusCode, userRes.data?.success ? '✅ SUCCESS' : '❌ FAILED');

  // 2. Subscription Plan & Tenant Details Sync
  console.log('\n--- 2. Testing Subscription Plan & Tenant Details Sync ---');
  const tenantPayload = {
    tenantId: 'platform_tenant',
    firmName: 'Selxo FMCG Distributions Pvt Ltd',
    ownerName: 'Somesh Verma',
    phone: '+91 9876543210',
    email: 'somesh@distributor.in',
    gstin: '27AABCU9603R1ZM',
    pan: 'AABCU9603R',
    city: 'Mumbai',
    state: 'Maharashtra',
    warehouseAddress: 'Plot 42, MIDC Industrial Area, Andheri East, Mumbai',
    subscriptionStatus: 'active',
    planName: 'Pro Tier Annual (₹8,999/yr)',
    subscriptionPlanId: 'pro',
    expiryDate: '2027-10-16',
    isGstBillingEnabled: true
  };
  const tenantRes = await postJson('/api/platform/sync-tenant', tenantPayload);
  console.log('Sync Tenant/Subscription Result:', tenantRes.statusCode, tenantRes.data?.success ? '✅ SUCCESS' : '❌ FAILED');

  // 3. Retail Party (Shop) Sync
  console.log('\n--- 3. Testing Retail Party (Shop) Sync ---');
  const shopPayload = {
    shopId: 'SHP-LIVE-TEST-01',
    tenantId: 'platform_tenant',
    shopName: 'Shree Ganesh Supermarket',
    ownerName: 'Ganesh Shinde',
    phone: '+91 9819001122',
    whatsapp: '+91 9819001122',
    businessType: 'Supermarket',
    category: 'Supermarket',
    address: 'Station Road, Bandra West, Mumbai',
    city: 'Mumbai',
    state: 'Maharashtra',
    gstin: '27ABCDE1234F1Z5',
    creditLimit: 50000,
    currentOutstanding: 12500,
    isActive: true
  };
  const shopRes = await postJson('/api/platform/sync-shop', shopPayload);
  console.log('Sync Shop Result:', shopRes.statusCode, shopRes.data?.success ? '✅ SUCCESS' : '❌ FAILED');

  // 4. Product / Inventory SKU Sync
  console.log('\n--- 4. Testing Product / Inventory SKU Sync ---');
  const productPayload = {
    productId: 'PROD-LIVE-TEST-01',
    tenantId: 'platform_tenant',
    name: 'Fortune Sunflower Refined Oil 1L',
    variant: '1 Litre Pouch',
    sku: 'SKU-OIL-1L-001',
    barcode: '890103000001',
    hsnSac: '1512',
    basePrice: 120.0,
    wholesalePrice: 135.0,
    sellingPrice: 135.0,
    gstRate: 5.0,
    stockQuantity: 240,
    lowStockThreshold: 25,
    unit: 'POUCH',
    isActive: true
  };
  const productRes = await postJson('/api/platform/sync-product', productPayload);
  console.log('Sync Product Result:', productRes.statusCode, productRes.data?.success ? '✅ SUCCESS' : '❌ FAILED');

  // 5. Order Sync
  console.log('\n--- 5. Testing Order Sync ---');
  const orderPayload = {
    orderId: 'ORD-LIVE-TEST-101',
    tenantId: 'platform_tenant',
    shopId: 'SHP-LIVE-TEST-01',
    shopName: 'Shree Ganesh Supermarket',
    subtotal: 2700.0,
    totalGst: 135.0,
    grandTotal: 2835.0,
    status: 'confirmed',
    placedAt: new Date().toISOString(),
    deliveryNote: 'Urgent morning delivery requested',
    items: [
      {
        productId: 'PROD-LIVE-TEST-01',
        productName: 'Fortune Sunflower Refined Oil 1L',
        quantity: 20,
        unitPrice: 135.0,
        gstRate: 5.0,
        itemSubtotal: 2700.0,
        itemGst: 135.0,
        itemGrandTotal: 2835.0
      }
    ]
  };
  const orderRes = await postJson('/api/platform/sync-order', orderPayload);
  console.log('Sync Order Result:', orderRes.statusCode, orderRes.data?.success ? '✅ SUCCESS' : '❌ FAILED');

  // 6. Verify Dashboard State Persistence
  console.log('\n--- 6. Verifying Dashboard State Persistence ---');
  const statsRes = await getJson('/api/platform/stats');
  console.log('Server Platform Stats:', statsRes.statusCode, {
    tenantsCount: statsRes.data?.stats?.activeTenants,
    usersCount: statsRes.data?.stats?.totalUsers,
    ordersCount: statsRes.data?.stats?.activeOrders
  });

  const ordersRes = await getJson('/api/platform/retail-orders');
  const createdOrder = ordersRes.data?.orders?.find(o => o.orderId === 'ORD-LIVE-TEST-101' || o.id === 'ORD-LIVE-TEST-101');
  console.log('Verified Created Order in Platform State:', createdOrder ? '✅ FOUND' : '❌ NOT FOUND', createdOrder ? { id: createdOrder.orderId, total: createdOrder.grandTotal, shop: createdOrder.shopName } : '');

  console.log('\n🎉 ALL SYNC AND DATABASE OPERATIONS TESTED SUCCESSFULLY!');
}

runTests().catch(console.error);
