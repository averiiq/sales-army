'use strict';

const PUBLIC_ROUTES = new Set([
  'GET /api/config/supabase',
  'GET /api/platform/public',
  'GET /api/platform/legal',
  'GET /api/legal',
  'GET /api/auth/roles',
  'POST /api/auth/login',
  'POST /api/auth/signup',
  // 'GET /api/auth/tenants' removed — requires authentication to prevent tenant data exposure.
]);

function bearerToken(req) {
  const header = req.headers.authorization;
  return typeof header === 'string' && header.startsWith('Bearer ') ? header.slice(7).trim() : '';
}

async function authenticate(req, { url, anonKey, serviceKey, fetchImpl = fetch }) {
  const token = bearerToken(req);
  if (!token || !url || !anonKey || !serviceKey) return null;
  const response = await fetchImpl(`${url.replace(/\/$/, '')}/auth/v1/user`, {
    headers: { apikey: anonKey, Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!response.ok) return null;
  const user = await response.json();
  if (!user.id) return null;
  const profileResponse = await fetchImpl(`${url.replace(/\/$/, '')}/rest/v1/profiles?id=eq.${encodeURIComponent(user.id)}&select=id,role,tenant_id,account_status,is_active`, {
    headers: { apikey: serviceKey, Authorization: `Bearer ${serviceKey}` },
    signal: AbortSignal.timeout(10000),
  });
  if (!profileResponse.ok) return null;
  const [profile] = await profileResponse.json();
  if (!profile || profile.is_active === false || profile.account_status !== 'active') return null;
  return { ...profile, email: user.email };
}

function publicPlatformState(state) {
  return {
    plans: state.plans,
    printerOptions: state.printerOptions,
    subscriptionAddons: state.subscriptionAddons || [],
    remoteConfig: state.remoteConfig,
    broadcast: state.broadcast,
  };
}

function validatePlatformUpdate(payload) {
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) throw new Error('Expected a state object');
  const allowed = new Set(['plans', 'printerOptions', 'subscriptionAddons', 'coupons', 'tenants', 'users', 'remoteConfig', 'broadcast', 'printerOrders', 'retailOrders', 'notifications', 'settings']);
  for (const key of Object.keys(payload)) {
    if (!allowed.has(key)) throw new Error(`Unsupported state field: ${key}`);
    const isList = ['printerOptions', 'subscriptionAddons', 'coupons', 'tenants', 'users', 'printerOrders', 'retailOrders', 'notifications'].includes(key);
    if (isList ? !Array.isArray(payload[key]) : !payload[key] || typeof payload[key] !== 'object' || Array.isArray(payload[key])) {
      throw new Error(`Invalid state field: ${key}`);
    }
  }
  if (payload.plans && (!Array.isArray(payload.plans.tiers) || !payload.plans.tiers.length)) throw new Error('At least one subscription tier is required');
  for (const item of [...(payload.plans?.tiers || []), ...(payload.printerOptions || []), ...(payload.subscriptionAddons || [])]) {
    if (!item.id || !item.name && !item.title) throw new Error('Catalog entries require an ID and name');
    for (const field of ['price', 'monthlyPrice', 'annualPrice', 'yearlyPrice', 'gstRate']) {
      if (item[field] !== undefined && (typeof item[field] !== 'number' || !Number.isFinite(item[field]) || item[field] < 0)) throw new Error(`Invalid ${field}`);
    }
  }
  if (/"(passcode|adminPasscode|password|keySecret|webhookSecret)"\s*:/i.test(JSON.stringify(payload))) throw new Error('Credentials must not be stored in platform state');
  return payload;
}

module.exports = { PUBLIC_ROUTES, authenticate, publicPlatformState, validatePlatformUpdate };
