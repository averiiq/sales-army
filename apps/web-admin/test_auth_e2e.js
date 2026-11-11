const http = require('http');
const https = require('https');

function request(options, body = null) {
  return new Promise((resolve, reject) => {
    const isHttps = options.protocol === 'https:' || options.port === 443;
    const client = isHttps ? https : http;
    const req = client.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, headers: res.headers, body: JSON.parse(data) });
        } catch {
          resolve({ status: res.statusCode, headers: res.headers, body: data });
        }
      });
    });
    req.on('error', reject);
    if (body) {
      req.write(typeof body === 'string' ? body : JSON.stringify(body));
    }
    req.end();
  });
}

async function runAuthTests() {
  console.log('====================================================');
  console.log('🧪 SALESARMY END-TO-END AUTH & RBAC VERIFICATION');
  console.log('====================================================\n');

  // Test 1: GET /api/auth/roles
  console.log('1️⃣ Testing GET /api/auth/roles ...');
  const rolesRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/auth/roles',
    method: 'GET'
  });
  console.log(`   Response Status: ${rolesRes.status}`);
  if (rolesRes.status === 200 && Array.isArray(rolesRes.body.roles)) {
    console.log(`   ✅ Success! Retrieved ${rolesRes.body.roles.length} RBAC roles: ${rolesRes.body.roles.map(r => r.id).join(', ')}`);
  } else {
    console.error('   ❌ Failed to get roles:', rolesRes.body);
  }

  // Test 2: GET /api/auth/tenants
  console.log('\n2️⃣ Testing GET /api/auth/tenants ...');
  const tenantsRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/auth/tenants',
    method: 'GET'
  });
  console.log(`   Response Status: ${tenantsRes.status}`);
  if (tenantsRes.status === 200 && Array.isArray(tenantsRes.body.tenants)) {
    console.log(`   ✅ Success! Retrieved ${tenantsRes.body.tenants.length} database tenants.`);
    tenantsRes.body.tenants.slice(0, 3).forEach(t => {
      console.log(`      - [${t.tenant_id}] ${t.business_name} (${t.city || 'N/A'})`);
    });
  } else {
    console.error('   ❌ Failed to get tenants:', tenantsRes.body);
  }

  // Test 3: Log in as Seeded Distributor and Seeded Sales Person
  console.log('\n3️⃣ Testing POST /api/auth/login for Seeded Accounts ...');
  const testAccounts = [
    { email: 'distributor@salesarmy.com', role: 'owner' },
    { email: 'sales@salesarmy.com', role: 'sales_person' },
    { email: 'accountant@salesarmy.com', role: 'accountant' },
    { email: 'superadmin@salesarmy.saas', role: 'super_admin' }
  ];

  for (const acc of testAccounts) {
    const loginRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    }, {
      email: acc.email,
      password: 'Password@123'
    });

    if (loginRes.status === 200 && loginRes.body.user) {
      console.log(`   ✅ Login Successful: ${acc.email} | Role: ${loginRes.body.user.role} | Tenant: ${loginRes.body.user.tenant_id}`);
    } else {
      console.error(`   ❌ Login Failed for ${acc.email}:`, loginRes.body);
    }
  }

  // Test 4: Dynamic Account Creation - New Agency Tenant Onboarding
  const timestamp = Date.now().toString().slice(-5);
  const testAgencyName = `Kalyan FMCG Agency ${timestamp}`;
  const testOwnerEmail = `owner.kalyan.${timestamp}@salesarmy.com`;
  const testPassword = 'Password@123';

  console.log(`\n4️⃣ Testing Agency Onboarding (POST /api/auth/signup) ...`);
  console.log(`   Registering Agency: "${testAgencyName}" with Owner: "${testOwnerEmail}"`);

  const signupAgencyRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/auth/signup',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, {
    accountType: 'agency',
    businessName: testAgencyName,
    representativeName: `Kalyan Shinde`,
    email: testOwnerEmail,
    password: testPassword,
    phone: '9876543210',
    city: 'Thane, Mumbai',
    gstin: '27AABCU9603R1ZM'
  });

  let newTenantId = null;
  if (signupAgencyRes.status === 201 && signupAgencyRes.body.tenant_id) {
    newTenantId = signupAgencyRes.body.tenant_id;
    console.log(`   ✅ Agency Successfully Created! Tenant ID: ${newTenantId}`);
    console.log(`      Owner User ID: ${signupAgencyRes.body.uid}`);
  } else {
    console.error('   ❌ Agency Signup Failed:', signupAgencyRes.body);
  }

  // Test 5: Log in with newly registered Agency Owner
  console.log(`\n5️⃣ Testing Login with Newly Created Agency Owner (${testOwnerEmail}) ...`);
  const newOwnerLoginRes = await request({
    hostname: 'localhost',
    port: 3000,
    path: '/api/auth/login',
    method: 'POST',
    headers: { 'Content-Type': 'application/json' }
  }, {
    email: testOwnerEmail,
    password: testPassword
  });

  if (newOwnerLoginRes.status === 200 && newOwnerLoginRes.body.user) {
    console.log(`   ✅ New Owner Authenticated!`);
    console.log(`      User ID: ${newOwnerLoginRes.body.user.id}`);
    console.log(`      Tenant: ${newOwnerLoginRes.body.user.tenant_id} (${newOwnerLoginRes.body.tenant?.business_name})`);
    console.log(`      Permissions: ${newOwnerLoginRes.body.permissions?.length || 0} RBAC permissions assigned`);
  } else {
    console.error('   ❌ New Owner Login Failed:', newOwnerLoginRes.body);
  }

  // Test 6: Dynamic Staff User Signup under the new agency
  if (newTenantId) {
    const testStaffEmail = `sales.kalyan.${timestamp}@salesarmy.com`;
    console.log(`\n6️⃣ Testing Staff Signup under Agency [${newTenantId}] (${testStaffEmail}) ...`);

    const signupStaffRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/auth/signup',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    }, {
      accountType: 'staff',
      name: 'Sunil Kadam',
      email: testStaffEmail,
      password: testPassword,
      phone: '9811223344',
      role: 'sales_person',
      tenantId: newTenantId
    });

    if (signupStaffRes.status === 201 && signupStaffRes.body.uid) {
      console.log(`   ✅ Staff Member Successfully Registered! UID: ${signupStaffRes.body.uid}`);
      console.log(`      Role: ${signupStaffRes.body.role} | Tenant ID: ${signupStaffRes.body.tenant_id}`);
    } else {
      console.error('   ❌ Staff Signup Failed:', signupStaffRes.body);
    }

    // Test 7: Log in with newly registered Staff Member
    console.log(`\n7️⃣ Testing Login with Newly Created Staff Member (${testStaffEmail}) ...`);
    const newStaffLoginRes = await request({
      hostname: 'localhost',
      port: 3000,
      path: '/api/auth/login',
      method: 'POST',
      headers: { 'Content-Type': 'application/json' }
    }, {
      email: testStaffEmail,
      password: testPassword
    });

    if (newStaffLoginRes.status === 200 && newStaffLoginRes.body.user) {
      console.log(`   ✅ New Staff Authenticated!`);
      console.log(`      User ID: ${newStaffLoginRes.body.user.id}`);
      console.log(`      Role: ${newStaffLoginRes.body.user.role}`);
      console.log(`      Assigned Tenant: ${newStaffLoginRes.body.user.tenant_id} (${newStaffLoginRes.body.tenant?.business_name})`);
      console.log(`      Field Sales Permissions: ${newStaffLoginRes.body.permissions?.join(', ')}`);
    } else {
      console.error('   ❌ New Staff Login Failed:', newStaffLoginRes.body);
    }
  }

  console.log('\n====================================================');
  console.log('🎉 ALL AUTHENTICATION & RBAC TESTS COMPLETED!');
  console.log('====================================================');
}

runAuthTests().catch(err => {
  console.error('Fatal error running tests:', err);
});
