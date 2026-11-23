// Catalog defaults, normalisation and validation shared by the admin API and
// the subscription checkout. Every value written to platform_settings passes
// through these functions so the mobile app, the admin UI and checkout agree
// on one shape.
import { HttpError } from './supabase.mjs';

export const ROLES = ['super_admin', 'owner', 'distributor', 'sales_person', 'accountant', 'delivery_agent', 'manager'];
export const STAFF_ROLES = ['sales_person', 'accountant', 'delivery_agent', 'manager'];
const ROLE_ALIASES = { salesman: 'sales_person', delivery: 'delivery_agent', store_manager: 'manager', warehouse: 'manager', accounts: 'accountant' };
export const TENANT_STATUSES = ['trial', 'active', 'freemium', 'expired', 'suspended', 'cancelled'];
export const ORDER_STATUSES = ['pending', 'confirmed', 'processing', 'dispatched', 'delivered', 'completed', 'cancelled', 'draft'];
export const HARDWARE_STATUSES = ['processing', 'packed', 'shipped', 'in_transit', 'delivered', 'cancelled'];

export function canonicalRole(role) {
  const r = String(role || '').toLowerCase().trim();
  return ROLE_ALIASES[r] || r;
}

export const DEFAULT_TIERS = [
  { id: 'startup', name: 'Startup', badge: 'Starter Pass', monthlyPrice: 399, yearlyPrice: 3828, yearlyMonthlyEquivalent: 319, maxUsers: 1, maxShops: 200, maxProducts: 50, isActive: true,
    features: ['1 Proprietor seat', 'Up to 200 Retail Shops', 'GST & Estimate Invoicing', '58mm Thermal Printing'] },
  { id: 'grow', name: 'Grow', badge: 'Most Popular', monthlyPrice: 599, yearlyPrice: 5748, yearlyMonthlyEquivalent: 479, maxUsers: 5, maxShops: 1000, maxProducts: 200, highlight: true, isActive: true,
    features: ['Up to 5 Staff Users', 'Up to 1,000 Retail Shops', 'Dynamic UPI QR on Bills', 'Van Stock & Batch Sync'] },
  { id: 'enterprise', name: 'Enterprise', badge: 'Regional Giant', monthlyPrice: 899, yearlyPrice: 8628, yearlyMonthlyEquivalent: 719, maxUsers: 50, maxShops: 10000, maxProducts: 9999, isActive: true,
    features: ['Up to 50 Staff Seats', 'Up to 10,000 Shops', 'Custom Tax Slabs & Audit Vault', 'Dedicated Account Manager'] },
];

export const DEFAULT_PRINTERS = [
  { id: 'printer_58mm_std', name: '58mm Standard Bluetooth POS Thermal Printer', price: 2499, gstRate: 18, paperWidth: '58mm (2-inch)', connectivity: 'Bluetooth + USB', description: 'Compact wireless receipt printer for delivery vans and counter billing.', features: ['90mm/s print speed', '1500mAh battery'], isActive: true, isAvailable: true, isDefault: true },
  { id: 'printer_80mm_pro', name: '80mm High-Speed Countertop POS Printer', price: 4299, gstRate: 18, paperWidth: '80mm (3-inch)', connectivity: 'Bluetooth + USB + LAN', description: 'Heavy-duty billing printer with auto-cutter for agency godowns.', features: ['250mm/s print speed', 'Automatic paper cutter'], isActive: true, isAvailable: true, isDefault: false },
];

export const DEFAULT_ADDONS = [
  { id: 'addon_extra_user', title: 'Extra Staff Seat License', name: 'Extra Staff Seat License', price: 149, gstRate: 18, category: 'seats', period: 'monthly', description: 'One additional salesman or delivery login.', features: ['1 Active Staff Login'], isActive: true, isAvailable: true },
  { id: 'addon_rolls', title: 'Thermal Paper Rolls (Box of 24)', name: 'Thermal Paper Rolls (Box of 24)', price: 499, gstRate: 18, category: 'supplies', period: 'one_time', description: 'BPA-free 58mm receipt rolls.', features: ['24 rolls', 'Free delivery'], isActive: true, isAvailable: true },
];

export const DEFAULT_REMOTE_CONFIG = {
  featureFlags: {
    order_taking: true, gst_invoicing: true, collections: true, gps_tracking: true, thermal_printer: true,
    soundbox_audio: true, staff_management: true, van_stock: true, customer_portal: true, instant_sync: true,
    purchases: true, expenses: true, reports: true,
  },
  maintenance: { active: false, message: 'Platform undergoing scheduled maintenance.', eta: '30 minutes' },
  minAppVersion: '1.0.0',
  allowFreeUserBilling: true,
  freeBillingBlockedMessage: '',
};

export const DEFAULT_BROADCAST = { active: false, title: '', message: '', severity: 'info', dismissible: true };

export const SETTINGS_KEYS = ['supportPhone', 'supportEmail', 'companyName', 'cin', 'gstin', 'upiVpa', 'currency', 'defaultPlanId', 'defaultTrialDays', 'trialGracePeriodDays'];

const fail = message => { throw new HttpError(400, message); };
const str = (v, max = 500) => (v === undefined || v === null ? '' : String(v).trim().slice(0, max));
const num = (v, field, { min = 0, max = 10000000, integer = false } = {}) => {
  const n = typeof v === 'string' && v.trim() !== '' ? Number(v) : v;
  if (typeof n !== 'number' || !Number.isFinite(n) || n < min || n > max || (integer && !Number.isInteger(n))) fail(`Invalid ${field}`);
  return n;
};
const optNum = (v, field, opts) => (v === undefined || v === null || v === '' ? undefined : num(v, field, opts));
const bool = (v, dflt) => (v === undefined || v === null ? dflt : Boolean(v));
const list = v => (Array.isArray(v) ? v.map(x => str(x, 200)).filter(Boolean).slice(0, 20)
  : typeof v === 'string' ? v.split(',').map(x => x.trim()).filter(Boolean).slice(0, 20) : []);
const id = (v, prefix) => {
  const s = str(v, 64) || `${prefix}_${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`;
  if (!/^[A-Za-z0-9_\-]{1,64}$/.test(s)) fail(`Invalid ${prefix} id`);
  return s;
};

export function normalizeTier(t) {
  if (!t || typeof t !== 'object') fail('Invalid plan tier');
  const tierId = id(t.id || t.planId, 'plan');
  const name = str(t.name, 80) || fail('Plan name is required');
  const monthlyPrice = num(t.monthlyPrice ?? 0, 'monthlyPrice');
  const yearlyPrice = num(t.yearlyPrice ?? t.annualPrice ?? Math.round(monthlyPrice * 12 * 0.8), 'yearlyPrice');
  return {
    ...t,
    id: tierId, name, badge: str(t.badge, 40),
    monthlyPrice, yearlyPrice,
    yearlyMonthlyEquivalent: Math.round(yearlyPrice / 12),
    maxUsers: num(t.maxUsers ?? 1, 'maxUsers', { min: 1, max: 100000, integer: true }),
    maxShops: num(t.maxShops ?? 200, 'maxShops', { min: 1, max: 10000000, integer: true }),
    maxProducts: num(t.maxProducts ?? 50, 'maxProducts', { min: 1, max: 10000000, integer: true }),
    features: list(t.features),
    highlight: bool(t.highlight ?? t.isPopular, false),
    isActive: bool(t.isActive, true),
  };
}

export function normalizePlans(plans) {
  const tiers = Array.isArray(plans) ? plans : plans?.tiers;
  if (!Array.isArray(tiers) || !tiers.length) fail('At least one subscription tier is required');
  const out = { tiers: tiers.map(normalizeTier) };
  const ids = new Set(out.tiers.map(t => t.id));
  if (ids.size !== out.tiers.length) fail('Plan ids must be unique');
  out.planGst = num(plans?.planGst ?? 18, 'planGst', { max: 100 });
  return out;
}

export function normalizePrinter(p) {
  if (!p || typeof p !== 'object') fail('Invalid printer option');
  return {
    id: id(p.id, 'printer'),
    name: str(p.name, 120) || fail('Printer model name is required'),
    price: num(p.price ?? 0, 'price'),
    gstRate: num(p.gstRate ?? 18, 'gstRate', { max: 100 }),
    paperWidth: str(p.paperWidth || '58mm (2-inch)', 40),
    connectivity: str(p.connectivity || 'Bluetooth', 80),
    description: str(p.description, 500),
    features: list(p.features),
    isActive: bool(p.isActive ?? p.isAvailable, true),
    isAvailable: bool(p.isAvailable ?? p.isActive, true),
    isDefault: bool(p.isDefault, false),
  };
}

export function normalizeAddon(a) {
  if (!a || typeof a !== 'object') fail('Invalid add-on');
  const title = str(a.title || a.name, 120) || fail('Add-on title is required');
  const period = str(a.period || 'monthly', 20).toLowerCase();
  if (!['monthly', 'yearly', 'one_time'].includes(period)) fail('Invalid add-on period');
  return {
    id: id(a.id, 'addon'), title, name: title,
    price: num(a.price ?? 0, 'price'),
    gstRate: num(a.gstRate ?? 18, 'gstRate', { max: 100 }),
    category: str(a.category || 'seats', 40).toLowerCase(),
    period,
    description: str(a.description, 500),
    features: list(a.features),
    isActive: bool(a.isActive ?? a.isAvailable, true),
    isAvailable: bool(a.isAvailable ?? a.isActive, true),
  };
}

export function normalizeCoupon(c) {
  if (!c || typeof c !== 'object') fail('Invalid coupon');
  const code = str(c.code, 32).toUpperCase();
  if (!/^[A-Z0-9_\-]{3,32}$/.test(code)) fail('Coupon code must be 3-32 letters, digits, - or _');
  let type = str(c.type || c.discountType || 'flat', 20).toLowerCase();
  if (type === 'percent') type = 'percentage';
  if (type === 'days') type = 'trial';
  if (!['trial', 'flat', 'percentage'].includes(type)) fail('Coupon type must be trial, flat or percentage');
  const value = num(c.value ?? c.discountValue ?? c.benefit, 'coupon value', type === 'trial' ? { min: 1, max: 365, integer: true } : type === 'percentage' ? { min: 1, max: 100 } : { min: 1 });
  const minAmount = num(c.minAmount ?? c.minOrderValue ?? 0, 'minimum order value');
  const expiry = str(c.expiryDate || c.validUntil || c.expiresAt, 30) || null;
  if (expiry && Number.isNaN(new Date(expiry).getTime())) fail('Invalid coupon expiry date');
  const isActive = c.isPaused === true ? false : bool(c.isActive ?? c.active, true);
  return {
    id: str(c.id, 64) || code, code, type, value,
    title: str(c.title, 120) || (type === 'trial' ? `${value}-Day Free Trial` : type === 'flat' ? `₹${value} Off` : `${value}% Off`),
    description: str(c.description, 300),
    minAmount, minOrderValue: minAmount,
    maxUses: num(c.maxUses ?? c.limit ?? 100, 'maxUses', { min: 1, max: 1000000, integer: true }),
    expiryDate: expiry, validUntil: expiry,
    isActive, isPaused: !isActive,
    createdAt: c.createdAt || new Date().toISOString(),
  };
}

export function normalizeCoupons(coupons) {
  if (!Array.isArray(coupons)) fail('coupons must be an array');
  const out = coupons.map(normalizeCoupon);
  if (new Set(out.map(c => c.code)).size !== out.length) fail('Coupon codes must be unique');
  return out;
}

export function normalizeSettings(input, current = {}) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) fail('Invalid settings');
  const out = { ...current };
  for (const key of SETTINGS_KEYS) {
    if (input[key] === undefined) continue;
    if (key === 'defaultTrialDays') out[key] = num(input[key], key, { min: 0, max: 365, integer: true });
    else if (key === 'trialGracePeriodDays') out[key] = num(input[key], key, { min: 0, max: 90, integer: true });
    else out[key] = str(input[key], 200);
  }
  return out;
}

export function normalizeRemoteConfig(updates, current = DEFAULT_REMOTE_CONFIG) {
  if (!updates || typeof updates !== 'object' || Array.isArray(updates)) fail('Invalid remote config');
  const next = JSON.parse(JSON.stringify({ ...DEFAULT_REMOTE_CONFIG, ...current }));
  if (updates.featureFlags && typeof updates.featureFlags === 'object') {
    for (const [k, v] of Object.entries(updates.featureFlags)) {
      if (/^[a-z0-9_]{1,40}$/.test(k)) next.featureFlags[k] = Boolean(v);
    }
  }
  const m = updates.maintenance;
  if (m && typeof m === 'object') {
    next.maintenance = {
      active: bool(m.active, next.maintenance?.active || false),
      message: m.message !== undefined ? str(m.message, 300) : next.maintenance?.message || '',
      eta: m.eta !== undefined ? str(m.eta, 60) : next.maintenance?.eta || '',
    };
  } else if (updates.maintenanceMode !== undefined) {
    next.maintenance = { ...next.maintenance, active: Boolean(updates.maintenanceMode) };
    if (updates.maintenanceMessage !== undefined) next.maintenance.message = str(updates.maintenanceMessage, 300);
    if (updates.maintenanceEta !== undefined) next.maintenance.eta = str(updates.maintenanceEta, 60);
  }
  if (updates.minAppVersion !== undefined) {
    const v = str(updates.minAppVersion, 20);
    if (!/^\d+(\.\d+){0,3}$/.test(v)) fail('minAppVersion must look like 1.2.3');
    next.minAppVersion = v;
  }
  for (const k of ['smsProvider', 'smsMode']) if (updates[k] !== undefined) next[k] = str(updates[k], 40);
  if (updates.otpDigits !== undefined) next.otpDigits = num(updates.otpDigits, 'otpDigits', { min: 4, max: 8, integer: true });
  if (updates.enforceOtp !== undefined) next.enforceOtp = Boolean(updates.enforceOtp);
  if (updates.allowFreeUserBilling !== undefined) next.allowFreeUserBilling = Boolean(updates.allowFreeUserBilling);
  if (updates.freeBillingBlockedMessage !== undefined) next.freeBillingBlockedMessage = str(updates.freeBillingBlockedMessage, 300);
  return next;
}

export function normalizeBroadcast(b, current = DEFAULT_BROADCAST) {
  if (!b || typeof b !== 'object' || Array.isArray(b)) fail('Invalid broadcast');
  const severity = str(b.severity ?? b.type ?? current.severity ?? 'info', 20).toLowerCase();
  const out = {
    ...current,
    active: bool(b.active, current.active),
    title: b.title !== undefined ? str(b.title, 120) : current.title,
    message: b.message !== undefined ? str(b.message, 1000) : current.message,
    severity: ['info', 'warning', 'critical', 'success', 'promo'].includes(severity) ? severity : 'info',
    dismissible: bool(b.dismissible, current.dismissible ?? true),
    actionText: b.actionText !== undefined ? str(b.actionText, 40) : current.actionText || '',
    actionUrl: b.actionUrl !== undefined ? str(b.actionUrl, 300) : current.actionUrl || '',
    targetTenant: b.targetTenant !== undefined ? str(b.targetTenant, 64) || 'all' : current.targetTenant || 'all',
    targetPlan: b.targetPlan !== undefined ? str(b.targetPlan, 40) || 'all' : current.targetPlan || 'all',
    updatedAt: new Date().toISOString(),
  };
  if (out.actionUrl && !/^(https:\/\/|\/)/i.test(out.actionUrl)) fail('Broadcast action URL must be https:// or an in-app path');
  return out;
}

export function tierFor(plans, planId) {
  return (plans?.tiers || DEFAULT_TIERS).find(t => t.id === planId) || null;
}
