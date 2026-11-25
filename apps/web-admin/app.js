// SalesArmy Super Admin Portal - Core Logic & Data Engine
// Supports Decoupled Standalone Operation, Real-Time Tab Broadcast,
// and Direct Interoperability with the SalesArmy Mobile Flutter App.

const STORAGE_KEYS = {
  COUPONS: 'sa_admin_coupons',
  PRINTER_ORDERS: 'sa_admin_printer_orders',
  PRINTER_OPTIONS: 'sa_admin_printer_options',
  SUBSCRIPTION_ADDONS: 'sa_admin_subscription_addons',
  TENANTS: 'sa_admin_tenants',
  PLANS: 'sa_admin_plans',
  SETTINGS: 'sa_admin_settings',
  AUTH: 'sa_admin_session',
  REMOTE_CONFIG: 'sa_admin_remote_config',
  BROADCAST: 'sa_admin_broadcast',
  USERS: 'sa_admin_users',
  RETAIL_ORDERS: 'sa_admin_retail_orders',
  NOTIFICATIONS: 'sa_admin_notifications',
};

// Attach the current verified session to every same-origin API request.
const nativeFetch = window.fetch.bind(window);
window.fetch = async (input, options = {}) => {
  const url = new URL(typeof input === 'string' ? input : input.url, window.location.href);
  if (url.origin !== window.location.origin || !url.pathname.startsWith('/api/')) return nativeFetch(input, options);

  // Auth endpoints (login, signup) should always use native fetch directly without injecting bearer tokens
  if (url.pathname.startsWith('/api/auth/')) return nativeFetch(input, options);

  const headers = new Headers(options.headers || {});
  let session;
  try { session = JSON.parse(localStorage.getItem(STORAGE_KEYS.AUTH) || 'null'); } catch (_) {}
  if (session?.token) headers.set('Authorization', `Bearer ${session.token}`);
  const response = await nativeFetch(input, { ...options, headers });
  if (!response.ok) {
    const body = await response.clone().json().catch(() => ({}));
    const message = body.error || `Request failed (${response.status})`;
    if (response.status === 401 && !url.pathname.startsWith('/api/auth/')) {
      // Session expired or revoked: drop the token and every cached record.
      for (const key of Object.values(STORAGE_KEYS)) localStorage.removeItem(key);
      window.adminApp?.stopBridge?.();
      document.getElementById('authGate')?.classList.remove('hidden');
    }
    document.dispatchEvent(new CustomEvent('api-error', { detail: message }));
    throw new Error(message);
  }
  return response;
};

// Official Firebase Project Credentials for Real-Time Mobile Interoperability
const FIREBASE_CONFIG = {
  apiKey: 'AIzaSyD9d5rJx7-SrhAHc34KQpAZ1wCqG1GNBmQ',
  authDomain: 'salesarmy-app-flutter.firebaseapp.com',
  projectId: 'salesarmy-app-flutter',
  storageBucket: 'salesarmy-app-flutter.firebasestorage.app',
  messagingSenderId: '299154277094',
  appId: '1:299154277094:web:e816259e6fea79de43b127',
  databaseURL: 'https://salesarmy-app-flutter-default-rtdb.asia-southeast1.firebasedatabase.app',
};

// 1. Initial Seed Data
const DEFAULT_COUPONS = [];

// Canonical capability catalog — shared with mobile FeatureGate.
// Admin toggles these per tier to control what each plan actually unlocks.
const CAPABILITY_CATALOG = [
  { key: 'order_taking',      label: 'Order Taking & Bill Page',     group: 'Selling' },
  { key: 'estimate_bills',    label: 'Kaccha / Estimate Bills',      group: 'Selling' },
  { key: 'invoicing',         label: 'GST Tax Invoicing',            group: 'Selling' },
  { key: 'sales_returns',     label: 'Sales Returns',                group: 'Selling' },
  { key: 'collections',       label: 'Payment Collection',           group: 'Money' },
  { key: 'khata_ledger',      label: 'Khata Ledgers & PDF Export',   group: 'Money' },
  { key: 'dynamic_upi_qr',    label: 'Dynamic UPI QR on Bills',      group: 'Money' },
  { key: 'purchases',         label: 'Purchases / Stock Inward',     group: 'Operations' },
  { key: 'expenses',          label: 'Expense Tracking',             group: 'Operations' },
  { key: 'visits',            label: 'Visits & Reminders',           group: 'Operations' },
  { key: 'staff_management',  label: 'Staff Logins & Permissions',   group: 'Operations' },
  { key: 'thermal_printer',   label: 'Bluetooth Thermal Printing',   group: 'Operations' },
  { key: 'reports',           label: 'Reports Hub',                  group: 'Reports' },
  { key: 'gst_reports',       label: 'GST Reports & Export',         group: 'Reports' },
  { key: 'offline_sync',      label: 'Offline Outbox & Cloud Sync',  group: 'Core' },
  { key: 'bulk_import',       label: 'Bulk CSV Import',              group: 'Core' },
  { key: 'live_tracking',     label: 'Live Beat Tracking (GPS)',     group: 'Advanced' },
  { key: 'van_stock',         label: 'Van Stock & Reconciliation',   group: 'Advanced' },
  { key: 'multi_van',         label: 'Multi-Van Fleet Management',   group: 'Advanced' },
  { key: 'multi_branch',      label: 'Multi-Branch Locations',       group: 'Advanced' },
  { key: 'custom_branding',   label: 'Logo & Brand Customization',   group: 'Customization' },
  { key: 'custom_tax_slabs',  label: 'Custom Tax Slabs',             group: 'Customization' },
  { key: 'admin_customization', label: 'Admin Panel Customization',  group: 'Customization' },
  { key: 'audit_vault',       label: 'Audit Vault & Compliance',     group: 'Enterprise' },
  { key: 'priority_support',  label: 'Priority Phone / WhatsApp',    group: 'Support' },
  { key: 'dedicated_manager', label: 'Dedicated Account Manager',    group: 'Support' },
];
const CORE_CAPABILITIES = ['order_taking', 'estimate_bills', 'invoicing', 'sales_returns', 'collections', 'khata_ledger',
  'purchases', 'expenses', 'visits', 'thermal_printer', 'reports', 'gst_reports', 'offline_sync'];

const DEFAULT_PLANS = {
  // Legacy rates for backwards compatibility
  silverPrice: 399,
  goldPrice: 599,
  platinumPrice: 899,
  printerPrice: 2499,
  planGst: 18,
  printerGst: 18,
  // Dynamic subscription tiers matching mobile app
  tiers: [
    {
      id: 'startup',
      name: 'Startup Plan',
      monthlyPrice: 399,
      yearlyMonthlyEquivalent: 319,
      annualPrice: 3828,
      maxStaff: 2,
      maxOrdersPerMonth: 200,
      maxBranches: 1,
      maxProducts: 50,
      maxShops: 200,
      featuresVersion: 2,
      tagline: 'Ideal for single-van distributors and emerging agencies.',
      features: [
        'GST & Kaccha Billing',
        '2 Field Sales Staff Logins',
        '200 Orders / Invoices per month',
        '1 Branch / Godown Location',
        'Instant Kaccha & Tax Bills',
        'Standard WhatsApp PDF Sharing',
      ],
      allowedFeatures: [...CORE_CAPABILITIES],
      isPopular: false,
    },
    {
      id: 'grow',
      name: 'Grow Plan',
      monthlyPrice: 599,
      yearlyMonthlyEquivalent: 479,
      annualPrice: 5748,
      maxStaff: 10,
      maxOrdersPerMonth: 1000,
      maxBranches: 3,
      maxProducts: 200,
      maxShops: 1000,
      featuresVersion: 2,
      tagline: 'Most popular for expanding regional wholesale operations.',
      features: [
        'Everything in Startup',
        'Up to 10 Field Sales Staff Logins',
        '1,000 Orders / Invoices per month',
        '3 Branch / Depot Locations',
        'Soundbox & BharatQR Audio Confirmation',
        'Route Optimization & Beat Tracking',
        '24/7 Priority WhatsApp Support',
      ],
      allowedFeatures: [...CORE_CAPABILITIES, 'staff_management', 'dynamic_upi_qr', 'live_tracking', 'van_stock', 'bulk_import', 'multi_branch', 'priority_support'],
      isPopular: true,
    },
    {
      id: 'enterprise',
      name: 'Enterprise Plan',
      monthlyPrice: 899,
      yearlyMonthlyEquivalent: 719,
      annualPrice: 8628,
      maxStaff: 999,
      maxOrdersPerMonth: 0,
      maxBranches: 10,
      maxProducts: 0,
      maxShops: 10000,
      featuresVersion: 2,
      tagline: 'Maximum power & scale for enterprise FMCG operations.',
      features: [
        'Unlimited Staff & Shop Logins',
        'Unlimited Monthly Orders & Invoices',
        'Up to 10 Branches / Warehouses',
        'Multi-Godown Stock Transfers',
        'Custom ERP & Tally Integration',
        'Dedicated Enterprise Account Manager',
      ],
      allowedFeatures: CAPABILITY_CATALOG.map(c => c.key),
      isPopular: false,
    },
  ],
};

const DEFAULT_PRINTER_OPTIONS = [
  {
    id: 'printer_58mm_standard',
    name: '58mm Standard Bluetooth POS Thermal Printer',
    price: 2499,
    gstRate: 18,
    paperWidth: '58mm (2-inch)',
    connectivity: 'Bluetooth + USB',
    description: 'Compact wireless receipt printer ideal for mobile delivery vans and quick counter receipts.',
    features: [
      'Up to 90mm/s print speed',
      'Drop-in paper roll loading',
      'Rechargeable 1500mAh battery',
    ],
    isAvailable: true,
    isDefault: true,
  },
  {
    id: 'printer_80mm_heavyduty',
    name: '80mm Heavy-Duty Bluetooth + USB Kitchen/POS Printer',
    price: 3999,
    gstRate: 18,
    paperWidth: '80mm (3-inch)',
    connectivity: 'Bluetooth + USB + LAN',
    description: 'High-speed desktop thermal printer for busy wholesale distribution desks, itemized invoices with GST breakdown.',
    features: [
      'Auto-cutter mechanism',
      '200mm/s high-speed printing',
      'Wide format for B2B itemized bills',
    ],
    isAvailable: true,
    isDefault: false,
  },
  {
    id: 'printer_58mm_pocket',
    name: '58mm Pocket Mini Belt-Clip POS Thermal Printer',
    price: 1899,
    gstRate: 18,
    paperWidth: '58mm (2-inch)',
    connectivity: 'Bluetooth only',
    description: 'Ultra-portable featherweight printer with belt clip holster for field sales agents and spot collections.',
    features: [
      'Ultra-compact belt pouch included',
      'Direct ESC/POS Android & iOS link',
      '12-hour standby time',
    ],
    isAvailable: true,
    isDefault: false,
  },
];

const DEFAULT_ADDONS = [
  {
    id: 'addon_extra_user',
    title: 'Extra Staff Seat License',
    price: 149,
    gstRate: 18,
    category: 'seats',
    period: 'monthly',
    description: 'Add an additional mobile salesman or delivery van driver to your workspace with live field tracking.',
    features: ['1 Active Staff Login', 'Live GPS Route Tracking', 'Individual Sales Performance & Cash Register'],
    isAvailable: true,
  },
  {
    id: 'addon_extra_shops',
    title: '+500 Retail Shop Directory Boost',
    price: 299,
    gstRate: 18,
    category: 'directory',
    period: 'monthly',
    description: 'Expand your retail footprint with 500 extra customer shop accounts, credit ledgers, and visit scheduling.',
    features: ['+500 Shop Profiles', 'Khata Credit Ledgers & GSTIN Lookup', 'Geo-tagged Pinpoints'],
    isAvailable: true,
  },
  {
    id: 'addon_whatsapp_sms',
    title: 'Smart WhatsApp & SMS Notification Pack',
    price: 399,
    gstRate: 18,
    category: 'notifications',
    period: 'monthly',
    description: 'Automated WhatsApp PDF invoice dispatch and SMS dispatch alerts to retailers instantly upon order booking.',
    features: ['1,000 WhatsApp Order Slips/mo', 'Instant SMS Dispatch Alerts', 'Payment Reminder Broadcasts'],
    isAvailable: true,
  },
  {
    id: 'addon_rolls',
    title: 'Thermal Paper Rolls Pack (Box of 24)',
    price: 499,
    gstRate: 18,
    category: 'supplies',
    period: 'one_time',
    description: 'High quality 58mm direct thermal BPA-free receipt paper rolls box with 5-year image preservation coating.',
    features: ['24 High-Density Paper Rolls', 'BPA-Free Clear Coating', 'Free Doorstep Courier Delivery'],
    isAvailable: true,
  },
  {
    id: 'addon_scanner',
    title: 'Wireless Barcode & QR Scanner',
    price: 1799,
    gstRate: 18,
    category: 'hardware',
    period: 'one_time',
    description: 'Handheld Bluetooth 1D/2D scanner for ultra-fast barcode lookup and zero-error inventory tally.',
    features: ['Bluetooth & 2.4G Wireless Dongle', 'Fast 1D/2D QR code decode', 'Rugged shock-resistant casing'],
    isAvailable: true,
  },
  {
    id: 'addon_weighing_scale',
    title: 'Digital Bluetooth Weighing Scale',
    price: 3499,
    gstRate: 18,
    category: 'hardware',
    period: 'one_time',
    description: 'Precision digital scale directly paired to POS for auto-filling exact gross weight and billing kg items.',
    features: ['Up to 50kg capacity / 5g precision', 'Instant Bluetooth POS auto-sync', 'Heavy duty steel platform'],
    isAvailable: true,
  },
  {
    id: 'addon_vip_support',
    title: 'VIP Priority Support & Dedicated Account Manager',
    price: 999,
    gstRate: 18,
    category: 'support',
    period: 'yearly',
    description: 'Direct phone & WhatsApp hotline with guaranteed 15-minute SLA and priority staff onboarding training.',
    features: ['Dedicated WhatsApp & Phone Line', '15-min Guaranteed Response SLA', 'Quarterly Inventory Audit & Tally Export Assist'],
    isAvailable: true,
  },
];

const DEFAULT_PRINTER_ORDERS = [];

const DEFAULT_TENANTS = [];

const DEFAULT_SETTINGS = {
  maintenanceMode: false,
  supportPhone: '',
  supportEmail: '',
  companyName: '',
  brandName: 'SalesArmy',
  cin: '',
  gstin: '',
  upiVpa: '',
  upiMerchantName: '',
  defaultPlanId: 'startup',
  defaultTrialDays: 14,
  trialGracePeriodDays: 3,
};

const DEFAULT_REMOTE_CONFIG = {
  featureFlags: {
    order_taking: true,
    gst_invoicing: true,
    collections: true,
    gps_tracking: true,
    thermal_printer: true,
    soundbox_audio: true,
    staff_management: true,
    van_stock: true,
    customer_portal: true,
    instant_sync: true,
    purchases: true,
    expenses: true,
    reports: true,
  },
  minAppVersion: 'v2.4.1',
  updateUrl: 'https://play.google.com/store/apps/details?id=com.salesarmy.app',
  enforceHardUpdate: true,
  smsProvider: 'firebase',
  otpDigits: 6,
  smsMode: 'live',
  enforceOtp: false,
  maintenance: {
    active: false,
    message: 'SalesArmy is currently undergoing scheduled platform maintenance. Please check back shortly.',
    eta: '30 minutes',
  },
  printerConfig: {
    defaultWidth: '58mm',
    characterSet: 'PC437',
  },
  soundboxConfig: {
    language: 'hi_IN',
    volume: 80,
  },
};

const DEFAULT_BROADCAST = {
  active: false,
  id: 'bcast_1',
  title: 'Platform Announcement',
  message: 'Welcome to SalesArmy B2B Distribution Platform.',
  type: 'info',
  dismissible: true,
  actionText: 'Got It',
};

const REMOTE_MODULES_METADATA = [
  {
    key: 'order_taking',
    name: 'Order Taker & Kaccha Bill',
    title: 'Order Taker & Kaccha Billing Flow',
    category: 'Core Selling',
    desc: 'Core wholesale booking and quotation bills (platform-wide kill switch; per-plan access is set in Plans).',
    description: 'Core wholesale booking and quotation bills (platform-wide kill switch; per-plan access is set in Plans).',
    icon: '📝',
    isFreemiumProtected: true,
    isCoreSelling: true,
  },
  {
    key: 'gst_invoicing',
    name: 'GST Tax Slabs & Invoicing',
    title: 'GST Tax Slabs & HSN Invoicing',
    category: 'Billing & GST',
    desc: 'Enables 0%, 5%, 12%, 18%, 28% tax slabs, CGST/SGST/IGST breakdown, and official tax invoices.',
    description: 'Enables 0%, 5%, 12%, 18%, 28% tax slabs, CGST/SGST/IGST breakdown, and official tax invoices.',
    icon: '🧾',
    isFreemiumProtected: true,
    isCoreSelling: true,
  },
  {
    key: 'collections',
    name: 'Khata Ledger & Collections',
    title: 'Khata Ledger & Cash/UPI Collections',
    category: 'Accounts & Khata',
    desc: 'Multi-bank accounts, outstanding party balances, cash reconciliations, and automated ledger receipts.',
    description: 'Multi-bank accounts, outstanding party balances, cash reconciliations, and automated ledger receipts.',
    icon: '💰',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'gps_tracking',
    name: 'Field GPS & Beat Tracking',
    title: 'Field GPS Location & Beat Geofencing',
    category: 'Field Force',
    desc: 'Captures field agent coordinates during check-ins and orders taken along assigned beats.',
    description: 'Captures field agent coordinates during check-ins and orders taken along assigned beats.',
    icon: '📍',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'thermal_printer',
    name: 'Bluetooth Thermal Printing',
    title: 'Bluetooth Thermal POS Printing',
    category: 'Hardware Add-on',
    desc: 'Wireless 58mm/80mm ESC/POS thermal printing for invoices, order slips, and collection vouchers.',
    description: 'Wireless 58mm/80mm ESC/POS thermal printing for invoices, order slips, and collection vouchers.',
    icon: '🖨️',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'soundbox_audio',
    name: 'Soundbox Audio Alerts',
    title: 'Soundbox & Audio Payment Alerts',
    category: 'Voice Hardware',
    desc: 'Spoken multilingual payment confirmation voice alerts upon successful UPI collections.',
    description: 'Spoken multilingual payment confirmation voice alerts upon successful UPI collections.',
    icon: '🔊',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'staff_management',
    name: 'Field Staff & Seat Quotas',
    title: 'Field Sales Staff & Seat Quotas',
    category: 'Operations',
    desc: 'Controls whether distributors can invite sub-users, drivers, and sales reps to their tenant.',
    description: 'Controls whether distributors can invite sub-users, drivers, and sales reps to their tenant.',
    icon: '👥',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'van_stock',
    name: 'Van Stock & Warehouses',
    title: 'Multiple Godowns & Van Stock Transfers',
    category: 'Inventory',
    desc: 'Vehicle load-in, godown stock allocation, and real-time transit inventory tracking.',
    description: 'Vehicle load-in, godown stock allocation, and real-time transit inventory tracking.',
    icon: '🚚',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'customer_portal',
    name: 'Retailer Catalog & Store',
    title: 'Retailer Self-Ordering Catalog Link',
    category: 'B2B Commerce',
    desc: 'Generates shareable web catalog links allowing shopkeepers to order directly online.',
    description: 'Generates shareable web catalog links allowing shopkeepers to order directly online.',
    icon: '🛒',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'instant_sync',
    name: 'Instant Cloud Outbox Sync',
    title: 'Real-Time Cloud Outbox Sync',
    category: 'Sync Engine',
    desc: 'Background outbox dispatch engine synchronizing offline mutations to Firestore immediately.',
    description: 'Background outbox dispatch engine synchronizing offline mutations to Firestore immediately.',
    icon: '☁️',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'purchases',
    name: 'Supplier Purchases & Goods-In',
    title: 'Supplier Purchases & Stock Inward',
    category: 'Inventory',
    desc: 'Purchase bills, vendor stock additions, supplier balances and accounts payable.',
    description: 'Purchase bills, vendor stock additions, supplier balances and accounts payable.',
    icon: '📦',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'expenses',
    name: 'Expenses & Operational Payouts',
    title: 'Field Expenses & Cash Outflow',
    category: 'Accounts & Khata',
    desc: 'Petty cash, fuel, travel allowances, operational vouchers, and expense categories.',
    description: 'Petty cash, fuel, travel allowances, operational vouchers, and expense categories.',
    icon: '💸',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
  {
    key: 'reports',
    name: 'Analytics & Financial Statements',
    title: 'Export Reports & Financial Audit',
    category: 'Intelligence',
    desc: 'Detailed monthly, quarterly, and annual sales, tax, ledger, and stock audit exports.',
    description: 'Detailed monthly, quarterly, and annual sales, tax, ledger, and stock audit exports.',
    icon: '📊',
    isFreemiumProtected: false,
    isCoreSelling: false,
  },
];

// 2. Main Super Admin Application Class

const DEFAULT_USERS = [
  {
    id: 'c5d3eb2b-08b8-4a4c-9082-6db533d3155e',
    uid: 'c5d3eb2b-08b8-4a4c-9082-6db533d3155e',
    name: 'Master Super Admin',
    email: 'superadmin@salesarmy.saas',
    role: 'superadmin',
    status: 'active',
    tenantId: 'platform_tenant',
    tenantName: 'Platform Central',
    createdAt: '2026-01-01T00:00:00.000Z',
    lastLogin: '2026-10-28T04:00:00.000Z'
  }
];

const DEFAULT_RETAIL_ORDERS = [];

class AdminPortal {
  constructor() {
    this.coupons = this.loadData(STORAGE_KEYS.COUPONS, DEFAULT_COUPONS);
    this.printerOrders = this.loadData(STORAGE_KEYS.PRINTER_ORDERS, DEFAULT_PRINTER_ORDERS);
    this.tenants = this.loadData(STORAGE_KEYS.TENANTS, DEFAULT_TENANTS);
    this.plans = this.loadData(STORAGE_KEYS.PLANS, DEFAULT_PLANS);
    this.printerOptions = this.loadData(STORAGE_KEYS.PRINTER_OPTIONS, DEFAULT_PRINTER_OPTIONS);
    this.subscriptionAddons = this.loadData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, DEFAULT_ADDONS);
    this.settings = this.loadData(STORAGE_KEYS.SETTINGS, DEFAULT_SETTINGS);
    this.remoteConfig = this.loadData(STORAGE_KEYS.REMOTE_CONFIG, DEFAULT_REMOTE_CONFIG);
    this.broadcast = this.loadData(STORAGE_KEYS.BROADCAST, DEFAULT_BROADCAST);
    this.users = this.loadData(STORAGE_KEYS.USERS, DEFAULT_USERS);
    this.retailOrders = this.loadData(STORAGE_KEYS.RETAIL_ORDERS, DEFAULT_RETAIL_ORDERS);
    this.notifications = this.loadData(STORAGE_KEYS.NOTIFICATIONS, []);

    // Purge legacy mock/dummy data from client cache to ensure 100% real database state
    if (this.retailOrders && this.retailOrders.some(o => (o.id || '').startsWith('ORD-892') || o.shopName === 'Shree Ganesh Kirana & Superstore')) {
      this.retailOrders = [];
      this.saveData(STORAGE_KEYS.RETAIL_ORDERS, []);
    }
    if (this.printerOrders && this.printerOrders.some(po => (po.id || '').startsWith('PO-9821') || po.customerName === 'Rajesh Sharma')) {
      this.printerOrders = [];
      this.saveData(STORAGE_KEYS.PRINTER_ORDERS, []);
    }
    if (this.coupons && this.coupons.some(c => c.code === 'DIWALI2026' || c.code === 'STARTUP50')) {
      this.coupons = [];
      this.saveData(STORAGE_KEYS.COUPONS, []);
    }
    if (this.tenants && this.tenants.some(t => t.id === 't_001' || t.firmName === 'Balaji Provisions & Wholesale')) {
      this.tenants = [];
      this.saveData(STORAGE_KEYS.TENANTS, []);
    }

    this.currentView = 'dashboard';
    this.couponFilter = 'all';
    this.printerFilter = 'all';
    this.tenantFilter = 'all';
    this.tenantPlanFilter = 'all';
    this.tenantCityFilter = 'all';
    this.tenantSortOrder = 'latest';
    this.tenantSortKey = 'createdAt';
    this.tenantSortDir = 'desc';
    this.tenantViewMode = 'grid'; // client spec: subscribers shown as cards
    this.userFilter = 'all';
    this.userStatusFilter = 'all';
    this.orderFilter = 'all';
    this.notificationFilter = 'all';
    this.userTenantFilter = 'all';
    this.activeInvoiceOrderId = null;

    this.couponSearch = '';
    this.printerSearch = '';
    this.tenantSearch = '';
    this.userSearch = '';
    this.orderSearch = '';

    this.db = null;
    this.isCloudConnected = false;
    this.supabaseClient = null;
    document.addEventListener('api-error', event => this.showToast(event.detail, '❌', 'danger'));

    this.initAuth();
    this.initTheme();
    this.initBroadcastChannel();
    this.initElements();
    this.bindEvents();
    this.initKeyboardShortcuts();
    this.renderAll();
    // Data is only fetched for a signed-in Super Admin; the server verifies
    // the session on every request (the login gate is not a security boundary).
    if (this.hasSession()) this.startDataSync();
  }

  hasSession() {
    const s = this.loadData(STORAGE_KEYS.AUTH, null);
    return Boolean(s && s.token && s.role === 'super_admin');
  }

  async startDataSync() {
    await this.initSupabase();
    await this.initBridge();
  }

  clearLocalData() {
    for (const key of Object.values(STORAGE_KEYS)) localStorage.removeItem(key);
    localStorage.removeItem('sa_admin_shops');
  }

  // --- Theme & Accessibility ---
  initTheme() {
    const savedTheme = localStorage.getItem('sa_admin_theme') || 'light';
    this.applyTheme(savedTheme);
  }

  applyTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme);
    localStorage.setItem('sa_admin_theme', theme);
    if (this.renderDashboardCharts) this.renderDashboardCharts();
    const toggleBtn = document.getElementById('btnThemeToggle');
    if (toggleBtn) {
      if (theme === 'dark') {
        toggleBtn.innerHTML = '☀️ <span id="themeToggleText">Light</span>';
      } else {
        toggleBtn.innerHTML = '🌙 <span id="themeToggleText">Dark</span>';
      }
    }
  }

  toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme') || 'light';
    const next = current === 'dark' ? 'light' : 'dark';
    this.applyTheme(next);
    this.showToast(`Switched to ${next === 'dark' ? 'Dark' : 'Light'} Mode`, next === 'dark' ? '🌙' : '☀️');
  }

  toggleMobileSidebar() {
    const sidebar = document.querySelector('.sidebar');
    const backdrop = document.getElementById('sidebarBackdrop');
    if (sidebar) sidebar.classList.toggle('open');
    if (backdrop) backdrop.classList.toggle('open');
  }

  initKeyboardShortcuts() {
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        document.querySelectorAll('.modal-overlay.active').forEach(modal => {
          modal.classList.remove('active');
        });
        const sidebar = document.querySelector('.sidebar');
        const backdrop = document.getElementById('sidebarBackdrop');
        if (sidebar && sidebar.classList.contains('open')) {
          sidebar.classList.remove('open');
          if (backdrop) backdrop.classList.remove('open');
        }
      }
    });
  }

  // --- Storage & Sync Handlers ---
  loadData(key, fallback) {
    try {
      const saved = localStorage.getItem(key);
      return saved ? JSON.parse(saved) : fallback;
    } catch (e) {
      console.warn('LocalStorage load error', e);
      return fallback;
    }
  }

  saveData(key, data) {
    try {
      localStorage.setItem(key, JSON.stringify(data));
      this.broadcastChange(key, data);
    } catch (e) {
      console.error('LocalStorage save error', e);
    }
  }

  escapeHtml(str) {
    if (str === null || str === undefined) return '';
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  // JS-string-literal escape for values interpolated into inline event handlers
  // like onclick="foo('${jsStr(id)}')". Note: the HTML parser decodes `&#39;`
  // back to `'` BEFORE the JS parser sees it, which means `escapeHtml` alone
  // is NOT a safe JS-context escape — attacker-controlled values could still
  // break out of the string. Use this helper for every inline handler arg,
  // AND restrict ids to IDs you issued (UUIDs / server-signed slugs) wherever
  // possible. Prefer data-* attributes + delegated listeners for new code.
  escapeJs(str) {
    if (str === null || str === undefined) return '';
    // Quotes become \x27 / \x22 (not \' / \"): the result is placed inside
    // HTML attributes like onclick="...", where the HTML parser ends the
    // attribute at a raw " even when it is preceded by a backslash.
    return String(str)
      .replace(/\\/g, '\\\\')
      .replace(/'/g, '\\x27')
      .replace(/"/g, '\\x22')
      .replace(/</g, '\\x3c')
      .replace(/>/g, '\\x3e')
      .replace(/&/g, '\\x26')
      .replace(/\r/g, '\\r')
      .replace(/\n/g, '\\n')
      .replace(new RegExp(String.fromCharCode(0x2028), 'g'), '\\u2028')
      .replace(new RegExp(String.fromCharCode(0x2029), 'g'), '\\u2029');
  }

  getAuthHeaders(customHeaders = {}) {
    let token = '';
    try {
      const raw = localStorage.getItem(STORAGE_KEYS.AUTH);
      if (raw) {
        const sess = JSON.parse(raw);
        token = sess.token || sess.sessionToken || sess.accessToken || '';
      }
    } catch (_) {}
    const headers = token ? { 'Authorization': `Bearer ${token}` } : {};
    return { ...headers, ...customHeaders };
  }

  /**
   * Server mutation helper. Returns true on 2xx, false on anything else
   * (also surfaces a failure toast). Call sites that update local state
   * optimistically should roll back when this returns false.
   *
   * Options:
   *   method   HTTP verb (default POST)
   *   silent   skip the error toast
   */
  async apiMutate(url, body, { method = 'POST', silent = false } = {}) {
    try {
      const res = await fetch(url, {
        method,
        headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
        body: body == null ? undefined : JSON.stringify(body),
      });
      if (res.ok) return true;
      let msg = `${method} ${url} failed (${res.status})`;
      try {
        const j = await res.json();
        if (j && j.error) msg = String(j.error);
      } catch (_) {}
      if (!silent) this.showToast(msg, '⚠️', 'warning');
      return false;
    } catch (err) {
      // The global fetch wrapper has already shown the server's error message
      // for HTTP failures; only report genuine network failures here.
      if (!silent && err instanceof TypeError) this.showToast(`Network error: ${err.message}`, '⚠️', 'warning');
      return false;
    }
  }

  // --- Real-Time Tab & Broadcast Synchronization ---
  initBroadcastChannel() {
    if (typeof BroadcastChannel !== 'undefined') {
      try {
        this.channel = new BroadcastChannel('salesarmy_admin_channel');
        this.channel.onmessage = (event) => {
          this.handleBroadcastMessage(event.data);
        };
      } catch (e) {
        console.warn('BroadcastChannel not supported, relying on storage events', e);
      }
    }

    window.addEventListener('storage', (event) => {
      if (Object.values(STORAGE_KEYS).includes(event.key)) {
        this.coupons = this.loadData(STORAGE_KEYS.COUPONS, DEFAULT_COUPONS);
        this.printerOrders = this.loadData(STORAGE_KEYS.PRINTER_ORDERS, DEFAULT_PRINTER_ORDERS);
        this.tenants = this.loadData(STORAGE_KEYS.TENANTS, DEFAULT_TENANTS);
        this.plans = this.loadData(STORAGE_KEYS.PLANS, DEFAULT_PLANS);
        this.printerOptions = this.loadData(STORAGE_KEYS.PRINTER_OPTIONS, DEFAULT_PRINTER_OPTIONS);
        this.subscriptionAddons = this.loadData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, DEFAULT_ADDONS);
        this.remoteConfig = this.loadData(STORAGE_KEYS.REMOTE_CONFIG, DEFAULT_REMOTE_CONFIG);
        this.broadcast = this.loadData(STORAGE_KEYS.BROADCAST, DEFAULT_BROADCAST);
        this.renderAll();
        this.showToast('Data synced from another window!', '🔄');
      }
    });
  }

  broadcastChange(key, data) {
    if (this.channel) {
      try {
        this.channel.postMessage({
          type: 'DATA_UPDATED',
          key,
          timestamp: new Date().toISOString(),
        });
      } catch (e) {
        console.warn('Broadcast send error', e);
      }
    }
    const indicator = document.getElementById('syncLastEventText');
    if (indicator) {
      indicator.textContent = `Updated ${key.replace('sa_admin_', '')} at ${new Date().toLocaleTimeString()}`;
    }
  }

  handleBroadcastMessage(data) {
    if (data && data.type === 'DATA_UPDATED') {
      this.coupons = this.loadData(STORAGE_KEYS.COUPONS, DEFAULT_COUPONS);
      this.printerOrders = this.loadData(STORAGE_KEYS.PRINTER_ORDERS, DEFAULT_PRINTER_ORDERS);
      this.tenants = this.loadData(STORAGE_KEYS.TENANTS, DEFAULT_TENANTS);
      this.plans = this.loadData(STORAGE_KEYS.PLANS, DEFAULT_PLANS);
      this.printerOptions = this.loadData(STORAGE_KEYS.PRINTER_OPTIONS, DEFAULT_PRINTER_OPTIONS);
      this.subscriptionAddons = this.loadData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, DEFAULT_ADDONS);
      this.remoteConfig = this.loadData(STORAGE_KEYS.REMOTE_CONFIG, DEFAULT_REMOTE_CONFIG);
      this.broadcast = this.loadData(STORAGE_KEYS.BROADCAST, DEFAULT_BROADCAST);
      this.renderAll();
      const indicator = document.getElementById('syncLastEventText');
      if (indicator) {
        indicator.textContent = `Received live sync (${data.key}) at ${new Date().toLocaleTimeString()}`;
      }
      this.showToast('Live update received via BroadcastChannel', '📡');
    } else if (data && data.type === 'PING') {
      this.showToast('BroadcastChannel heartbeat OK!', '⚡');
    }
  }

  broadcastHeartbeat() {
    if (this.channel) {
      this.channel.postMessage({ type: 'PING' });
    }
    this.showToast('Heartbeat ping sent to active tabs!', '📡');
  }

  // Firestore has been removed from the admin — Supabase is the single
  // source of truth. All `this.db = …` writes below are inert because
  // `this.db` is permanently null. We keep the method shape so other
  // code paths that call it don't throw.
  initFirebase() {
    this.db = null;
    this.isCloudConnected = false;
    this.updateCloudStatus(false, 'Firestore disabled — Supabase is primary');
  }

  updateCloudStatus(connected, message = '') {
    const cloudBridgeText = document.getElementById('cloudBridgeStatusText');
    const topSyncText = document.getElementById('syncStatusIndicatorText');

    if (connected) {
      if (cloudBridgeText) {
        cloudBridgeText.textContent = '● Connected (Live Listeners Active)';
        cloudBridgeText.style.color = '#10B981';
      }
      if (topSyncText) topSyncText.textContent = 'Cloud Bridge Active';
    } else {
      if (cloudBridgeText) {
        cloudBridgeText.textContent = `○ Standalone / Outbox Mode (${message || 'Offline'})`;
        cloudBridgeText.style.color = '#F59E0B';
      }
      if (topSyncText) topSyncText.textContent = 'Local Outbox Mode';
    }
  }

  // --- SUPABASE (session + realtime change notifications only) ---
  // All reads and writes go through the admin API (/api/platform/*), which
  // verifies the Super Admin session and records an audit log. The browser
  // Supabase client is used only to receive realtime change events.
  async initSupabase() {
    let url = null;
    let anonKey = null;
    try {
      const res = await fetch('/api/config/supabase');
      const conf = await res.json();
      url = conf.supabaseUrl;
      anonKey = conf.supabaseAnonKey;
    } catch (_) {}

    if (typeof supabase === 'undefined' || !supabase.createClient || !url || !anonKey) {
      this.updateSupabaseStatus(false, 'Realtime unavailable');
      return;
    }
    try {
      if (!this.supabaseClient) {
        this.supabaseClient = supabase.createClient(url, anonKey, { auth: { persistSession: false, autoRefreshToken: true } });
        this.supabaseClient.auth.onAuthStateChange((_event, session) => {
          if (!session) return;
          const saved = this.loadData(STORAGE_KEYS.AUTH, null);
          if (saved && saved.id === session.user.id) {
            localStorage.setItem(STORAGE_KEYS.AUTH, JSON.stringify({ ...saved, token: session.access_token, refreshToken: session.refresh_token }));
          }
        });
      }
      const saved = this.loadData(STORAGE_KEYS.AUTH, null);
      if (saved?.token && saved?.refreshToken) {
        await this.supabaseClient.auth.setSession({ access_token: saved.token, refresh_token: saved.refreshToken }).catch(() => {});
      }
      this.updateSupabaseStatus(true);
      this.initSupabaseRealtimeListeners();
    } catch (err) {
      console.warn('Supabase realtime init notice:', err);
      this.updateSupabaseStatus(false, err.message);
    }
  }

  updateSupabaseStatus(connected, message = '') {
    const el = document.getElementById('supabaseBridgeStatusText');
    if (el) {
      el.textContent = connected ? '● Supabase: Connected (live updates)' : `○ Supabase: ${message || 'Offline'}`;
      el.style.color = connected ? '#10B981' : '#94A3B8';
    }
  }

  initSupabaseRealtimeListeners() {
    if (!this.supabaseClient || this._realtimeStarted) return;
    this._realtimeStarted = true;
    const tables = ['platform_settings', 'tenants', 'profiles', 'orders', 'printer_hardware_orders', 'notifications', 'subscription_checkouts'];
    for (const table of tables) {
      try {
        this.supabaseClient
          .channel(`web_admin:${table}`)
          .on('postgres_changes', { event: '*', schema: 'public', table }, () => this.scheduleRefresh())
          .subscribe();
      } catch (err) {
        console.warn('Realtime listener error:', table, err);
      }
    }
  }

  // Debounced refresh after realtime events or mutations.
  scheduleRefresh(delay = 800) {
    clearTimeout(this._refreshTimer);
    this._refreshTimer = setTimeout(() => this.fetchPlatformState(true), delay);
  }

  // Legacy entry points kept for existing call sites; all resolve to the
  // authoritative admin API snapshot.
  fetchSettingsFromSupabase() { return this.fetchPlatformState(true); }
  fetchTenantsFromSupabase() { return this.fetchPlatformState(true); }
  fetchShopsFromSupabase() { return Promise.resolve(); }
  fetchOrdersFromSupabase() { return this.fetchPlatformState(true); }
  fetchProfilesFromSupabase() { return this.fetchPlatformState(true); }

  // Persist one settings document through the admin API.
  async syncToSupabase(settingId, data) {
    const map = {
      pricing_and_plans: () => ({ plans: data.plans, printerOptions: data.printerOptions, subscriptionAddons: data.subscriptionAddons, coupons: data.coupons }),
      remote_config: () => ({ remoteConfig: data }),
      broadcast: () => ({ broadcast: data }),
      general_settings: () => ({ settings: data }),
    };
    if (!map[settingId]) throw new Error(`Unknown setting ${settingId}`);
    const payload = Object.fromEntries(Object.entries(map[settingId]()).filter(([, v]) => v !== undefined));
    const ok = await this.saveToBridge(payload);
    if (!ok) throw new Error(`Saving ${settingId} failed`);
  }

  // saveToBridge() already persists these; kept as no-ops for old call sites.
  async syncPricingToSupabase() {}
  async syncRemoteConfigToSupabase() {}
  async syncBroadcastToSupabase() {}
  async syncPrinterOrderToSupabase() {}

  async verifyPricingSync() {
    await this.fetchPlatformState(true);
    this.showToast(`Pricing reloaded from the database (${(this.plans?.tiers || []).length} tiers, ${(this.subscriptionAddons || []).length} add-ons).`, '☁️');
  }

  // Translate a tenant view-model into the explicit fields the API accepts.
  tenantPatch(t) {
    const patch = { id: t.id || t.tenantId };
    const fields = {
      firmName: t.firmName, ownerName: t.ownerName, phone: t.phone, email: t.email, gstin: t.gstin, pan: t.pan,
      address: t.address, city: t.city, state: t.state, subscriptionPlanId: t.subscriptionPlanId,
      subscriptionStatus: t.subscriptionStatus, expiryDate: t.expiryDate, maxUsers: t.maxUsers, maxShops: t.maxShops,
    };
    for (const [k, v] of Object.entries(fields)) if (v !== undefined && v !== null) patch[k] = v;
    return patch;
  }

  async syncTenantToSupabase(tenant) {
    if (!tenant) return false;
    const ok = await this.apiMutate('/api/platform/sync-tenant', this.tenantPatch(tenant));
    this.scheduleRefresh(ok ? 200 : 0);
    return ok;
  }

  async syncUserToSupabase(user) {
    if (!user) return false;
    const ok = await this.apiMutate('/api/platform/sync-user', {
      id: user.id || user.uid, name: user.name, phone: user.phone, role: user.role, tenantId: user.tenantId, status: user.status,
    });
    this.scheduleRefresh(ok ? 200 : 0);
    return ok;
  }

  // --- ADMIN API SNAPSHOT (single source of truth: Supabase via /api) ---
  async initBridge() {
    await this.fetchPlatformState(true);
    this.stopBridge();
    // Realtime events trigger refreshes; this interval is only a safety net.
    this.refreshHealth();
    this._bridgeInterval = setInterval(() => { this.fetchPlatformState(); this.refreshHealth(); }, 60000);
  }

  async refreshHealth() {
    const set = (id, text, color) => { const el = document.getElementById(id); if (el) { el.textContent = text; if (color) el.style.color = color; } };
    try {
      const res = await fetch('/api/platform/health');
      const data = await res.json();
      set('healthValue', 'Healthy', '#10B981');
      set('healthIndicator', '● Database reachable');
      set('healthLatency', `${data.latencyMs}ms`);
    } catch (_) {
      set('healthValue', 'Degraded', '#DC2626');
      set('healthIndicator', '● Database unreachable');
      set('healthLatency', '—');
    }
    set('healthCheckedAt', new Date().toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' }));
  }

  stopBridge() {
    if (this._bridgeInterval) {
      clearInterval(this._bridgeInterval);
      this._bridgeInterval = null;
    }
  }

  async fetchPlatformState(force = false) {
    if (!this.hasSession()) return;
    if (this._fetchInFlight) { this._fetchAgain = this._fetchAgain || force; return this._fetchInFlight; }
    this._fetchInFlight = (async () => {
      try {
        const res = await fetch('/api/platform/all', { headers: this.getAuthHeaders() });
        const json = await res.json();
        if (!json.success || !json.data) return;
        const d = json.data;
        // Surface server-side problems (e.g. a missing database migration)
        // once per session instead of silently showing zeros.
        const warnKey = (d.warnings || []).join('|');
        if (warnKey && warnKey !== this._lastSnapshotWarning) {
          this._lastSnapshotWarning = warnKey;
          d.warnings.forEach(w => this.showToast(w, '⚠️', 'warning'));
        }
        const assign = (prop, key, value) => {
          if (value === undefined) return false;
          if (JSON.stringify(value) === JSON.stringify(this[prop])) return false;
          this[prop] = value;
          this.saveData(key, value);
          return true;
        };
        let changed = false;
        changed = assign('plans', STORAGE_KEYS.PLANS, d.plans) || changed;
        changed = assign('printerOptions', STORAGE_KEYS.PRINTER_OPTIONS, d.printerOptions) || changed;
        changed = assign('subscriptionAddons', STORAGE_KEYS.SUBSCRIPTION_ADDONS, d.subscriptionAddons) || changed;
        changed = assign('coupons', STORAGE_KEYS.COUPONS, d.coupons) || changed;
        changed = assign('tenants', STORAGE_KEYS.TENANTS, d.tenants) || changed;
        changed = assign('users', STORAGE_KEYS.USERS, d.users) || changed;
        changed = assign('remoteConfig', STORAGE_KEYS.REMOTE_CONFIG, d.remoteConfig) || changed;
        changed = assign('broadcast', STORAGE_KEYS.BROADCAST, d.broadcast) || changed;
        changed = assign('printerOrders', STORAGE_KEYS.PRINTER_ORDERS, d.printerOrders) || changed;
        changed = assign('retailOrders', STORAGE_KEYS.RETAIL_ORDERS, d.retailOrders) || changed;
        changed = assign('notifications', STORAGE_KEYS.NOTIFICATIONS, d.notifications) || changed;
        changed = assign('settings', STORAGE_KEYS.SETTINGS, d.settings) || changed;
        const tb = document.getElementById('badgeTenantsCount'); if (tb) tb.textContent = (this.tenants || []).length;
        const ub = document.getElementById('badgeUsersCount'); if (ub) ub.textContent = (this.users || []).length;
        this.updateCloudStatus(true);
        if (changed || force) this.renderAll();
      } catch (err) {
        this.updateCloudStatus(false, err.message);
      } finally {
        this._fetchInFlight = null;
        if (this._fetchAgain) { this._fetchAgain = false; this.fetchPlatformState(); }
      }
    })();
    return this._fetchInFlight;
  }

  // Persist catalog/config changes. Tenants, users and orders are NEVER sent
  // as whole arrays; they have dedicated, validated endpoints.
  async saveToBridge(partialState) {
    const allowed = ['plans', 'printerOptions', 'subscriptionAddons', 'coupons', 'remoteConfig', 'broadcast', 'settings'];
    const payload = {};
    for (const key of allowed) if (partialState && partialState[key] !== undefined) payload[key] = partialState[key];
    if (!Object.keys(payload).length) return true;
    try {
      const res = await fetch('/api/platform/update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...this.getAuthHeaders() },
        body: JSON.stringify(payload)
      });
      const data = await res.json();
      this.updateCloudStatus(true);
      this.scheduleRefresh(300);
      return Boolean(data && data.success);
    } catch (err) {
      // The fetch wrapper already showed the server's error message.
      this.updateCloudStatus(false);
      await this.fetchPlatformState(true);
      return false;
    }
  }

  initFirestoreRealtimeListeners() {
    if (!this.db) return;

    // 1. Live Tenants Listener
    try {
      this.db.collection('tenants').onSnapshot((snap) => {
        const cloudTenants = [];
        snap.forEach((doc) => {
          if (doc.id !== '_schema') {
            const data = doc.data();
            cloudTenants.push({
              id: doc.id,
              tenantId: doc.id,
              userId: data.ownerUid || data.distributorId || doc.id,
              firmName: data.firmName || data.name || 'Commercial Distributor',
              ownerName: data.representativeName || data.ownerName || data.contactPerson || 'Authorized Rep',
              phone: data.phone || data.mobile || 'N/A',
              city: data.city || data.territory || 'Central Hub',
              subscriptionStatus: data.subscriptionStatus || data.accountStatus || 'active',
              planName: data.subscriptionPlanId ? `${data.subscriptionPlanId.replace(/_/g, ' ').toUpperCase()} Plan` : (data.planName || 'Silver Monthly'),
              expiryDate: data.subscriptionEndDate ? (data.subscriptionEndDate.toDate ? data.subscriptionEndDate.toDate().toISOString().split('T')[0] : data.subscriptionEndDate.toString()) : 'Active',
              freemiumSelling: data.freemiumSelling ?? true,
              ordersCount: data.ordersCount || 0,
              revenue: data.revenue || data.totalRevenue || 0,
            });
          }
        });

        if (cloudTenants.length > 0) {
          this.tenants = cloudTenants;
          this.saveData(STORAGE_KEYS.TENANTS, this.tenants);
          this.renderAll();
        }

        const countEl = document.getElementById('cloudSyncedTenantsCount');
        if (countEl) countEl.textContent = this.tenants.length;
      }, (err) => {
        console.warn('Firestore tenants listener note:', err);
      });
    } catch (e) {
      console.warn('Error setting up tenants listener:', e);
    }

    // 2. Live Remote Config Listener (Both collections)
    const handleRemoteConfigSnap = (doc) => {
      if (doc.exists && doc.data()) {
        const d = doc.data();
        if (d.featureFlags && typeof d.featureFlags === 'object') {
          this.remoteConfig.featureFlags = { ...this.remoteConfig.featureFlags, ...d.featureFlags };
        }
        if (d.maintenance && typeof d.maintenance === 'object') {
          this.remoteConfig.maintenance = d.maintenance;
          this.settings.maintenanceMode = d.maintenance.active === true;
        }
        if (d.minAppVersion) this.remoteConfig.minAppVersion = d.minAppVersion;
        if (d.smsProvider) this.remoteConfig.smsProvider = d.smsProvider;
        if (d.otpDigits) this.remoteConfig.otpDigits = d.otpDigits;
        if (d.smsMode) this.remoteConfig.smsMode = d.smsMode;
        if (d.enforceOtp !== undefined) this.remoteConfig.enforceOtp = d.enforceOtp;

        this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig);
        this.saveData(STORAGE_KEYS.SETTINGS, this.settings);
        this.renderRemoteAppControl();
      }
    };

    try {
      this.db.collection('platform_settings').doc('remote_config').onSnapshot(handleRemoteConfigSnap, (err) => console.warn('remote_config note:', err));
      this.db.collection('platformSettings').doc('remote_config').onSnapshot(handleRemoteConfigSnap, (err) => console.warn('platformSettings remote_config note:', err));
    } catch (_) {}

    // 3. Live Broadcast Listener (Both collections)
    const handleBroadcastSnap = (doc) => {
      if (doc.exists && doc.data()) {
        const b = doc.data();
        this.broadcast = { ...this.broadcast, ...b };
        this.saveData(STORAGE_KEYS.BROADCAST, this.broadcast);
        this.renderBroadcastCenter();
      }
    };

    try {
      this.db.collection('platform_settings').doc('broadcast').onSnapshot(handleBroadcastSnap, (err) => console.warn('broadcast note:', err));
      this.db.collection('platformSettings').doc('broadcast').onSnapshot(handleBroadcastSnap, (err) => console.warn('platformSettings broadcast note:', err));
    } catch (_) {}

    // 4. Live Pricing & Plans Listener (Both collections)
    const handlePricingSnap = (doc) => {
      if (doc.exists && doc.data()) {
        const p = doc.data();

        // 1. Parse dynamic tiers if present
        let parsedTiers = this.plans?.tiers || DEFAULT_PLANS.tiers;
        if (p.plans) {
          if (Array.isArray(p.plans)) {
            parsedTiers = p.plans;
          } else if (typeof p.plans === 'object') {
            parsedTiers = Object.values(p.plans);
          }
        }

        const startupTier = parsedTiers.find(t => t.id === 'startup') || parsedTiers[0];
        const growTier = parsedTiers.find(t => t.id === 'grow') || parsedTiers[1];
        const enterpriseTier = parsedTiers.find(t => t.id === 'enterprise') || parsedTiers[2];

        this.plans = {
          tiers: parsedTiers,
          silverPrice: startupTier?.monthlyPrice || p.monthlyPlanPrice || this.plans.silverPrice,
          goldPrice: growTier?.monthlyPrice || p.quarterlyPlanPrice || this.plans.goldPrice,
          platinumPrice: enterpriseTier?.monthlyPrice || p.annualPlanPrice || this.plans.platinumPrice,
          printerPrice: p.printerHardwarePrice || this.plans.printerPrice,
          planGst: p.planGstRate || this.plans.planGst || 18,
          printerGst: p.printerGstRate || this.plans.printerGst || 18,
        };
        this.saveData(STORAGE_KEYS.PLANS, this.plans);

        // 2. Parse dynamic printer options if present
        if (p.printerOptions) {
          if (Array.isArray(p.printerOptions)) {
            this.printerOptions = p.printerOptions;
          } else if (typeof p.printerOptions === 'object') {
            this.printerOptions = Object.values(p.printerOptions);
          }
          this.saveData(STORAGE_KEYS.PRINTER_OPTIONS, this.printerOptions);
        }

        this.renderPlansGrid();
        this.renderPrintersGrid();
      }
    };

    try {
      this.db.collection('platform_settings').doc('pricing_and_plans').onSnapshot(handlePricingSnap, (err) => console.warn('pricing note:', err));
      this.db.collection('platformSettings').doc('pricing_and_plans').onSnapshot(handlePricingSnap, (err) => console.warn('platformSettings pricing note:', err));
    } catch (_) {}

    // 5. Live Promo Codes Listener
    try {
      this.db.collection('promoCodes').onSnapshot((snap) => {
        const cloudCoupons = [];
        snap.forEach((doc) => {
          const d = doc.data();
          cloudCoupons.push({
            id: doc.id,
            code: d.code || doc.id,
            type: d.type || (d.discountType === 'days' ? 'trial' : 'flat'),
            title: d.title || d.code,
            value: d.value || d.discountValue || 30,
            minOrderValue: d.minOrderValue || 0,
            usedCount: d.usedCount || 0,
            maxUses: d.maxUses || 500,
            validUntil: d.validUntil || '2027-12-31',
            isActive: d.isActive !== false,
            description: d.description || '',
          });
        });
        if (cloudCoupons.length > 0) {
          this.coupons = cloudCoupons;
          this.saveData(STORAGE_KEYS.COUPONS, this.coupons);
          this.renderCouponsTable();
          this.renderSyncPills();
        }
      }, (err) => console.warn('promoCodes note:', err));
    } catch (_) {}

    // 6. Live Hardware Orders Listener
    try {
      this.db.collection('platform_hardware_orders').onSnapshot((snap) => {
        const cloudOrders = [];
        snap.forEach((doc) => {
          const d = doc.data();
          cloudOrders.push({
            id: doc.id,
            userId: d.userId || d.tenantId || 'SA-USR',
            customerName: d.customerName || d.representativeName || 'Distributor',
            agencyName: d.agencyName || d.firmName || 'Agency',
            phone: d.phone || 'N/A',
            plan: d.plan || 'Active Plan',
            printerItem: d.printerItem || '58mm Bluetooth Thermal POS Printer',
            shippingAddress: d.shippingAddress || 'Commercial Address',
            orderedAt: d.orderedAt || new Date().toISOString(),
            status: d.status || 'Pending',
            courierName: d.courierName || 'DTDC',
            trackingNumber: d.trackingNumber || 'Unassigned',
          });
        });
        if (cloudOrders.length > 0) {
          this.printerOrders = cloudOrders;
          this.saveData(STORAGE_KEYS.PRINTER_ORDERS, this.printerOrders);
          this.renderPrintersTable();
        }
      }, (err) => console.warn('platform_hardware_orders note:', err));
    } catch (_) {}
  }

  async pushAllToCloudFirestore() {
    if (!this.db) {
      this.showToast('Cloud Firestore not connected!', '⚠️', 'warning');
      return;
    }
    try {
      this.showToast('Pushing configurations & coupons to Cloud Firestore...', '⏳', 'info');
      // 1. Push remote config & feature flags
      const rPayload = {
        featureFlags: this.remoteConfig?.featureFlags || {},
        minAppVersion: this.remoteConfig?.minAppVersion || 'v2.4.1',
        smsProvider: this.remoteConfig?.smsProvider || 'firebase',
        smsMode: this.remoteConfig?.smsMode || 'live',
        otpDigits: this.remoteConfig?.otpDigits || 6,
        enforceOtp: this.remoteConfig?.enforceOtp ?? false,
        maintenance: this.remoteConfig?.maintenance || { active: false },
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      };
      await this.db.collection('platform_settings').doc('remote_config').set(rPayload, { merge: true });
      await this.db.collection('platformSettings').doc('remote_config').set(rPayload, { merge: true });

      // 2. Push broadcast
      if (this.broadcast) {
        await this.db.collection('platform_settings').doc('broadcast').set({
          ...this.broadcast,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        await this.db.collection('platformSettings').doc('broadcast').set({
          ...this.broadcast,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }

      // 3. Push pricing & plans
      if (this.plans) {
        const pPayload = {
          monthlyPlanPrice: this.plans.silverPrice,
          quarterlyPlanPrice: this.plans.goldPrice,
          annualPlanPrice: this.plans.platinumPrice,
          printerHardwarePrice: this.plans.printerPrice,
          planGstRate: this.plans.planGst,
          printerGstRate: this.plans.printerGst,
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        };
        await this.db.collection('platform_settings').doc('pricing_and_plans').set(pPayload, { merge: true });
        await this.db.collection('platformSettings').doc('pricing_and_plans').set(pPayload, { merge: true });
      }

      // 4. Push coupons to promoCodes
      if (this.coupons && Array.isArray(this.coupons)) {
        for (const c of this.coupons) {
          await this.db.collection('promoCodes').doc(c.code).set({
            code: c.code,
            title: c.title,
            type: c.type,
            discountType: c.type === 'trial' ? 'days' : (c.type === 'flat' ? 'flat' : 'percent'),
            discountValue: c.value,
            value: c.value,
            minOrderValue: c.minOrderValue || 0,
            maxUses: c.maxUses || 500,
            validUntil: c.validUntil,
            isActive: c.isActive !== false,
            description: c.description || '',
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
        }
      }

      this.showToast('All configurations and promo codes pushed to Cloud Firestore!', '☁️', 'success');
      this.updateCloudStatus(true);
    } catch (e) {
      console.error('Push to cloud error:', e);
      this.showToast(`Push failed: ${e.message}`, '❌', 'danger');
    }
  }

  async pullAllFromCloudFirestore() {
    if (!this.db) {
      this.showToast('Cloud Firestore not connected!', '⚠️', 'warning');
      return;
    }
    try {
      this.showToast('Pulling live central database from Cloud Firestore...', '⏳', 'info');
      // 1. Pull tenants
      const tenantsSnap = await this.db.collection('tenants').get();
      if (!tenantsSnap.empty) {
        const fetchedTenants = [];
        tenantsSnap.forEach(doc => {
          if (doc.id !== '_schema') {
            const data = doc.data();
            fetchedTenants.push({
              id: doc.id,
              tenantId: doc.id,
              userId: data.ownerUid || data.distributorId || doc.id,
              firmName: data.firmName || data.name || 'Commercial Distributor',
              ownerName: data.representativeName || data.ownerName || data.contactPerson || 'Authorized Rep',
              phone: data.phone || data.mobile || 'N/A',
              city: data.city || data.territory || 'Central Hub',
              subscriptionStatus: data.subscriptionStatus || data.accountStatus || 'active',
              planName: data.subscriptionPlanId ? `${data.subscriptionPlanId.replace(/_/g, ' ').toUpperCase()} Plan` : (data.planName || 'Silver Monthly'),
              expiryDate: data.subscriptionEndDate ? (data.subscriptionEndDate.toDate ? data.subscriptionEndDate.toDate().toISOString().split('T')[0] : data.subscriptionEndDate.toString()) : 'Active',
              freemiumSelling: data.freemiumSelling ?? true,
              ordersCount: data.ordersCount || 0,
              revenue: data.revenue || data.totalRevenue || 0,
            });
          }
        });
        if (fetchedTenants.length > 0) {
          this.tenants = fetchedTenants;
          this.saveData(STORAGE_KEYS.TENANTS, this.tenants); this.saveToBridge({ tenants: this.tenants });
        }
      }

      // 2. Pull remote config
      const rSnap = await this.db.collection('platform_settings').doc('remote_config').get();
      if (rSnap.exists) {
        const d = rSnap.data();
        if (d && d.featureFlags) {
          this.remoteConfig.featureFlags = { ...this.remoteConfig.featureFlags, ...d.featureFlags };
        }
        if (d && d.maintenance) this.remoteConfig.maintenance = d.maintenance;
        this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig); this.saveToBridge({ remoteConfig: this.remoteConfig });
      }

      // 3. Pull broadcast
      const bSnap = await this.db.collection('platform_settings').doc('broadcast').get();
      if (bSnap.exists) {
        this.broadcast = bSnap.data();
        this.saveData(STORAGE_KEYS.BROADCAST, this.broadcast); this.saveToBridge({ broadcast: this.broadcast });
      }

      // 4. Pull pricing
      const pSnap = await this.db.collection('platform_settings').doc('pricing_and_plans').get();
      if (pSnap.exists) {
        const p = pSnap.data();
        this.plans = {
          silverPrice: p.monthlyPlanPrice || this.plans.silverPrice,
          goldPrice: p.quarterlyPlanPrice || this.plans.goldPrice,
          platinumPrice: p.annualPlanPrice || this.plans.platinumPrice,
          printerPrice: p.printerHardwarePrice || this.plans.printerPrice,
          planGst: p.planGstRate || this.plans.planGst,
          printerGst: p.printerGstRate || this.plans.printerGst,
        };
        this.saveData(STORAGE_KEYS.PLANS, this.plans); this.saveToBridge({ plans: this.plans });
      }

      this.renderAll();
      this.showToast('Successfully synchronized with central Cloud Firestore!', '🎉', 'success');
    } catch (e) {
      console.error('Pull from cloud error:', e);
      this.showToast(`Pull failed: ${e.message}`, '❌', 'danger');
    }
  }

  // --- Authentication ---
  initAuth() {
    let session = null;
    try {
      session = JSON.parse(localStorage.getItem(STORAGE_KEYS.AUTH) || 'null');
    } catch (_) {}

    const gate = document.getElementById('authGate');
    const form = document.getElementById('loginForm');

    if (form && !form._bound) {
      form._bound = true;
      form.addEventListener('submit', (e) => {
        e.preventDefault();
        const email = document.getElementById('loginEmail')?.value || '';
        const pass = document.getElementById('loginPassword')?.value || '';
        this.handleLogin(email, pass);
      });
    }

    if (session && session.token && session.role === 'super_admin') {
      if (gate) gate.classList.add('hidden');
    } else if (gate) {
      gate.classList.remove('hidden');
    }
  }

  async handleLogin(email, password) {
    const errorEl = document.getElementById('authError');
    const submitBtn = document.querySelector('#loginForm button[type="submit"]');
    let loginData = null;

    try {
      if (submitBtn) {
        submitBtn.disabled = true;
        submitBtn.style.opacity = '0.7';
      }
      if (errorEl) errorEl.style.display = 'none';

      const response = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email: (email || '').trim(), password }),
      });
      const result = await response.json();
      if (!result.success || result.user?.role !== 'super_admin' || !result.token) {
        throw new Error(result.error || 'An active Super Admin account is required.');
      }
      loginData = result;
    } catch (authError) {
      localStorage.removeItem(STORAGE_KEYS.AUTH);
      if (errorEl) {
        errorEl.textContent = authError.message || 'Invalid credentials.';
        errorEl.style.display = 'block';
      }
      return;
    } finally {
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.style.opacity = '1';
      }
    }

    // 1. Persist authenticated session
    // Clear any previous admin's cached data before storing the new session.
    this.clearLocalData();
    localStorage.setItem(STORAGE_KEYS.AUTH, JSON.stringify({ ...loginData.user, token: loginData.token, refreshToken: loginData.refreshToken }));
    
    // 2. Hide gate immediately and clear errors
    const gate = document.getElementById('authGate');
    if (gate) gate.classList.add('hidden');
    if (errorEl) errorEl.style.display = 'none';

    // 3. Load live data (realtime + admin API snapshot)
    try {
      await this.startDataSync();
    } catch (e) {
      console.warn('Post-login data load notice:', e);
    }

    this.showToast('Welcome back, Super Admin!', '👋');
  }

  async handleLogout() {
    if (confirm('Are you sure you want to sign out of the Super Admin Console?')) {
      if (this.supabaseClient) {
        try {
          await this.supabaseClient.auth.signOut();
        } catch (_) {}
      }
      // Stop background polling before clearing the bearer so a stray tick
      // doesn't hit the API with a now-invalid token.
      this.stopBridge();
      // Remove the session AND every cached tenant/user/order record.
      this.clearLocalData();
      ['coupons','printerOrders','tenants','users','retailOrders','notifications'].forEach(k => { this[k] = []; });
      this.renderAll();
      document.getElementById('authGate')?.classList.remove('hidden');
      this.showToast('Signed out of admin portal.', '🚪');
    }
  }

  // --- Element Bindings ---
  initElements() {
    this.navItems = document.querySelectorAll('.nav-item');
    this.views = document.querySelectorAll('.view-section');
    this.pageTitle = document.getElementById('pageTitle');
    this.toastEl = document.getElementById('toast');
    this.couponModal = document.getElementById('couponModal');
  }

  bindEvents() {
    // Navigation
    this.navItems.forEach(item => {
      item.addEventListener('click', () => {
        const view = item.dataset.view;
        this.switchView(view);
      });
    });



    // Logout
    document.getElementById('btnAdminLogout')?.addEventListener('click', () => {
      this.handleLogout();
    });

    // Modal overlay click to close
    document.querySelectorAll('.modal-overlay').forEach(overlay => {
      overlay.addEventListener('click', (e) => {
        if (e.target === overlay) {
          overlay.classList.remove('active');
        }
      });
    });

    // Escape key closes modals
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') {
        document.querySelectorAll('.modal-overlay.active').forEach(m => m.classList.remove('active'));
      }
    });

    // Coupon modals
    document.getElementById('btnOpenAddCoupon')?.addEventListener('click', () => this.openCouponModal());
    document.getElementById('btnQuickAddCoupon')?.addEventListener('click', () => this.openCouponModal());
    document.getElementById('btnCloseCouponModal')?.addEventListener('click', () => this.closeCouponModal());
    document.getElementById('btnCancelCouponModal')?.addEventListener('click', () => this.closeCouponModal());

    document.getElementById('couponForm')?.addEventListener('submit', (e) => {
      e.preventDefault();
      this.handleSaveCoupon();
    });

    document.getElementById('btnGenerateCode')?.addEventListener('click', () => {
      const type = document.getElementById('couponType').value;
      const prefix = type === 'trial' ? 'TRIAL' : (type === 'flat' ? 'SAVE' : 'OFF');
      const random = Math.floor(10 + Math.random() * 90);
      document.getElementById('couponCode').value = `${prefix}${random}`;
    });

    // Coupon type change hint
    document.getElementById('couponType')?.addEventListener('change', (e) => {
      const hint = document.getElementById('couponHint');
      const valInput = document.getElementById('couponValue');
      if (e.target.value === 'trial') {
        hint.textContent = 'For trial: Enter number of free membership days (e.g., 14, 30).';
        valInput.placeholder = '30 (days)';
      } else if (e.target.value === 'flat') {
        hint.textContent = 'For flat: Enter fixed rupee amount to deduct (e.g., 100, 200).';
        valInput.placeholder = '100 (₹)';
      } else {
        hint.textContent = 'For percentage: Enter percentage discount (e.g., 25, 50).';
        valInput.placeholder = '25 (%)';
      }
    });

    // Coupon filters
    document.querySelectorAll('.filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.couponFilter = btn.dataset.filter;
        this.renderCouponsTable();
      });
    });

    document.getElementById('couponStatusFilter')?.addEventListener('change', (e) => {
      this.couponStatusFilter = e.target.value;
      this.renderCouponsTable();
    });

    // Coupon search
    document.getElementById('searchCouponsInput')?.addEventListener('input', (e) => {
      this.couponSearch = e.target.value.toLowerCase().trim();
      const btn = document.getElementById('btnClearCouponSearch');
      if (btn) btn.style.display = this.couponSearch ? 'flex' : 'none';
      this.renderCouponsTable();
    });

    // Printer filters & search
    document.querySelectorAll('.printer-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.printer-filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.printerFilter = btn.dataset.printerFilter;
        this.renderPrintersTable();
      });
    });

    document.getElementById('searchPrintersInput')?.addEventListener('input', (e) => {
      this.printerSearch = e.target.value.toLowerCase().trim();
      const btn = document.getElementById('btnClearPrinterSearch');
      if (btn) btn.style.display = this.printerSearch ? 'flex' : 'none';
      this.renderPrintersTable();
    });

    // Global Omnisearch & Keyboard Shortcuts (⌘K, /)
    document.addEventListener('keydown', (e) => {
      if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === 'k') {
        e.preventDefault();
        const omni = document.getElementById('globalOmnisearchInput');
        if (omni) { omni.focus(); omni.select(); }
        return;
      }
      if (e.key === 'Escape') {
        this.clearOmnisearch();
        if (document.activeElement && typeof document.activeElement.blur === 'function') {
          document.activeElement.blur();
        }
        return;
      }
      if (e.key === '/' && !['INPUT', 'TEXTAREA', 'SELECT'].includes(e.target.tagName)) {
        e.preventDefault();
        const map = {
          tenants: 'searchTenantsInput',
          orders: 'searchOrdersInput',
          users: 'searchUsersInput',
          coupons: 'searchCouponsInput',
          printers: 'searchPrintersInput',
        };
        const el = document.getElementById(map[this.currentView] || 'globalOmnisearchInput');
        if (el) { el.focus(); el.select(); }
      }
    });

    document.addEventListener('click', (e) => {
      if (!e.target.closest('.topbar-omnisearch')) {
        document.getElementById('omnisearchDropdown')?.classList.remove('active');
      }
    });

    // Tenant filters & search
    document.querySelectorAll('.tenant-filter-btn').forEach(btn => {
      btn.addEventListener('click', () => {
        document.querySelectorAll('.tenant-filter-btn').forEach(b => b.classList.remove('active'));
        btn.classList.add('active');
        this.tenantFilter = btn.dataset.tenantFilter;
        this.renderTenantsView();
      });
    });

    document.getElementById('searchTenantsInput')?.addEventListener('input', (e) => {
      this.tenantSearch = e.target.value.toLowerCase().trim();
      const btnClear = document.getElementById('btnClearTenantSearch');
      if (btnClear) btnClear.style.display = this.tenantSearch ? 'inline-block' : 'none';
      this.renderTenantsView();
    });
  }


  clearCouponSearch() {
    this.couponSearch = '';
    const input = document.getElementById('searchCouponsInput');
    if (input) input.value = '';
    const btn = document.getElementById('btnClearCouponSearch');
    if (btn) btn.style.display = 'none';
    this.renderCouponsTable();
  }

  clearPrinterSearch() {
    this.printerSearch = '';
    const input = document.getElementById('searchPrintersInput');
    if (input) input.value = '';
    const btn = document.getElementById('btnClearPrinterSearch');
    if (btn) btn.style.display = 'none';
    this.renderPrintersTable();
  }

  handleOmnisearch(query) {
    const q = (query || '').trim().toLowerCase();
    const btn = document.getElementById('btnClearOmnisearch');
    const dropdown = document.getElementById('omnisearchDropdown');
    if (btn) btn.style.display = q ? 'flex' : 'none';
    if (!dropdown) return;

    if (!q) {
      dropdown.classList.remove('active');
      dropdown.innerHTML = '';
      return;
    }

    const results = [];

    // 1. Navigation Pages
    const pages = [
      { id: 'dashboard', title: 'Executive Dashboard', sub: 'Overview, GMV, Orders & Analytics', icon: '⚡' },
      { id: 'tenants', title: 'Agencies & Tenants Directory', sub: 'Manage SaaS tenants & quotas', icon: '🏢' },
      { id: 'users', title: 'Platform Staff & RBAC', sub: 'User accounts & agency staff roles', icon: '👥' },
      { id: 'plans', title: 'SaaS Plans & Pricing', sub: 'Subscription tiers & hardware catalog', icon: '💳' },
      { id: 'coupons', title: 'Coupons & Promo Passes', sub: 'Discount codes & extended trials', icon: '🏷️' },
      { id: 'printers', title: 'Hardware Orders', sub: 'Thermal POS printers & tracking', icon: '🖨️' },
      { id: 'billing', title: 'Billing & Subscriptions', sub: 'Checkouts, renewals & payments', icon: '📊' },
      { id: 'gateways', title: 'Payment Gateways & Checkout Engine', sub: 'Razorpay, Cashfree, UPI VPA & webhooks', icon: '💳' },
      { id: 'broadcasts', title: 'In-App Announcements & Push', sub: 'Emergency alerts & plan notifications', icon: '📢' },
      { id: 'app-control', title: 'Remote App Control', sub: 'Feature flags & maintenance lock', icon: '📱' },
      { id: 'audit-logs', title: 'Audit Trail & System Health', sub: 'Security events, DB drift & telemetry', icon: '🛡️' },
      { id: 'settings', title: 'Platform Settings', sub: 'Super admin passcode & business info', icon: '⚙️' },
    ];
    const matchPages = pages.filter(p => p.title.toLowerCase().includes(q) || p.sub.toLowerCase().includes(q) || p.id.includes(q)).slice(0, 3);
    if (matchPages.length) {
      results.push({ group: 'Platform Navigation', items: matchPages.map(p => ({
        icon: p.icon,
        title: p.title,
        sub: p.sub,
        action: () => { this.switchView(p.id); this.clearOmnisearch(); }
      })) });
    }

    // 2. Agencies & Tenants
    const matchTenants = (this.tenants || []).filter(t =>
      (t.firmName || t.name || '').toLowerCase().includes(q) ||
      (t.ownerName || '').toLowerCase().includes(q) ||
      (t.userId || '').toLowerCase().includes(q) ||
      (t.city || '').toLowerCase().includes(q)
    ).slice(0, 4);

    if (matchTenants.length) {
      results.push({ group: 'Agencies & Tenants', items: matchTenants.map(t => ({
        icon: '🏢',
        title: t.firmName || t.name || 'Agency',
        sub: `${t.ownerName || 'Proprietor'} • ${t.city || 'Location'} (ID: ${t.userId || t.id})`,
        badge: t.subscriptionStatus ? t.subscriptionStatus.toUpperCase() : 'ACTIVE',
        action: () => { this.switchView('tenants'); this.openTenantDetailModal(t.id); this.clearOmnisearch(); }
      })) });
    }

    // 4. Staff Users
    const matchUsers = (this.users || []).filter(u =>
      (u.name || '').toLowerCase().includes(q) ||
      (u.email || '').toLowerCase().includes(q) ||
      (u.phone || '').includes(q)
    ).slice(0, 3);

    if (matchUsers.length) {
      results.push({ group: 'Staff & Workforce', items: matchUsers.map(u => ({
        icon: '👤',
        title: u.name || 'User',
        sub: `${u.email || ''} • ${u.role || 'Staff'}`,
        badge: (u.role || 'USER').toUpperCase(),
        action: () => { this.switchView('users'); this.openUserModal(u.id); this.clearOmnisearch(); }
      })) });
    }

    // 5. Coupons
    const matchCoupons = (this.coupons || []).filter(c =>
      (c.code || '').toLowerCase().includes(q) ||
      (c.title || '').toLowerCase().includes(q)
    ).slice(0, 3);

    if (matchCoupons.length) {
      results.push({ group: 'Coupons & Passes', items: matchCoupons.map(c => ({
        icon: '🏷️',
        title: c.code || 'CODE',
        sub: c.title || c.description || 'Discount Coupon',
        badge: (c.type || 'coupon').toUpperCase(),
        action: () => { this.switchView('coupons'); this.clearOmnisearch(); }
      })) });
    }

    if (!results.length) {
      dropdown.innerHTML = `
        <div style="padding: 24px; text-align: center; color: var(--text-muted); font-size: 12.5px;">
          No matching records found for "<strong>${this.escapeHtml(q)}</strong>"
        </div>
      `;
    } else {
      let html = '';
      window._omnisearchActions = [];
      let actionIdx = 0;

      results.forEach(g => {
        html += `<div class="omnisearch-group-title">${this.escapeHtml(g.group)}</div>`;
        g.items.forEach(item => {
          const idx = actionIdx++;
          window._omnisearchActions[idx] = item.action;
          html += `
            <div class="omnisearch-item" onclick="window._omnisearchActions[${idx}]()">
              <div class="omnisearch-item-icon" style="background: var(--bg-subtle);">${item.icon}</div>
              <div class="omnisearch-item-info">
                <div class="omnisearch-item-title">${this.escapeHtml(item.title)}</div>
                <div class="omnisearch-item-sub">${this.escapeHtml(item.sub)}</div>
              </div>
              ${item.badge ? `<span class="badge badge-indigo omnisearch-item-badge">${this.escapeHtml(item.badge)}</span>` : ''}
            </div>
          `;
        });
      });
      dropdown.innerHTML = html;
    }

    dropdown.classList.add('active');
  }

  clearOmnisearch() {
    const input = document.getElementById('globalOmnisearchInput');
    if (input) input.value = '';
    const btn = document.getElementById('btnClearOmnisearch');
    if (btn) btn.style.display = 'none';
    const dropdown = document.getElementById('omnisearchDropdown');
    if (dropdown) dropdown.classList.remove('active');
  }

  switchView(viewId) {
    this.currentView = viewId;
    this.navItems.forEach(item => {
      const match = (item.dataset.view === viewId) || ((viewId === 'tenant-drilldown' || viewId === 'tenant-profile') && item.dataset.view === 'tenants');
      item.classList.toggle('active', match);
    });

    this.views.forEach(v => {
      v.classList.toggle('active', v.id === `view-${viewId}`);
    });

    const titles = {
      dashboard: 'Dashboard',
      'app-control': 'Remote App Control',
      billing: 'Subscriptions',
      'tenant-drilldown': 'Subscriber Drill-Down',
      'tenant-profile': 'Subscriber Profile',
      revenue: 'Revenue Reports',
      broadcasts: 'In App Broadcast',
      coupons: 'Coupon & Offers',
      plans: 'Plan & Pricing Control',
      printers: 'Orders',
      orders: 'Orders',
      tenants: 'Subscribers',
      users: 'User Management',
      settings: 'Platform Setting',
      gateways: 'Payment Gateway Configuration',
      'audit-logs': 'Audit Trail & Health',
    };
    if (this.pageTitle) {
      this.pageTitle.textContent = titles[viewId] || 'Admin Console';
    }

    if (viewId === 'dashboard') this.renderDashboard();
    if (viewId === 'app-control') this.renderRemoteAppControl();
    if (viewId === 'broadcasts') this.renderBroadcastCenter();
    if (viewId === 'coupons') this.renderCouponsTable();
    if (viewId === 'plans') {
      this.renderPlansGrid();
      this.renderPrintersGrid();
      this.renderAddonsGrid();
    }
    if (viewId === 'printers') this.renderPrintersTable();
    if (viewId === 'orders') this.switchOrderTab('hardware');
    if (viewId === 'users') this.renderUsersTable();
    if (viewId === 'sync') this.renderSyncPills();
    if (viewId === 'settings') this.renderPlatformSettings();
    if (viewId === 'gateways') this.renderGatewaySettings();
    if (viewId === 'audit-logs') this.renderAuditLogs();
    if (viewId === 'billing') this.renderBilling();
    if (viewId === 'revenue') this.loadRevenueReports();
    if (viewId === 'tenant-drilldown') this.renderTenantDrilldown();
    if (viewId === 'tenants') this.renderTenantsView();
  }

  showToast(message, icon = '✓', type = 'success') {
    const container = document.getElementById('toastContainer');
    const isError = type === 'danger' || type === 'error' || message.toLowerCase().includes('failed') || message.toLowerCase().includes('error');
    const isWarn = type === 'warning' || message.toLowerCase().includes('warning') || message.toLowerCase().includes('lock');
    const cleanIcon = isError 
      ? `<svg class="icon icon-sm" viewBox="0 0 24 24" style="color: var(--rose-text);"><circle cx="12" cy="12" r="10"></circle><line x1="15" y1="9" x2="9" y2="15"></line><line x1="9" y1="9" x2="15" y2="15"></line></svg>`
      : (isWarn 
        ? `<svg class="icon icon-sm" viewBox="0 0 24 24" style="color: var(--amber-text);"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"></path><line x1="12" y1="9" x2="12" y2="13"></line><line x1="12" y1="17" x2="12.01" y2="17"></line></svg>`
        : `<svg class="icon icon-sm" viewBox="0 0 24 24" style="color: var(--emerald-text);"><polyline points="20 6 9 17 4 12"></polyline></svg>`);

    if (container) {
      const toast = document.createElement('div');
      toast.className = `toast-item ${type}`;
      toast.innerHTML = `${cleanIcon} <span>${this.escapeHtml(message)}</span>`;
      container.appendChild(toast);
      requestAnimationFrame(() => {
        toast.classList.add('show');
      });
      setTimeout(() => {
        toast.classList.remove('show');
        setTimeout(() => toast.remove(), 350);
      }, 3500);
      return;
    }
    if (!this.toastEl) return;
    this.toastEl.innerHTML = `${cleanIcon} <span>${this.escapeHtml(message)}</span>`;
    this.toastEl.classList.add('show');
    setTimeout(() => {
      this.toastEl.classList.remove('show');
    }, 3200);
  }


  // ==============================================
  // USER MANAGEMENT & RBAC DIRECTORY
  // ==============================================
  renderUsersTable() {
    const tbody = document.getElementById('usersTableBody');
    const badgeCount = document.getElementById('badgeUsersCount');
    if (badgeCount) badgeCount.textContent = (this.users || []).length;

    // Populate agency filter dropdown if needed
    const filterTenantSelect = document.getElementById('filterUserTenant');
    if (filterTenantSelect && filterTenantSelect.options.length <= 1) {
      const currentVal = this.userTenantFilter || 'all';
      filterTenantSelect.innerHTML = '<option value="all">All Agencies</option>' + 
        (this.tenants || []).map(t => `<option value="${this.escapeHtml(t.id || t.tenantId)}" ${currentVal === (t.id || t.tenantId) ? 'selected' : ''}>${this.escapeHtml(t.firmName || t.name)}</option>`).join('');
    }

    if (!tbody) return;

    let filtered = (this.users || []).slice();

    if (this.userFilter && this.userFilter !== 'all') {
      filtered = filtered.filter(u => u.role === this.userFilter);
    }
    if (this.userStatusFilter && this.userStatusFilter !== 'all') {
      filtered = filtered.filter(u => u.status === this.userStatusFilter);
    }
    if (this.userTenantFilter && this.userTenantFilter !== 'all') {
      filtered = filtered.filter(u => u.tenantId === this.userTenantFilter);
    }
    if (this.userSearch) {
      const q = this.userSearch.toLowerCase();
      filtered = filtered.filter(u => 
        (u.name && u.name.toLowerCase().includes(q)) ||
        (u.email && u.email.toLowerCase().includes(q)) ||
        (u.phone && u.phone.toLowerCase().includes(q)) ||
        (u.tenantName && u.tenantName.toLowerCase().includes(q)) ||
        (u.userId && String(u.userId).toLowerCase().includes(q))
      );
    }

    if (filtered.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="7" style="text-align: center; padding: 36px; color: var(--text-muted);">
            No users match current filters. Click "+ Add New User" to register a staff or distributor account.
          </td>
        </tr>
      `;
      return;
    }

    const roleLabels = {
      super_admin: 'Super Admin',
      distributor: 'Agency Owner',
      owner: 'Agency Owner',
      sales_person: 'Field Sales',
      salesman: 'Field Sales',
      delivery_agent: 'Van Delivery',
      delivery: 'Van Delivery',
      accountant: 'Accountant',
      manager: 'Store Manager'
    };

    tbody.innerHTML = filtered.map(u => {
      const roleClassMap = { sales_person: 'salesman', delivery_agent: 'delivery', owner: 'distributor' };
      const roleBadgeClass = `badge-role-${roleClassMap[u.role] || String(u.role || 'salesman').replace(/[^a-z_]/g, '')}`;
      const statusBadgeClass = `badge-status-${String(u.status || 'active').replace(/[^a-z_]/g, '')}`;
      const roleName = roleLabels[u.role] || u.role;
      const createdDate = u.createdAt ? new Date(u.createdAt).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : 'Active';

      const initials = (u.name || 'US').split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();

      return `
        <tr>
          <td>
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="width: 32px; height: 32px; border-radius: var(--radius-xs); background: linear-gradient(135deg, #6366F1, #8B5CF6); color: white; display: flex; align-items: center; justify-content: center; font-size: 11.5px; font-weight: 800; flex-shrink: 0;">${this.escapeHtml(initials)}</div>
              <div>
                <div style="font-weight: 700; color: var(--text-main); font-size: 13.5px;">${this.escapeHtml(u.name)}</div>
                <div style="font-size: 11.5px; color: var(--text-muted); margin-top: 2px;">
                  <span>✉️ ${this.escapeHtml(u.email)}</span> • <span>📞 ${this.escapeHtml(u.phone || 'N/A')}</span>
                </div>
              </div>
            </div>
          </td>
          <td>
            ${u.userId ? `<div class="code-pill">
              <span>${this.escapeHtml(u.userId)}</span>
              <button onclick="adminApp.copyText('${this.escapeJs(u.userId)}')" style="background:transparent; border:none; color:var(--text-muted); cursor:pointer;" title="Copy User ID">📋</button>
            </div>` : '<span style="font-size: 12px; color: var(--text-muted);">—</span>'}
          </td>
          <td>
            <span class="${roleBadgeClass}">${this.escapeHtml(roleName)}</span>
          </td>
          <td>
            <div style="font-size: 13px; font-weight: 600; color: var(--text-main);">${this.escapeHtml(u.tenantName || 'Platform Central')}</div>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 2px;">Tenant: <code>${this.escapeHtml(u.tenantId || 'platform_tenant')}</code></div>
          </td>
          <td>
            <span class="${statusBadgeClass}">
              <span style="width: 5px; height: 5px; border-radius: 50%; background: currentColor; display: inline-block; margin-right: 4px;"></span>
              ${this.escapeHtml((u.status || 'active').toUpperCase())}
            </span>
          </td>
          <td style="font-size: 12px; color: var(--text-muted); font-variant-numeric: tabular-nums;">${createdDate}</td>
          <td>
            <div style="display: flex; gap: 6px;">
              <button class="btn btn-sm btn-outline" onclick="adminApp.openUserModal('${this.escapeJs(u.id || u.uid)}')" title="Edit User">Edit</button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.openUserPasswordResetModal('${this.escapeJs(u.id || u.uid)}')" title="Reset Password">🔑</button>
              <button class="btn btn-sm btn-outline" style="color: ${u.status === 'active' ? '#DC2626' : '#16A34A'};" onclick="adminApp.toggleUserStatus('${this.escapeJs(u.id || u.uid)}')">
                ${u.status === 'active' ? 'Suspend' : 'Activate'}
              </button>
              ${u.role !== 'super_admin' ? `<button class="btn btn-sm btn-outline" style="color: #DC2626;" onclick="adminApp.deleteUser('${this.escapeJs(u.id || u.uid)}')">✕</button>` : ''}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  filterUsersByTenant(tenantId) {
    this.userTenantFilter = tenantId;
    this.renderUsersTable();
  }

  openUserPasswordResetModal(userId) {
    const user = (this.users || []).find(u => u.id === userId || u.uid === userId);
    if (!user) return;
    const idInput = document.getElementById('resetPassUserId');
    const nameEl = document.getElementById('resetPassUserName');
    const emailEl = document.getElementById('resetPassUserEmail');
    const passInput = document.getElementById('resetPassNewInput');

    if (idInput) idInput.value = user.id || user.uid;
    if (nameEl) nameEl.textContent = user.name;
    if (emailEl) emailEl.textContent = `${user.email} (${(user.role || 'user').toUpperCase()})`;
    if (passInput) passInput.value = this.generateStrongPassword();

    document.getElementById('userPasswordResetModal')?.classList.add('active');
  }

  closeUserPasswordResetModal() {
    document.getElementById('userPasswordResetModal')?.classList.remove('active');
  }

  generateRandomPasswordForReset() {
    const passInput = document.getElementById('resetPassNewInput');
    if (passInput) passInput.value = this.generateStrongPassword();
  }

  generateStrongPassword() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    const bytes = crypto.getRandomValues(new Uint8Array(12));
    return 'Sa-' + Array.from(bytes, b => alphabet[b % alphabet.length]).join('') + '#7';
  }

  async handleSaveUserPasswordReset(e) {
    if (e) e.preventDefault();
    const userId = document.getElementById('resetPassUserId')?.value;
    const newPassword = document.getElementById('resetPassNewInput')?.value;
    if (!userId || !newPassword) return;

    try {
      const res = await fetch('/api/platform/user/reset-password', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, newPassword })
      });
      const data = await res.json();
      if (data && data.success) {
        this.closeUserPasswordResetModal();
        this.showToast(`Password updated! User can now sign in with the new passcode.`, '🔑');
      } else {
        this.showToast(`Note: ${data?.error || 'Failed to update'}`, '⚠️');
      }
    } catch (err) {
      this.closeUserPasswordResetModal();
      this.showToast('Password reset failed. No credential change was confirmed.', '❌', 'danger');
    }
  }

  filterUsersByRole(role) {
    this.userFilter = role;
    document.querySelectorAll('.user-filter-btn').forEach(b => {
      b.classList.toggle('active', b.dataset.userFilter === role);
    });
    this.renderUsersTable();
  }

  filterUsersByStatus(status) {
    this.userStatusFilter = status;
    this.renderUsersTable();
  }

  handleUserSearch(query) {
    this.userSearch = query.trim().toLowerCase();
    const btn = document.getElementById('btnClearUserSearch');
    if (btn) btn.style.display = this.userSearch ? 'flex' : 'none';
    this.renderUsersTable();
  }

  clearUserSearch() {
    this.userSearch = '';
    const input = document.getElementById('searchUsersInput');
    if (input) input.value = '';
    const btn = document.getElementById('btnClearUserSearch');
    if (btn) btn.style.display = 'none';
    this.renderUsersTable();
  }

  openUserModal(userId = null) {
    const modal = document.getElementById('userModal');
    const title = document.getElementById('userModalTitle');
    const idInput = document.getElementById('usrId');
    const nameInput = document.getElementById('usrName');
    const emailInput = document.getElementById('usrEmail');
    const phoneInput = document.getElementById('usrPhone');
    const roleInput = document.getElementById('usrRole');
    const tenantSelect = document.getElementById('usrTenantId');
    const statusInput = document.getElementById('usrStatus');

    if (!modal) return;

    if (tenantSelect) {
      tenantSelect.innerHTML = (this.tenants || []).map(t => `
        <option value="${this.escapeHtml(t.id || t.tenantId)}">${this.escapeHtml(t.firmName || t.name || t.id)}</option>
      `).join('');
    }

    if (userId) {
      const u = (this.users || []).find(x => x.id === userId || x.uid === userId);
      if (u) {
        if (title) title.textContent = 'Edit Platform User & Role';
        if (idInput) idInput.value = u.id || u.uid;
        if (nameInput) nameInput.value = u.name;
        if (emailInput) emailInput.value = u.email;
        if (phoneInput) phoneInput.value = u.phone || '';
        const uiRole = { salesman: 'sales_person', delivery: 'delivery_agent', distributor: 'owner' }[u.role] || u.role || 'sales_person';
        if (roleInput) roleInput.value = uiRole;
        if (tenantSelect) tenantSelect.value = u.tenantId || (this.tenants[0]?.id || '');
        if (statusInput) statusInput.value = u.status || 'active';
        const pwdRow = document.getElementById('usrPasswordRow');
        if (pwdRow) pwdRow.style.display = 'none';
      }
    } else {
      if (title) title.textContent = 'Add New Platform User';
      if (idInput) idInput.value = '';
      if (nameInput) nameInput.value = '';
      if (emailInput) emailInput.value = '';
      if (phoneInput) phoneInput.value = '+91 ';
      if (roleInput) roleInput.value = 'sales_person';
      if (tenantSelect && this.tenants.length > 0) tenantSelect.value = this.tenants[0].id || this.tenants[0].tenantId;
      if (statusInput) statusInput.value = 'active';
      const pwdRow = document.getElementById('usrPasswordRow');
      const pwdInput = document.getElementById('usrPassword');
      if (pwdInput) pwdInput.value = '';
      if (pwdRow) pwdRow.style.display = 'grid';
    }

    modal.classList.add('active');
  }

  closeUserModal() {
    document.getElementById('userModal')?.classList.remove('active');
  }

  async handleSaveUser(e) {
    if (e) e.preventDefault();
    const id = document.getElementById('usrId')?.value;
    const name = document.getElementById('usrName')?.value.trim();
    const email = document.getElementById('usrEmail')?.value.trim();
    const phone = document.getElementById('usrPhone')?.value.trim();
    const password = document.getElementById('usrPassword')?.value || '';
    const role = document.getElementById('usrRole')?.value;
    const tenantId = document.getElementById('usrTenantId')?.value;
    const status = document.getElementById('usrStatus')?.value || 'active';

    if (!name || !email) {
      this.showToast('Please enter both name and email.', '⚠️', 'warning');
      return;
    }
    if (role !== 'super_admin' && !tenantId) {
      this.showToast('Select the agency this user belongs to.', '⚠️', 'warning');
      return;
    }

    let ok;
    if (id) {
      ok = await this.apiMutate('/api/platform/sync-user', {
        id, name, email, phone, role, status,
        tenantId: role === 'super_admin' ? null : tenantId,
      });
    } else {
      if (password.length < 8) {
        this.showToast('Set an initial password of at least 8 characters.', '⚠️', 'warning');
        return;
      }
      ok = await this.apiMutate('/api/auth/signup', {
        accountType: 'staff', name, email, password, phone, role,
        tenantId: role === 'super_admin' ? null : tenantId,
      });
    }
    if (!ok) return;

    this.closeUserModal();
    await this.fetchPlatformState(true);
    this.showToast(`User "${name}" ${id ? 'updated' : 'created'}. They can sign in on the mobile app.`, '👤');
  }

  async toggleUserStatus(userId) {
    const user = (this.users || []).find(u => u.id === userId || u.uid === userId);
    if (!user) return;
    const next = user.status === 'active' ? 'suspended' : 'active';
    if (next === 'suspended' && !confirm(`Suspend "${user.name}"? They will be signed out and blocked from logging in.`)) return;
    const ok = await this.apiMutate('/api/platform/sync-user', { id: user.id, status: next });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`User "${user.name}" is now ${next.toUpperCase()}.`, next === 'active' ? '✓' : '⚠️');
  }

  async deleteUser(userId) {
    const user = (this.users || []).find(u => u.id === userId || u.uid === userId);
    if (!user) return;
    if (!confirm(`Permanently delete "${user.name}" (${user.email})? Their login is removed and cannot be restored.`)) return;
    const ok = await this.apiMutate(`/api/platform/user/${encodeURIComponent(userId)}`, null, { method: 'DELETE' });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`User "${user.name}" deleted.`, '🗑️');
  }

  renderAll() {
    this.renderStats();
    this.renderDashboardOverview();
    this.renderCouponsTable();
    this.renderRecentOrdersTable();
    this.renderPrintersTable();
    this.renderOrdersView();
    this.renderTenantsTable();
    this.renderPlansGrid();
    this.renderPrintersGrid();
    this.renderAddonsGrid();
    this.renderSyncPills();
    this.renderRemoteAppControl();
    this.renderBroadcastCenter();
    this.renderNotificationsTable();
    this.renderUsersTable();
    this.renderPlatformSettings();
    this.renderGatewaySettings();
    this.renderAuditLogs();
  }

  // ==============================================
  // EXECUTIVE DASHBOARD: INTERACTIVE CHARTS & INSIGHTS
  // ==============================================
  initDashboardState() {
    if (!this.dashTimeWindow) this.dashTimeWindow = 'all';
    if (!this.dashTenantFilter) this.dashTenantFilter = 'all';
    if (!this.chartMetric) this.chartMetric = 'revenue';
    if (!this.dashActivityTab) this.dashActivityTab = 'orders';
    if (!this.charts) this.charts = {};
  }

  updateActiveFilterNotice() {
    const notice = document.getElementById('dashActiveFilterNotice');
    const textEl = document.getElementById('dashActiveFilterText');
    if (!notice || !textEl) return;
    
    const isFilteredTenant = this.dashTenantFilter && this.dashTenantFilter !== 'all';
    const isFilteredTime = this.dashTimeWindow && this.dashTimeWindow !== 'all';
    
    if (isFilteredTenant || isFilteredTime) {
      let label = 'Filter: ';
      if (isFilteredTenant) {
        const tenant = (this.tenants || []).find(t => (t.id || t.tenantId) === this.dashTenantFilter);
        label += `🏢 ${tenant ? (tenant.firmName || tenant.name) : 'Agency'}`;
      }
      if (isFilteredTime) {
        const timeMap = { 'today': 'Today', '7d': 'Last 7 Days', '30d': 'Last 30 Days' };
        label += (isFilteredTenant ? ' • ' : '') + `⏱️ ${timeMap[this.dashTimeWindow] || this.dashTimeWindow}`;
      }
      textEl.textContent = label;
      notice.style.display = 'inline-flex';
    } else {
      notice.style.display = 'none';
    }
  }

  resetDashboardFilters() {
    this.initDashboardState();
    this.dashTenantFilter = 'all';
    this.dashTimeWindow = 'all';
    const sel = document.getElementById('dashTenantFilter');
    if (sel) sel.value = 'all';
    const buttons = document.querySelectorAll('.dash-filter-btn[data-time]');
    buttons.forEach(b => b.classList.toggle('active', b.dataset.time === 'all'));
    this.updateActiveFilterNotice();
    this.renderDashboard();
    this.showToast('Reset dashboard view to all agencies & all-time.', '🔄');
  }

  setDashTimeWindow(window) {
    this.initDashboardState();
    this.dashTimeWindow = window;
    const buttons = document.querySelectorAll('.dash-filter-btn[data-time]');
    buttons.forEach(b => b.classList.toggle('active', b.dataset.time === window));
    this.updateActiveFilterNotice();
    this.renderDashboard();
  }

  onDashFilterChange() {
    this.initDashboardState();
    const sel = document.getElementById('dashTenantFilter');
    if (sel) {
      this.dashTenantFilter = sel.value;
      this.updateActiveFilterNotice();
      this.renderDashboard();
    }
  }

  setChartMetric(metric) {
    this.initDashboardState();
    this.chartMetric = metric;
    const btnRev = document.getElementById('btnChartMetricRev');
    const btnVol = document.getElementById('btnChartMetricVol');
    if (btnRev) btnRev.classList.toggle('active', metric === 'revenue');
    if (btnVol) btnVol.classList.toggle('active', metric === 'orders');
    this.renderChartRevenueTrajectory();
  }

  setDashActivityTab(tab) {
    this.initDashboardState();
    this.dashActivityTab = tab;
    const tabOrders = document.getElementById('tabBtnDashOrders');
    const tabHardware = document.getElementById('tabBtnDashHardware');
    const paneOrders = document.getElementById('dashActivityOrdersPane');
    const paneHardware = document.getElementById('dashActivityHardwarePane');

    if (tabOrders) tabOrders.classList.toggle('active', tab === 'orders');
    if (tabHardware) tabHardware.classList.toggle('active', tab === 'hardware');
    if (paneOrders) paneOrders.style.display = tab === 'orders' ? 'block' : 'none';
    if (paneHardware) paneHardware.style.display = tab === 'hardware' ? 'block' : 'none';
  }

  async refreshDashboard(forceSync = false) {
    this.initDashboardState();
    const icon = document.getElementById('iconDashSync');
    if (icon) icon.classList.add('spinning');

    try {
      await this.fetchPlatformState(forceSync);
      if (forceSync && this.supabaseClient) {
        await Promise.allSettled([
          this.fetchTenantsFromSupabase(),
          this.fetchOrdersFromSupabase(),
          this.fetchProfilesFromSupabase()
        ]);
      }
      this.renderDashboard();
      this.showToast('Dashboard insights updated with live data.', '✓');
    } catch (e) {
      console.warn('Dashboard refresh error:', e);
    } finally {
      if (icon) setTimeout(() => icon.classList.remove('spinning'), 600);
    }
  }

  getFilteredOrders() {
    this.initDashboardState();
    let orders = (this.retailOrders || []).slice();

    // 1. Tenant Filter
    if (this.dashTenantFilter && this.dashTenantFilter !== 'all') {
      orders = orders.filter(o => o.tenantId === this.dashTenantFilter || o.tenantName === this.dashTenantFilter);
    }

    // 2. Time Window Filter
    if (this.dashTimeWindow && this.dashTimeWindow !== 'all') {
      const now = new Date();
      let cutoff = new Date(0);
      if (this.dashTimeWindow === 'today') {
        cutoff = new Date(now.getFullYear(), now.getMonth(), now.getDate());
      } else if (this.dashTimeWindow === '7d') {
        cutoff = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
      } else if (this.dashTimeWindow === '30d') {
        cutoff = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);
      }
      orders = orders.filter(o => {
        const d = new Date(o.orderDate || o.createdAt || 0);
        return d >= cutoff;
      });
    }

    return orders;
  }

  renderDashboard() {
    this.initDashboardState();
    this.updateActiveFilterNotice();

    // Populate agency dropdown filter if options changed
    const selTenant = document.getElementById('dashTenantFilter');
    if (selTenant && selTenant.options.length <= 1) {
      const currentVal = this.dashTenantFilter;
      selTenant.innerHTML = '<option value="all">🏢 All Registered Agencies</option>';
      const tenants = this.tenants || [];
      tenants.forEach(t => {
        const opt = document.createElement('option');
        opt.value = t.id || t.tenantId;
        opt.textContent = `🏢 ${t.firmName || t.name || 'Agency'}`;
        selTenant.appendChild(opt);
      });
      selTenant.value = currentVal;
    }

    const filteredOrders = this.getFilteredOrders();
    const allOrders = this.retailOrders || [];
    const allTenants = this.tenants || [];
    const allUsers = this.users || [];
    const allPrinters = this.printerOrders || [];

    // Calculations
    const totalGMV = filteredOrders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    const deliveredOrders = filteredOrders.filter(o => (o.status || '').toLowerCase() === 'delivered');
    const deliveredGMV = deliveredOrders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    const pendingGMV = totalGMV - deliveredGMV;

    const totalOrdersCount = filteredOrders.length;
    const deliveredCount = deliveredOrders.length;
    const deliveryRate = totalOrdersCount > 0 ? Math.round((deliveredCount / totalOrdersCount) * 100) : 100;
    const aov = totalOrdersCount > 0 ? Math.round(totalGMV / totalOrdersCount) : 0;

    // Tenants & MRR calculations
    const activeTenants = allTenants.filter(t => (t.subscriptionStatus || '').toLowerCase() === 'active');
    const trialTenants = allTenants.filter(t => (t.subscriptionStatus || '').toLowerCase() === 'trial');
    // Est MRR based on plans (e.g. startup=399, grow=599, enterprise=899)
    const estMRR = activeTenants.reduce((sum, t) => {
      const p = (t.subscriptionPlanId || t.planName || '').toLowerCase();
      if (p.includes('enterprise') || p.includes('platinum')) return sum + 899;
      if (p.includes('grow') || p.includes('growth') || p.includes('gold')) return sum + 599;
      if (p.includes('startup') || p.includes('silver')) return sum + 399;
      return sum;
    }, 0);

    // Workforce calculations
    const salesReps = allUsers.filter(u => (u.role || '').toLowerCase() === 'salesman' || (u.role || '').toLowerCase() === 'sales_rep');
    const adminUsers = allUsers.filter(u => (u.role || '').toLowerCase().includes('admin'));

    // Hardware calculations
    const printerRevenue = allPrinters.reduce((sum, po) => sum + (Number(po.price || po.amount) || 0), 0);
    const fulfilledPrinters = allPrinters.filter(po => (po.status || '').toLowerCase() === 'fulfilled' || (po.status || '').toLowerCase() === 'shipped').length;

    // Update DOM Stats
    const elGMV = document.getElementById('statTotalGMV');
    const elDeliveredGMVTag = document.getElementById('statDeliveredGMVTag');
    const elMicroDeliveredGMV = document.getElementById('statMicroDeliveredGMV');
    const elMicroPendingGMV = document.getElementById('statMicroPendingGMV');

    const elOrders = document.getElementById('statTotalOrders');
    const elOrderRateTag = document.getElementById('statOrderRateTag');
    const elMicroAOV = document.getElementById('statMicroAOV');
    const elMicroDeliveredCount = document.getElementById('statMicroDeliveredCount');

    const elTenants = document.getElementById('statTotalTenants');
    const elMicroActiveTenants = document.getElementById('statMicroActiveTenants');
    const elMicroMRR = document.getElementById('statMicroMRR');

    const elUsers = document.getElementById('statTotalUsers');
    const elMicroSalesReps = document.getElementById('statMicroSalesReps');
    const elMicroAdmins = document.getElementById('statMicroAdmins');

    const elPrinters = document.getElementById('statPrinterOrders');
    const elMicroPrinterRev = document.getElementById('statMicroPrinterRev');
    const elMicroPrinterFulfilled = document.getElementById('statMicroPrinterFulfilled');

    const elBadgeOrders = document.getElementById('badgeRetailOrdersCount');
    const elBadgePrinters = document.getElementById('badgePrinterOrdersCount');
    const elBadgeTenants = document.getElementById('badgeTenantsCount');
    const elBadgeUsers = document.getElementById('badgeUsersCount');

    if (elGMV) elGMV.textContent = `₹${totalGMV.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
    if (elDeliveredGMVTag) elDeliveredGMVTag.textContent = `● ₹${deliveredGMV.toLocaleString('en-IN', { maximumFractionDigits: 0 })} Invoiced`;
    if (elMicroDeliveredGMV) elMicroDeliveredGMV.textContent = `₹${deliveredGMV.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
    if (elMicroPendingGMV) elMicroPendingGMV.textContent = `₹${pendingGMV.toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;

    if (elOrders) elOrders.textContent = totalOrdersCount;
    if (elOrderRateTag) elOrderRateTag.textContent = `● ${deliveryRate}% Rate`;
    if (elMicroAOV) elMicroAOV.textContent = `₹${aov.toLocaleString('en-IN')}`;
    if (elMicroDeliveredCount) elMicroDeliveredCount.textContent = deliveredCount;

    if (elTenants) elTenants.textContent = allTenants.length;
    if (elMicroActiveTenants) elMicroActiveTenants.textContent = `${activeTenants.length} Active / ${trialTenants.length} Trial`;
    if (elMicroMRR) elMicroMRR.textContent = `₹${estMRR.toLocaleString('en-IN')}/mo`;

    if (elUsers) elUsers.textContent = allUsers.length;
    if (elMicroSalesReps) elMicroSalesReps.textContent = salesReps.length;
    if (elMicroAdmins) elMicroAdmins.textContent = adminUsers.length;

    if (elPrinters) elPrinters.textContent = allPrinters.length;
    if (elMicroPrinterRev) elMicroPrinterRev.textContent = `₹${printerRevenue.toLocaleString('en-IN')}`;
    if (elMicroPrinterFulfilled) elMicroPrinterFulfilled.textContent = fulfilledPrinters;

    // Card 6: SaaS Platform MRR
    const elPlatformMRR = document.getElementById('statPlatformMRR');
    const elMicroPaidAgencies = document.getElementById('statMicroPaidAgencies');
    const elMicroFreeAgencies = document.getElementById('statMicroFreeAgencies');
    if (elPlatformMRR) elPlatformMRR.textContent = `₹${estMRR.toLocaleString('en-IN')}/mo`;
    if (elMicroPaidAgencies) elMicroPaidAgencies.textContent = activeTenants.length;
    if (elMicroFreeAgencies) elMicroFreeAgencies.textContent = Math.max(0, allTenants.length - activeTenants.length);

    if (elBadgeOrders) elBadgeOrders.textContent = allOrders.length;
    if (elBadgePrinters) elBadgePrinters.textContent = allPrinters.length;
    if (elBadgeTenants) elBadgeTenants.textContent = allTenants.length;
    if (elBadgeUsers) elBadgeUsers.textContent = allUsers.length;

    const elTabOrdersCount = document.getElementById('dashTabOrdersCount');
    if (elTabOrdersCount) elTabOrdersCount.textContent = filteredOrders.length;
    const elTabPrintersCount = document.getElementById('dashTabPrintersCount');
    if (elTabPrintersCount) elTabPrintersCount.textContent = allPrinters.length;

    // Render Recent Activity Tables
    this.renderRecentOrdersOnDashboard(filteredOrders);
    this.renderRecentOrdersTable();

    // Render All Charts
    this.renderDashboardCharts();

    // Overview section at the top (users, revenue, agency cards, orders)
    this.renderDashboardOverview();
  }

  // ==============================================
  // DASHBOARD OVERVIEW (client spec §1)
  // ==============================================
  formatRupees(n) {
    return '₹' + Number(n || 0).toLocaleString('en-IN', { minimumFractionDigits: 0, maximumFractionDigits: 2 });
  }

  renderDashboardOverview() {
    const tenants = this.tenants || [];
    const statusOf = t => String(t.subscriptionStatus || '').toLowerCase();
    const setText = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
    setText('ovRegistered', tenants.length);
    setText('ovTrial', tenants.filter(t => statusOf(t) === 'trial').length);
    setText('ovUnregistered', tenants.filter(t => statusOf(t) === 'expired').length);

    // Client spec §1 metrics. Paid = on an active plan; Unpaid = trial or expired.
    const since = Date.now() - 30 * 86400000;
    const recent = tenants.filter(t => new Date(t.createdAt || 0).getTime() >= since);
    setText('ovRecentSignups', recent.length);
    setText('ovPaidSubscribers', tenants.filter(t => statusOf(t) === 'active').length);
    setText('ovUnpaidSubscribers', tenants.filter(t => ['trial', 'expired'].includes(statusOf(t))).length);
    setText('ovTotalHardwareOrders', (this.printerOrders || []).length);
    this.renderRecentSignupsTable();

    // Agency cards: Unique ID + name
    const cards = document.getElementById('ovAgencyCards');
    if (cards) {
      cards.innerHTML = tenants.length ? tenants.map(t => `
        <div style="border: 1px solid var(--border-color, #E2E8F0); border-radius: 12px; padding: 12px 14px;">
          <div style="font-weight: 700; color: var(--text-main);">${this.escapeHtml(t.firmName || t.name || 'Agency')}</div>
          <div style="font-size: 11px; color: var(--text-muted); font-family: var(--font-mono, monospace); word-break: break-all; margin-top: 4px;">ID: ${this.escapeHtml(t.id || t.tenantId)}</div>
        </div>`).join('')
        : '<div style="color: var(--text-muted); padding: 8px 0;">No registered users yet</div>';
    }

    // User (agency) filter for orders — rebuilt each time, keeps the selection
    const sel = document.getElementById('ovOrderUserFilter');
    if (sel) {
      const current = this.ovUserFilter || 'all';
      sel.innerHTML = '<option value="all">All Users</option>' + tenants.map(t =>
        `<option value="${this.escapeHtml(t.id || t.tenantId)}">${this.escapeHtml(t.firmName || t.name || 'Agency')}</option>`).join('');
      sel.value = tenants.some(t => (t.id || t.tenantId) === current) ? current : 'all';
      this.ovUserFilter = sel.value;
    }

    this.loadOverviewRevenue();
    this.renderOverviewOrders();
  }

  // Newest subscribers first (client spec §1 "Recent Signup").
  renderRecentSignupsTable() {
    const tbody = document.getElementById('dashRecentSignupsTableBody');
    if (!tbody) return;
    const esc = v => this.escapeHtml(v);
    const list = [...(this.tenants || [])]
      .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))
      .slice(0, 10);
    if (!list.length) {
      tbody.innerHTML = '<tr><td colspan="9" style="text-align:center; padding: 24px; color: var(--text-muted);">No subscribers yet</td></tr>';
      return;
    }
    tbody.innerHTML = list.map(t => {
      const isSuspended = t.isSuspended === true || t.subscriptionStatus === 'suspended';
      const badge = this._getTenantStatusBadge(t.subscriptionStatus, isSuspended);
      const d = t.createdAt ? new Date(t.createdAt) : null;
      return `
        <tr>
          <td><span class="code-pill" style="font-size: 11px;">${esc(t.id)}</span></td>
          <td><strong>${esc(t.firmName || t.name || 'Agency')}</strong></td>
          <td>${esc(t.ownerName || '—')}</td>
          <td>${esc(t.phone || '—')}</td>
          <td>${esc([t.city, t.state].filter(Boolean).join(', ') || '—')}</td>
          <td>${esc(t.planName || '—')}</td>
          <td><span class="badge ${badge.class}">${esc(badge.label)}</span></td>
          <td>${esc(d && !isNaN(d) ? d.toLocaleDateString('en-IN') : '—')}</td>
          <td><button class="btn btn-outline btn-sm" onclick="adminApp.openTenantDetailModal('${this.escapeJs(t.id)}')">View</button></td>
        </tr>`;
    }).join('');
  }

  // Dashboard "Download Report": subscribers + key totals, PDF or Excel.
  async downloadFullPlatformReport(format = 'pdf') {
    try {
      let rev = {};
      try {
        const res = await fetch('/api/platform/revenue-summary', { headers: this.getAuthHeaders() });
        const j = await res.json();
        if (j.success) rev = j;
      } catch (_) { /* totals fall back to 0 */ }
      const tenants = this.tenants || [];
      const statusOf = t => String(t.subscriptionStatus || '').toLowerCase();
      const since = Date.now() - 30 * 86400000;
      const n = v => Number(v || 0).toLocaleString('en-IN', { maximumFractionDigits: 2 });
      const day = v => { const d = v ? new Date(v) : null; return d && !isNaN(d) ? d.toISOString().slice(0, 10) : ''; };
      const summary = [
        `Recent signups (30 days): ${tenants.filter(t => new Date(t.createdAt || 0).getTime() >= since).length}`,
        `Paid subscribers: ${tenants.filter(t => statusOf(t) === 'active').length}`,
        `Unpaid subscribers: ${tenants.filter(t => ['trial', 'expired'].includes(statusOf(t))).length}`,
        `Total orders: ${(this.printerOrders || []).length}`,
        `Total revenue: Rs ${n(rev.totalRevenue)} (subscriptions Rs ${n(rev.planRevenue)}, hardware Rs ${n(rev.hardwareRevenue)})`,
      ].join('  •  ');
      const report = {
        agency: 'SalesArmy Platform',
        title: `Subscribers Report — ${summary}`,
        columns: [
          ['id', 'Subscriber ID'], ['agency', 'Agency'], ['owner', 'Owner'], ['phone', 'Phone'], ['city', 'City'],
          ['state', 'State'], ['plan', 'Plan'], ['status', 'Status'], ['signedUp', 'Signed Up'], ['expiry', 'Plan Expiry'],
        ].map(([key, label]) => ({ key, label })),
        rows: [...tenants]
          .sort((a, b) => new Date(b.createdAt || 0) - new Date(a.createdAt || 0))
          .map(t => ({
            id: t.id, agency: t.firmName || t.name || '', owner: t.ownerName || '', phone: t.phone || '',
            city: t.city || '', state: t.state || '', plan: t.planName || '', status: this.formatRoleLabel(t.subscriptionStatus || ''),
            signedUp: day(t.createdAt), expiry: t.expiryDate || '',
          })),
      };
      const fileBase = `SalesArmy_Platform_Report_${new Date().toISOString().slice(0, 10)}`;
      if (format === 'excel') await this.writeReportExcel(report, fileBase);
      else await this.writeReportPdf(report, fileBase);
      this.showToast(`Platform report downloaded (${report.rows.length} subscribers).`, '📥');
    } catch (err) {
      console.warn('Platform report error:', err);
      this.showToast(`Report download failed: ${err.message}`, '⚠️', 'warning');
    }
  }

  async loadOverviewRevenue() {
    if (this._ovRevenueInFlight || !this.hasSession()) return;
    this._ovRevenueInFlight = true;
    try {
      const res = await fetch('/api/platform/revenue-summary', { headers: this.getAuthHeaders() });
      const j = await res.json();
      if (!j.success) return;
      const setText = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
      setText('ovTotalRevenue', this.formatRupees(j.totalRevenue));
      setText('ovPlanRevenue', this.formatRupees(j.planRevenue));
      setText('ovHardwareRevenue', this.formatRupees(j.hardwareRevenue));
      this.ovPaidSubscriptions = j.subscriptions || [];
      this.renderOverviewOrders();
    } catch (err) {
      console.warn('Revenue summary error:', err);
    } finally {
      this._ovRevenueInFlight = false;
    }
  }

  onOverviewUserFilterChange() {
    const sel = document.getElementById('ovOrderUserFilter');
    this.ovUserFilter = sel ? sel.value : 'all';
    this.renderOverviewOrders();
  }

  // Orders received by SalesArmy: paid subscriptions + hardware/printer/paper-roll orders.
  renderOverviewOrders() {
    const userId = this.ovUserFilter || 'all';
    const names = Object.fromEntries((this.tenants || []).map(t => [t.id || t.tenantId, t.firmName || t.name]));
    const subs = (this.ovPaidSubscriptions || []).map(s => ({
      ref: s.id, date: s.paidAt, tenantId: s.tenantId, agency: names[s.tenantId] || s.tenantId,
      type: 'Subscription', item: s.planName, amount: s.amount, payment: 'paid', status: '—',
    }));
    const hw = (this.printerOrders || []).map(o => ({
      ref: o.orderId || o.id, date: o.orderedAt, tenantId: o.tenantId, agency: o.agencyName || names[o.tenantId] || o.tenantId,
      type: 'Hardware', item: o.printerItem, amount: o.price, payment: o.paymentStatus, status: o.status,
    }));
    let rows = subs.concat(hw);
    if (userId !== 'all') rows = rows.filter(r => r.tenantId === userId);
    rows.sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));

    const tbody = document.getElementById('ovOrdersTableBody');
    if (!tbody) return;
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align:center; padding: 24px; color: var(--text-muted);">No orders found</td></tr>';
      return;
    }
    const cap = v => { const s = String(v || ''); return s ? s.charAt(0).toUpperCase() + s.slice(1) : '—'; };
    tbody.innerHTML = rows.map(r => {
      const d = r.date ? new Date(r.date) : null;
      const date = d && !isNaN(d) ? d.toLocaleDateString('en-IN') : '—';
      return `
        <tr>
          <td><strong style="font-family: var(--font-mono, monospace); font-size: 12px;">${this.escapeHtml(r.ref)}</strong></td>
          <td>${this.escapeHtml(date)}</td>
          <td>${this.escapeHtml(r.agency || '')}</td>
          <td>${this.escapeHtml(r.type)}</td>
          <td>${this.escapeHtml(r.item || '')}</td>
          <td><strong>${this.escapeHtml(this.formatRupees(r.amount))}</strong></td>
          <td>${this.escapeHtml(cap(r.payment))}</td>
          <td>${this.escapeHtml(cap(r.status))}</td>
        </tr>`;
    }).join('');
  }

  renderRecentOrdersOnDashboard(orders) {
    const tbody = document.getElementById('dashRecentOrdersTableBody');
    if (!tbody) return;

    if (!orders || orders.length === 0) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 28px; color: var(--text-muted);">No retail orders matching selected filters</td></tr>';
      return;
    }

    const recent = orders.slice(0, 8);
    tbody.innerHTML = recent.map(o => {
      const status = (o.status || 'Confirmed').toLowerCase();
      let badgeClass = 'badge-indigo';
      if (status === 'delivered') badgeClass = 'badge-emerald';
      else if (status === 'processing') badgeClass = 'badge-amber';
      else if (status === 'cancelled') badgeClass = 'badge-rose';

      const amount = Number(o.grandTotal || 0).toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
      const payStatus = o.paymentStatus || 'Not billed';
      const resolvedName = this.resolveShopName(o.shopId, o.shopName);

      return `
        <tr>
          <td><strong style="font-family: var(--font-mono, monospace); font-size: 12px;">${this.escapeHtml(o.orderNumber || o.orderId || o.id)}</strong></td>
          <td>
            <div style="font-weight: 700; color: var(--text-main);">${this.escapeHtml(resolvedName)}</div>
            <div style="font-size: 11px; color: var(--text-muted);">${o.salesmanName ? 'Rep: ' + this.escapeHtml(o.salesmanName) : ''}</div>
          </td>
          <td><span style="font-size: 12px; font-weight: 600;">${this.escapeHtml(o.tenantName || 'Agency')}</span></td>
          <td><strong style="color: var(--text-main);">₹${amount}</strong></td>
          <td>
            <span style="font-size: 11px; font-weight: 600; color: ${payStatus === 'Paid' ? 'var(--emerald-text)' : 'var(--amber-text)'};">
              ● ${this.escapeHtml(payStatus)}
            </span>
          </td>
          <td><span class="badge ${badgeClass}">${this.escapeHtml((o.status || 'Confirmed').toUpperCase())}</span></td>
          <td>
            <button class="btn btn-outline btn-xs" onclick="adminApp.openOrderDetailModal('${this.escapeJs(o.id || o.orderId)}')">
              <span>View</span>
            </button>
          </td>
        </tr>
      `;
    }).join('');
  }

  renderDashboardCharts() {
    const chartIds = ['chartRevenueTrajectory', 'chartFulfillmentStatus', 'chartTopShops', 'chartPlanDistribution'];

    // Clean up any previously installed fallback notices and ensure canvases are visible
    chartIds.forEach(id => {
      const el = document.getElementById(id);
      if (!el) return;
      el.style.display = 'block';
      const parent = el.parentElement;
      if (parent) {
        const fallbacks = parent.querySelectorAll('.chart-fallback-message');
        fallbacks.forEach(fb => fb.remove());
        delete parent.dataset.chartFallbackInstalled;
      }
    });

    if (typeof Chart !== 'undefined') {
      this.renderChartRevenueTrajectory();
      this.renderChartFulfillmentStatus();
      this.renderChartTopShops();
      this.renderChartPlanDistribution();
      return;
    }

    // If Chart is still loading asynchronously, retry up to 5 times (total ~1.8s)
    if (!this._chartRetryCount) this._chartRetryCount = 0;
    if (this._chartRetryCount < 5) {
      this._chartRetryCount++;
      setTimeout(() => this.renderDashboardCharts(), 350);
      return;
    }

    // Native HTML5 Canvas 2D Fallback: guarantees live charts always render
    // even if CDN or offline environment has blocked Chart.js
    this.renderNativeCanvasFallbackCharts();
  }

  renderNativeCanvasFallbackCharts() {
    this.renderNativeRevenueTrajectory();
    this.renderNativeFulfillmentStatus();
    this.renderNativeTopShops();
    this.renderNativePlanDistribution();
  }

  _setupNativeCanvas(canvas, targetHeight = 240) {
    if (!canvas) return null;
    const parent = canvas.parentElement;
    const width = (parent ? parent.clientWidth : 0) || canvas.clientWidth || 500;
    const height = targetHeight;
    const dpr = window.devicePixelRatio || 1;
    canvas.width = Math.floor(width * dpr);
    canvas.height = Math.floor(height * dpr);
    canvas.style.width = width + 'px';
    canvas.style.height = height + 'px';
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    return { ctx, width, height, dpr };
  }

  resolveShopName(shopId, rawName) {
    // Names come from the shops table via the API; never substitute aliases.
    return (rawName || '').trim() || shopId || 'Retail outlet';
  }

  renderNativeRevenueTrajectory() {
    const canvas = document.getElementById('chartRevenueTrajectory');
    if (!canvas) return;
    const setup = this._setupNativeCanvas(canvas, 240);
    if (!setup) return;
    const { ctx, width, height } = setup;
    const theme = this.getChartThemeColors();
    const orders = this.getFilteredOrders();
    const isRevenue = this.chartMetric !== 'orders';

    const dateMap = {};
    const now = new Date();
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      const key = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      dateMap[key] = { revenue: 0, orders: 0 };
    }
    orders.forEach(o => {
      const d = new Date(o.orderDate || o.createdAt || now);
      const key = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      if (!dateMap[key]) dateMap[key] = { revenue: 0, orders: 0 };
      dateMap[key].revenue += Number(o.grandTotal) || 0;
      dateMap[key].orders += 1;
    });

    const labels = Object.keys(dateMap);
    const data = labels.map(k => isRevenue ? dateMap[k].revenue : dateMap[k].orders);
    const maxVal = Math.max(...data, isRevenue ? 1000 : 5);

    // Update summary metrics
    const periodTotal = orders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    let peakKey = '—';
    let peakVal = 0;
    labels.forEach(k => {
      const v = isRevenue ? dateMap[k].revenue : dateMap[k].orders;
      if (v > peakVal) { peakVal = v; peakKey = k; }
    });
    const dailyAvg = labels.length > 0 ? (periodTotal / labels.length) : 0;
    const activeCount = orders.length;

    const elPeriodTotal = document.getElementById('chartTrajPeriodTotal');
    if (elPeriodTotal) elPeriodTotal.textContent = '₹' + periodTotal.toLocaleString('en-IN', { maximumFractionDigits: 2 });
    const elPeakDay = document.getElementById('chartTrajPeakDay');
    if (elPeakDay) elPeakDay.textContent = peakVal > 0 ? `${peakKey} (${isRevenue ? '₹' + peakVal.toLocaleString('en-IN') : peakVal + ' orders'})` : '—';
    const elDailyAvg = document.getElementById('chartTrajDailyAvg');
    if (elDailyAvg) elDailyAvg.textContent = '₹' + Math.round(dailyAvg).toLocaleString('en-IN');
    const elActiveCount = document.getElementById('chartTrajActiveCount');
    if (elActiveCount) elActiveCount.textContent = `${activeCount} ${activeCount === 1 ? 'order' : 'orders'}`;

    ctx.clearRect(0, 0, width, height);

    const paddingLeft = 55;
    const paddingRight = 20;
    const paddingTop = 25;
    const paddingBottom = 35;
    const chartW = width - paddingLeft - paddingRight;
    const chartH = height - paddingTop - paddingBottom;

    // Grid lines & Y-axis labels
    ctx.strokeStyle = theme.gridColor;
    ctx.lineWidth = 1;
    ctx.font = '11px sans-serif';
    ctx.fillStyle = theme.mutedColor;
    ctx.textAlign = 'right';
    ctx.textBaseline = 'middle';

    const gridSteps = 4;
    for (let i = 0; i <= gridSteps; i++) {
      const y = paddingTop + (chartH / gridSteps) * i;
      const val = Math.round(maxVal - (maxVal / gridSteps) * i);
      const label = isRevenue ? ('₹' + (val >= 1000 ? (val / 1000).toFixed(1) + 'k' : val)) : val;
      ctx.fillText(label, paddingLeft - 8, y);
      ctx.beginPath();
      ctx.moveTo(paddingLeft, y);
      ctx.lineTo(width - paddingRight, y);
      ctx.stroke();
    }

    const points = data.map((v, i) => {
      const x = paddingLeft + (chartW / (labels.length - 1 || 1)) * i;
      const y = paddingTop + chartH - (v / (maxVal || 1)) * chartH;
      return { x, y, v, label: labels[i] };
    });

    // Fill area gradient
    const primaryColor = isRevenue ? '#10B981' : '#3B82F6';
    const grad = ctx.createLinearGradient(0, paddingTop, 0, height - paddingBottom);
    grad.addColorStop(0, isRevenue ? 'rgba(16, 185, 129, 0.32)' : 'rgba(59, 130, 246, 0.32)');
    grad.addColorStop(1, isRevenue ? 'rgba(16, 185, 129, 0.0)' : 'rgba(59, 130, 246, 0.0)');

    ctx.beginPath();
    ctx.moveTo(points[0].x, height - paddingBottom);
    points.forEach(p => ctx.lineTo(p.x, p.y));
    ctx.lineTo(points[points.length - 1].x, height - paddingBottom);
    ctx.closePath();
    ctx.fillStyle = grad;
    ctx.fill();

    // Line stroke
    ctx.beginPath();
    points.forEach((p, idx) => {
      if (idx === 0) ctx.moveTo(p.x, p.y);
      else ctx.lineTo(p.x, p.y);
    });
    ctx.strokeStyle = primaryColor;
    ctx.lineWidth = 2.5;
    ctx.stroke();

    // Dots and labels
    ctx.textAlign = 'center';
    ctx.textBaseline = 'top';
    points.forEach(p => {
      ctx.fillStyle = theme.mutedColor;
      ctx.fillText(p.label, p.x, height - paddingBottom + 8);

      ctx.beginPath();
      ctx.arc(p.x, p.y, 4, 0, Math.PI * 2);
      ctx.fillStyle = theme.cardBg;
      ctx.fill();
      ctx.lineWidth = 2;
      ctx.strokeStyle = primaryColor;
      ctx.stroke();

      if (p.v > 0) {
        ctx.fillStyle = theme.textColor;
        ctx.font = 'bold 10px sans-serif';
        const valText = isRevenue ? '₹' + p.v.toLocaleString('en-IN') : p.v;
        ctx.fillText(valText, p.x, p.y - 14);
        ctx.font = '11px sans-serif';
      }
    });
  }

  renderNativeFulfillmentStatus() {
    const canvas = document.getElementById('chartFulfillmentStatus');
    if (!canvas) return;
    const setup = this._setupNativeCanvas(canvas, 220);
    if (!setup) return;
    const { ctx, width, height } = setup;
    const theme = this.getChartThemeColors();
    const orders = this.getFilteredOrders();

    let delivered = 0, processing = 0, dispatched = 0, cancelled = 0;
    orders.forEach(o => {
      const s = (o.status || 'confirmed').toLowerCase();
      if (s === 'delivered' || s === 'completed') delivered++;
      else if (s === 'processing' || s === 'confirmed') processing++;
      else if (s === 'dispatched' || s === 'in-transit') dispatched++;
      else if (s === 'cancelled' || s === 'returned') cancelled++;
      else processing++;
    });

    const total = orders.length;
    const donutVal = document.getElementById('donutTotalOrdersVal');
    if (donutVal) donutVal.textContent = total;
    const badgeRate = document.getElementById('badgeDeliveryRate');
    if (badgeRate) {
      const rate = total > 0 ? Math.round((delivered / total) * 100) : 0;
      badgeRate.textContent = total > 0 ? (rate + '% Delivered') : '0 Booked';
    }

    const elDelivered = document.getElementById('donutBreakdownDelivered');
    if (elDelivered) elDelivered.textContent = `${delivered} (${total > 0 ? Math.round((delivered / total) * 100) : 0}%)`;
    const elProcessing = document.getElementById('donutBreakdownProcessing');
    if (elProcessing) elProcessing.textContent = `${processing} (${total > 0 ? Math.round((processing / total) * 100) : 0}%)`;
    const elDispatched = document.getElementById('donutBreakdownDispatched');
    if (elDispatched) elDispatched.textContent = `${dispatched} (${total > 0 ? Math.round((dispatched / total) * 100) : 0}%)`;
    const elCancelled = document.getElementById('donutBreakdownCancelled');
    if (elCancelled) elCancelled.textContent = `${cancelled} (${total > 0 ? Math.round((cancelled / total) * 100) : 0}%)`;

    ctx.clearRect(0, 0, width, height);

    const slices = total > 0 ? [
      { label: 'Delivered', val: delivered, color: '#10B981' },
      { label: 'Processing', val: processing, color: '#F59E0B' },
      { label: 'Dispatched', val: dispatched, color: '#3B82F6' },
      { label: 'Cancelled', val: cancelled, color: '#F43F5E' },
    ] : [{ label: 'No Orders', val: 1, color: theme.isDark ? '#334155' : '#E2E8F0' }];

    const cx = width / 2;
    const cy = height / 2;
    const outerR = Math.min(cx, cy) - 20;
    const innerR = outerR * 0.65;
    const sliceTotal = slices.reduce((sum, s) => sum + s.val, 0) || 1;

    let startAngle = -Math.PI / 2;
    slices.forEach(s => {
      if (s.val <= 0) return;
      const angle = (s.val / sliceTotal) * Math.PI * 2;
      const endAngle = startAngle + angle;

      ctx.beginPath();
      ctx.arc(cx, cy, outerR, startAngle, endAngle);
      ctx.arc(cx, cy, innerR, endAngle, startAngle, true);
      ctx.closePath();
      ctx.fillStyle = s.color;
      ctx.fill();

      startAngle = endAngle;
    });

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = 'bold 22px sans-serif';
    ctx.fillStyle = theme.textColor;
    ctx.fillText(total, cx, cy - 6);
    ctx.font = '11px sans-serif';
    ctx.fillStyle = theme.mutedColor;
    ctx.fillText('Orders', cx, cy + 12);
  }

  renderNativeTopShops() {
    const canvas = document.getElementById('chartTopShops');
    if (!canvas) return;
    const setup = this._setupNativeCanvas(canvas, 240);
    if (!setup) return;
    const { ctx, width, height } = setup;
    const theme = this.getChartThemeColors();
    const orders = this.getFilteredOrders();

    const shopMap = {};
    orders.forEach(o => {
      const name = this.resolveShopName(o.shopId, o.shopName);
      if (!shopMap[name]) shopMap[name] = { name, revenue: 0, count: 0 };
      shopMap[name].revenue += Number(o.grandTotal) || 0;
      shopMap[name].count += 1;
    });

    const top = Object.values(shopMap)
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 5);

    const totalRetailGMV = orders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    const topGMV = top.reduce((sum, s) => sum + s.revenue, 0);
    const topPct = totalRetailGMV > 0 ? Math.round((topGMV / totalRetailGMV) * 100) : 100;
    const elContrib = document.getElementById('topShopsContributionPct');
    if (elContrib) elContrib.textContent = `${topPct}%`;

    ctx.clearRect(0, 0, width, height);

    if (!top.length) {
      ctx.textAlign = 'center';
      ctx.textBaseline = 'middle';
      ctx.fillStyle = theme.mutedColor;
      ctx.font = '13px sans-serif';
      ctx.fillText('No retail order data available yet', width / 2, height / 2);
      return;
    }

    const maxRev = top[0]?.revenue || 1;
    const barHeight = 22;
    const gap = 18;
    const startY = 20;
    const labelWidth = 160;
    const valueWidth = 85;
    const maxBarW = Math.max(50, width - labelWidth - valueWidth - 30);

    top.forEach((s, i) => {
      const y = startY + i * (barHeight + gap);
      const barW = Math.max(6, (s.revenue / maxRev) * maxBarW);

      ctx.textAlign = 'right';
      ctx.textBaseline = 'middle';
      ctx.font = '12px sans-serif';
      ctx.fillStyle = theme.textColor;
      const name = s.name.length > 20 ? s.name.substring(0, 18) + '...' : s.name;
      ctx.fillText(name, labelWidth - 12, y + barHeight / 2);

      ctx.fillStyle = theme.isDark ? '#1E293B' : '#F1F5F9';
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(labelWidth, y, maxBarW, barHeight, 6);
      else ctx.rect(labelWidth, y, maxBarW, barHeight);
      ctx.fill();

      const grad = ctx.createLinearGradient(labelWidth, 0, labelWidth + barW, 0);
      grad.addColorStop(0, '#3B82F6');
      grad.addColorStop(1, '#60A5FA');
      ctx.fillStyle = grad;
      ctx.beginPath();
      if (ctx.roundRect) ctx.roundRect(labelWidth, y, barW, barHeight, 6);
      else ctx.rect(labelWidth, y, barW, barHeight);
      ctx.fill();

      ctx.textAlign = 'left';
      ctx.fillStyle = theme.textColor;
      ctx.font = 'bold 11px sans-serif';
      ctx.fillText('₹' + s.revenue.toLocaleString('en-IN'), labelWidth + barW + 10, y + barHeight / 2);
    });
  }

  renderNativePlanDistribution() {
    const canvas = document.getElementById('chartPlanDistribution');
    if (!canvas) return;
    const setup = this._setupNativeCanvas(canvas, 240);
    if (!setup) return;
    const { ctx, width, height } = setup;
    const theme = this.getChartThemeColors();
    const tenants = this.tenants || [];

    let startup = 0, grow = 0, enterprise = 0, freemium = 0;
    tenants.forEach(t => {
      const plan = (t.subscriptionPlanId || t.planName || '').toLowerCase();
      const status = (t.subscriptionStatus || '').toLowerCase();
      if (status === 'expired') {
        freemium++; // "expired / read-only" bucket (there is no free plan)
      } else if (plan.includes('enterprise') || plan.includes('platinum')) {
        enterprise++;
      } else if (plan.includes('grow') || plan.includes('growth') || plan.includes('gold')) {
        grow++;
      } else if (plan.includes('startup') || plan.includes('silver')) {
        startup++;
      } else {
        startup++;
      }
    });

    const total = startup + grow + enterprise + freemium;

    // Update pill counters
    const elEnt = document.getElementById('pillEnterpriseCount');
    if (elEnt) elEnt.textContent = enterprise;
    const elGrow = document.getElementById('pillGrowCount');
    if (elGrow) elGrow.textContent = grow;
    const elStart = document.getElementById('pillStartupCount');
    if (elStart) elStart.textContent = startup;
    const elFree = document.getElementById('pillFreemiumCount');
    if (elFree) elFree.textContent = freemium;

    ctx.clearRect(0, 0, width, height);

    const slices = [
      { label: 'Enterprise', val: enterprise, color: '#10B981' },
      { label: 'Grow', val: grow, color: '#8B5CF6' },
      { label: 'Startup', val: startup, color: '#3B82F6' },
      { label: 'Expired', val: freemium, color: '#F59E0B' },
    ];

    const cx = width / 2;
    const cy = height / 2 - 15;
    const outerR = Math.min(cx, cy) - 20;
    const innerR = outerR * 0.65;
    const sliceTotal = slices.reduce((sum, s) => sum + s.val, 0) || 1;

    let startAngle = -Math.PI / 2;
    slices.forEach(s => {
      if (s.val <= 0) return;
      const angle = (s.val / sliceTotal) * Math.PI * 2;
      const endAngle = startAngle + angle;

      ctx.beginPath();
      ctx.arc(cx, cy, outerR, startAngle, endAngle);
      ctx.arc(cx, cy, innerR, endAngle, startAngle, true);
      ctx.closePath();
      ctx.fillStyle = s.color;
      ctx.fill();

      startAngle = endAngle;
    });

    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.font = 'bold 20px sans-serif';
    ctx.fillStyle = theme.textColor;
    ctx.fillText(total, cx, cy - 6);
    ctx.font = '11px sans-serif';
    ctx.fillStyle = theme.mutedColor;
    ctx.fillText('Agencies', cx, cy + 12);

    const legendY = height - 18;
    const legendW = width / slices.length;
    slices.forEach((s, i) => {
      const lx = legendW * i + legendW / 2;
      ctx.beginPath();
      ctx.arc(lx - 25, legendY, 4, 0, Math.PI * 2);
      ctx.fillStyle = s.color;
      ctx.fill();

      ctx.textAlign = 'left';
      ctx.font = '11px sans-serif';
      ctx.fillStyle = theme.mutedColor;
      ctx.fillText(s.label + ' (' + s.val + ')', lx - 17, legendY);
    });
  }

  getChartThemeColors() {
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    return {
      isDark,
      textColor: isDark ? '#E4E4E7' : '#18181B',
      mutedColor: isDark ? '#A1A1AA' : '#71717A',
      gridColor: isDark ? 'rgba(255, 255, 255, 0.08)' : 'rgba(0, 0, 0, 0.06)',
      cardBg: isDark ? '#111319' : '#FFFFFF',
      accentPrimary: '#3B82F6',
      accentEmerald: '#10B981',
      accentAmber: '#F59E0B',
      accentRose: '#F43F5E',
      accentPurple: '#8B5CF6'
    };
  }

  // CHART 1: REVENUE & ORDER TRAJECTORY
  renderChartRevenueTrajectory() {
    const canvas = document.getElementById('chartRevenueTrajectory');
    if (!canvas) return;
    if (typeof Chart === 'undefined') { this.renderNativeRevenueTrajectory(); return; }

    const theme = this.getChartThemeColors();
    const orders = this.getFilteredOrders();
    const isRevenue = this.chartMetric !== 'orders';

    // Group orders by date
    const dateMap = {};
    const now = new Date();
    // Default last 7 days keys
    for (let i = 6; i >= 0; i--) {
      const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
      const key = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      dateMap[key] = { revenue: 0, orders: 0 };
    }

    orders.forEach(o => {
      const d = new Date(o.orderDate || o.createdAt || now);
      const key = d.toLocaleDateString('en-IN', { month: 'short', day: 'numeric' });
      if (!dateMap[key]) dateMap[key] = { revenue: 0, orders: 0 };
      dateMap[key].revenue += Number(o.grandTotal) || 0;
      dateMap[key].orders += 1;
    });

    const labels = Object.keys(dateMap);
    const revenueData = labels.map(k => dateMap[k].revenue);
    const ordersData = labels.map(k => dateMap[k].orders);

    // Update trajectory summary metrics in DOM
    const periodTotal = orders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    let peakKey = '—';
    let peakVal = 0;
    labels.forEach(k => {
      const v = isRevenue ? dateMap[k].revenue : dateMap[k].orders;
      if (v > peakVal) { peakVal = v; peakKey = k; }
    });
    const dailyAvg = labels.length > 0 ? (periodTotal / labels.length) : 0;
    const activeCount = orders.length;

    const elPeriodTotal = document.getElementById('chartTrajPeriodTotal');
    if (elPeriodTotal) elPeriodTotal.textContent = '₹' + periodTotal.toLocaleString('en-IN', { maximumFractionDigits: 2 });
    const elPeakDay = document.getElementById('chartTrajPeakDay');
    if (elPeakDay) elPeakDay.textContent = peakVal > 0 ? `${peakKey} (${isRevenue ? '₹' + peakVal.toLocaleString('en-IN') : peakVal + ' orders'})` : '—';
    const elDailyAvg = document.getElementById('chartTrajDailyAvg');
    if (elDailyAvg) elDailyAvg.textContent = '₹' + Math.round(dailyAvg).toLocaleString('en-IN');
    const elActiveCount = document.getElementById('chartTrajActiveCount');
    if (elActiveCount) elActiveCount.textContent = `${activeCount} ${activeCount === 1 ? 'order' : 'orders'}`;

    if (this.charts.revenueTrajectory) {
      this.charts.revenueTrajectory.destroy();
    }

    const ctx = canvas.getContext('2d');
    
    // Create soft gradient
    const gradient = ctx.createLinearGradient(0, 0, 0, 240);
    if (isRevenue) {
      gradient.addColorStop(0, 'rgba(16, 185, 129, 0.28)');
      gradient.addColorStop(1, 'rgba(16, 185, 129, 0.00)');
    } else {
      gradient.addColorStop(0, 'rgba(59, 130, 246, 0.28)');
      gradient.addColorStop(1, 'rgba(59, 130, 246, 0.00)');
    }

    this.charts.revenueTrajectory = new Chart(canvas, {
      type: 'line',
      data: {
        labels: labels,
        datasets: [{
          label: isRevenue ? 'Gross Merchandise Value (₹)' : 'Order Volume (Units)',
          data: isRevenue ? revenueData : ordersData,
          borderColor: isRevenue ? theme.accentEmerald : theme.accentPrimary,
          backgroundColor: gradient,
          borderWidth: 2.5,
          tension: 0.38,
          fill: true,
          pointRadius: 4,
          pointHoverRadius: 6,
          pointBackgroundColor: isRevenue ? theme.accentEmerald : theme.accentPrimary,
          pointBorderColor: theme.cardBg,
          pointBorderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: theme.isDark ? '#1F2937' : '#FFFFFF',
            titleColor: theme.textColor,
            bodyColor: theme.textColor,
            borderColor: theme.gridColor,
            borderWidth: 1,
            padding: 11,
            boxPadding: 4,
            callbacks: {
              title: function(items) {
                return `📅 ${items[0].label}`;
              },
              label: function(context) {
                const key = labels[context.dataIndex];
                const rev = dateMap[key]?.revenue || 0;
                const cnt = dateMap[key]?.orders || 0;
                return [
                  ` 💰 GMV: ₹${Number(rev).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`,
                  ` 📦 Volume: ${cnt} ${cnt === 1 ? 'order' : 'orders'}`
                ];
              }
            }
          }
        },
        scales: {
          x: {
            grid: { color: theme.gridColor, drawBorder: false },
            ticks: { color: theme.mutedColor, font: { size: 11, family: 'Inter, sans-serif' } }
          },
          y: {
            grid: { color: theme.gridColor, drawBorder: false },
            ticks: {
              color: theme.mutedColor,
              font: { size: 11, family: 'Inter, sans-serif' },
              callback: function(val) {
                if (isRevenue) {
                  if (val >= 100000) return '₹' + (val / 100000).toFixed(1) + 'L';
                  if (val >= 1000) return '₹' + (val / 1000).toFixed(0) + 'k';
                  return '₹' + val;
                }
                return val;
              }
            }
          }
        }
      }
    });
  }

  // CHART 2: FULFILLMENT PIPELINE DONUT
  renderChartFulfillmentStatus() {
    const canvas = document.getElementById('chartFulfillmentStatus');
    if (!canvas) return;
    if (typeof Chart === 'undefined') { this.renderNativeFulfillmentStatus(); return; }

    const theme = this.getChartThemeColors();
    const orders = this.getFilteredOrders();

    let delivered = 0;
    let processing = 0;
    let dispatched = 0;
    let cancelled = 0;

    orders.forEach(o => {
      const s = (o.status || 'confirmed').toLowerCase();
      if (s === 'delivered' || s === 'completed') delivered++;
      else if (s === 'processing' || s === 'confirmed') processing++;
      else if (s === 'dispatched' || s === 'in-transit') dispatched++;
      else if (s === 'cancelled' || s === 'returned') cancelled++;
      else processing++;
    });

    const total = orders.length;

    // Update summary metrics in DOM
    const donutVal = document.getElementById('donutTotalOrdersVal');
    if (donutVal) donutVal.textContent = total;

    const badgeRate = document.getElementById('badgeDeliveryRate');
    if (badgeRate) {
      const rate = total > 0 ? Math.round((delivered / total) * 100) : 0;
      badgeRate.textContent = total > 0 ? `${rate}% Delivered` : '0 Booked';
    }

    const elDelivered = document.getElementById('donutBreakdownDelivered');
    if (elDelivered) elDelivered.textContent = `${delivered} (${total > 0 ? Math.round((delivered / total) * 100) : 0}%)`;
    const elProcessing = document.getElementById('donutBreakdownProcessing');
    if (elProcessing) elProcessing.textContent = `${processing} (${total > 0 ? Math.round((processing / total) * 100) : 0}%)`;
    const elDispatched = document.getElementById('donutBreakdownDispatched');
    if (elDispatched) elDispatched.textContent = `${dispatched} (${total > 0 ? Math.round((dispatched / total) * 100) : 0}%)`;
    const elCancelled = document.getElementById('donutBreakdownCancelled');
    if (elCancelled) elCancelled.textContent = `${cancelled} (${total > 0 ? Math.round((cancelled / total) * 100) : 0}%)`;

    if (this.charts.fulfillmentStatus) {
      this.charts.fulfillmentStatus.destroy();
    }

    const hasData = total > 0;
    const chartLabels = hasData ? ['Delivered', 'Processing', 'Dispatched', 'Cancelled'] : ['No Orders Booked'];
    const chartData = hasData ? [delivered, processing, dispatched, cancelled] : [1];
    const chartColors = hasData ? [
      theme.accentEmerald,
      theme.accentAmber,
      theme.accentPrimary,
      theme.accentRose
    ] : [theme.isDark ? '#374151' : '#E5E7EB'];

    this.charts.fulfillmentStatus = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: chartLabels,
        datasets: [{
          data: chartData,
          backgroundColor: chartColors,
          borderColor: theme.cardBg,
          borderWidth: 3,
          hoverOffset: hasData ? 4 : 0
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '72%',
        plugins: {
          legend: {
            position: 'bottom',
            labels: {
              color: theme.textColor,
              font: { size: 11, weight: '600', family: 'Inter, sans-serif' },
              boxWidth: 12,
              padding: 14
            }
          },
          tooltip: {
            backgroundColor: theme.isDark ? '#1F2937' : '#FFFFFF',
            titleColor: theme.textColor,
            bodyColor: theme.textColor,
            borderColor: theme.gridColor,
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: function(ctx) {
                const count = ctx.raw;
                const pct = total > 0 ? Math.round((count / total) * 100) : 0;
                return ` ${ctx.label}: ${count} ${count === 1 ? 'order' : 'orders'} (${pct}% of pipeline)`;
              }
            }
          }
        }
      }
    });
  }

  // CHART 3: TOP BUYING RETAIL OUTLETS
  renderChartTopShops() {
    const canvas = document.getElementById('chartTopShops');
    if (!canvas) return;
    if (typeof Chart === 'undefined') { this.renderNativeTopShops(); return; }

    const theme = this.getChartThemeColors();
    const orders = this.getFilteredOrders();

    const shopMap = {};
    orders.forEach(o => {
      const name = this.resolveShopName(o.shopId, o.shopName);
      if (!shopMap[name]) shopMap[name] = { name, revenue: 0, count: 0 };
      shopMap[name].revenue += Number(o.grandTotal) || 0;
      shopMap[name].count += 1;
    });

    const top = Object.values(shopMap)
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 5);

    const totalRetailGMV = orders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    const topGMV = top.reduce((sum, s) => sum + s.revenue, 0);
    const topPct = totalRetailGMV > 0 ? Math.round((topGMV / totalRetailGMV) * 100) : 100;

    const elContrib = document.getElementById('topShopsContributionPct');
    if (elContrib) elContrib.textContent = `${topPct}%`;

    const hasShops = top.length > 0;
    const labels = hasShops ? top.map(s => s.name.length > 20 ? s.name.substring(0, 18) + '...' : s.name) : ['No Orders Yet'];
    const data = hasShops ? top.map(s => s.revenue) : [0];

    if (this.charts.topShops) {
      this.charts.topShops.destroy();
    }

    this.charts.topShops = new Chart(canvas, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: 'Order Value (₹)',
          data: data,
          backgroundColor: hasShops ? 'rgba(59, 130, 246, 0.85)' : (theme.isDark ? '#374151' : '#E5E7EB'),
          hoverBackgroundColor: '#3B82F6',
          borderRadius: 6,
          barThickness: 18
        }]
      },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: theme.isDark ? '#1F2937' : '#FFFFFF',
            titleColor: theme.textColor,
            bodyColor: theme.textColor,
            borderColor: theme.gridColor,
            borderWidth: 1,
            padding: 10,
            callbacks: {
              title: function(items) {
                return top[items[0].dataIndex]?.name || items[0].label;
              },
              label: function(ctx) {
                const s = top[ctx.dataIndex];
                if (!s) return '';
                return [
                  ` 💰 Total Booked GMV: ₹${Number(s.revenue).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`,
                  ` 📦 Placed Orders: ${s.count} ${s.count === 1 ? 'order' : 'orders'}`
                ];
              }
            }
          }
        },
        scales: {
          x: {
            grid: { color: theme.gridColor, drawBorder: false },
            ticks: {
              color: theme.mutedColor,
              font: { size: 10.5 },
              callback: function(val) {
                if (val >= 1000) return '₹' + (val / 1000).toFixed(0) + 'k';
                return '₹' + val;
              }
            }
          },
          y: {
            grid: { display: false, drawBorder: false },
            ticks: {
              color: theme.textColor,
              font: { size: 11, weight: '600' }
            }
          }
        }
      }
    });
  }

  // CHART 4: SAAS SUBSCRIPTION PLAN DISTRIBUTION
  renderChartPlanDistribution() {
    const canvas = document.getElementById('chartPlanDistribution');
    if (!canvas) return;
    if (typeof Chart === 'undefined') { this.renderNativePlanDistribution(); return; }
    if (!this.charts) this.charts = {};

    const theme = this.getChartThemeColors();
    const tenants = this.tenants || [];

    let startup = 0;
    let grow = 0;
    let enterprise = 0;
    let freemium = 0;

    tenants.forEach(t => {
      const plan = (t.subscriptionPlanId || t.planName || '').toLowerCase();
      const status = (t.subscriptionStatus || '').toLowerCase();
      if (status === 'expired') {
        freemium++; // "expired / read-only" bucket (there is no free plan)
      } else if (plan.includes('enterprise') || plan.includes('platinum')) {
        enterprise++;
      } else if (plan.includes('grow') || plan.includes('growth') || plan.includes('gold')) {
        grow++;
      } else if (plan.includes('startup') || plan.includes('silver')) {
        startup++;
      } else {
        startup++;
      }
    });

    const totalPlans = startup + grow + enterprise + freemium;
    const hasPlans = totalPlans > 0;

    // Update pill counters in DOM
    const elEnt = document.getElementById('pillEnterpriseCount');
    if (elEnt) elEnt.textContent = enterprise;
    const elGrow = document.getElementById('pillGrowCount');
    if (elGrow) elGrow.textContent = grow;
    const elStart = document.getElementById('pillStartupCount');
    if (elStart) elStart.textContent = startup;
    const elFree = document.getElementById('pillFreemiumCount');
    if (elFree) elFree.textContent = freemium;

    if (this.charts.planDistribution) {
      this.charts.planDistribution.destroy();
    }

    const planLabels = hasPlans ? ['Enterprise (₹899)', 'Grow (₹599)', 'Startup (₹399)', 'Expired (Read-only)'] : ['No Agencies Registered'];
    const planData = hasPlans ? [enterprise, grow, startup, freemium] : [1];
    const planColors = hasPlans ? [
      theme.accentEmerald,
      theme.accentPurple,
      theme.accentPrimary,
      theme.accentAmber
    ] : [theme.isDark ? '#374151' : '#E5E7EB'];

    this.charts.planDistribution = new Chart(canvas, {
      type: 'doughnut',
      data: {
        labels: planLabels,
        datasets: [{
          data: planData,
          backgroundColor: planColors,
          borderColor: theme.cardBg,
          borderWidth: 3
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'right',
            labels: {
              color: theme.textColor,
              font: { size: 11, weight: '600' },
              padding: 12
            }
          },
          tooltip: {
            backgroundColor: theme.isDark ? '#1F2937' : '#FFFFFF',
            titleColor: theme.textColor,
            bodyColor: theme.textColor,
            borderColor: theme.gridColor,
            borderWidth: 1,
            padding: 10,
            callbacks: {
              label: function(ctx) {
                const count = ctx.raw;
                const pct = totalPlans > 0 ? Math.round((count / totalPlans) * 100) : 0;
                return ` ${ctx.label}: ${count} ${count === 1 ? 'agency' : 'agencies'} (${pct}%)`;
              }
            }
          }
        }
      }
    });
  }

  // EXPORT DASHBOARD SUMMARY AS CSV
  exportDashboardSummary() {
    const orders = this.getFilteredOrders();
    const tenants = this.tenants || [];

    const totalGMV = orders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    const deliveredCount = orders.filter(o => (o.status || '').toLowerCase() === 'delivered').length;

    let csv = '\\uFEFF'; // UTF-8 BOM
    csv += 'SalesArmy SaaS Super Admin - Executive Dashboard Report\n';
    csv += `Generated At,${new Date().toISOString()}\n`;
    csv += `Time Window,${this.dashTimeWindow || 'all'}\n`;
    csv += `Agency Filter,${this.dashTenantFilter || 'all'}\n\n`;

    csv += 'EXECUTIVE KPI SUMMARY\n';
    csv += 'Metric,Value\n';
    csv += `Total Gross Merchandise Value (GMV),Rs. ${totalGMV.toFixed(2)}\n`;
    csv += `Total Retail B2B Orders,${orders.length}\n`;
    csv += `Delivered Orders,${deliveredCount}\n`;
    csv += `Fulfillment Rate,${orders.length > 0 ? ((deliveredCount / orders.length) * 100).toFixed(1) : 100}%\n`;
    csv += `Total Registered Agencies,${tenants.length}\n\n`;

    csv += 'RECENT RETAIL ORDERS LOG\n';
    csv += 'Order Number,Shop Name,Agency,Amount,Status,Payment Status,Date\n';
    orders.forEach(o => {
      const num = o.orderNumber || o.orderId || o.id;
      const shop = (o.shopName || '').replace(/,/g, ' ');
      const agency = (o.tenantName || '').replace(/,/g, ' ');
      const amt = Number(o.grandTotal || 0).toFixed(2);
      const st = o.status || 'Confirmed';
      const pay = o.paymentStatus || 'Pending';
      const dt = o.orderDate || o.createdAt || '';
      csv += `${num},${shop},${agency},${amt},${st},${pay},${dt}\n`;
    });

    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `salesarmy_executive_dashboard_${Date.now()}.csv`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);

    this.showToast('Executive dashboard CSV exported successfully!', '📥');
  }


  renderStats() {
    const totalTenants = (this.tenants || []).length;
    const totalUsers = (this.users || []).length;
    const totalOrders = (this.retailOrders || []).length;
    const activeCoupons = (this.coupons || []).filter(c => c.isActive).length;
    const printerOrdersCount = (this.printerOrders || []).length;
    const totalGMV = (this.retailOrders || []).reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);

    const elTenants = document.getElementById('statTotalTenants');
    const elUsers = document.getElementById('statTotalUsers');
    const elOrders = document.getElementById('statTotalOrders');
    const elCoupons = document.getElementById('statActiveCoupons');
    const elPrinters = document.getElementById('statPrinterOrders');
    const elGMV = document.getElementById('statTotalGMV');

    if (elTenants) elTenants.textContent = totalTenants;
    if (elUsers) elUsers.textContent = totalUsers;
    if (elOrders) elOrders.textContent = totalOrders;
    if (elCoupons) elCoupons.textContent = activeCoupons;
    if (elPrinters) elPrinters.textContent = printerOrdersCount;
    if (elGMV) elGMV.textContent = `₹${totalGMV.toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;

    const badgeCoupons = document.getElementById('badgeCouponsCount');
    if (badgeCoupons) badgeCoupons.textContent = (this.coupons || []).length;

    const badgePrinters = document.getElementById('badgePrinterOrdersCount');
    if (badgePrinters) badgePrinters.textContent = (this.printerOrders || []).length;

    const badgeTenants = document.getElementById('badgeTenantsCount');
    if (badgeTenants) badgeTenants.textContent = (this.tenants || []).length;

    const badgeUsers = document.getElementById('badgeUsersCount');
    if (badgeUsers) badgeUsers.textContent = (this.users || []).length;

    const badgeOrders = document.getElementById('badgeRetailOrdersCount');
    if (badgeOrders) badgeOrders.textContent = (this.retailOrders || []).length;
  }

  // ==============================================
  // VIEW: RETAIL ORDERS & INVOICING
  // ==============================================
  renderOrdersView() {
    const tbody = document.getElementById('retailOrdersTableBody');
    const orders = this.retailOrders || [];
    
    const totalGMV = orders.reduce((sum, o) => sum + (Number(o.grandTotal) || 0), 0);
    const deliveredCount = orders.filter(o => (o.status || '').toLowerCase() === 'delivered').length;
    const pendingCount = orders.length - deliveredCount;

    const elGMV = document.getElementById('statOrdersGMV');
    const elCount = document.getElementById('statOrdersCount');
    const elDelivered = document.getElementById('statOrdersDelivered');
    const elPending = document.getElementById('statOrdersPending');
    const badgeCount = document.getElementById('badgeRetailOrdersCount');

    if (elGMV) elGMV.textContent = `₹${totalGMV.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elCount) elCount.textContent = orders.length;
    if (elDelivered) elDelivered.textContent = deliveredCount;
    if (elPending) elPending.textContent = pendingCount;
    if (badgeCount) badgeCount.textContent = orders.length;

    if (!tbody) return;

    let filtered = orders.slice();
    if (this.orderFilter && this.orderFilter !== 'all') {
      filtered = filtered.filter(o => (o.status || '').toLowerCase() === this.orderFilter.toLowerCase());
    }
    if (this.orderSearch) {
      const q = this.orderSearch.toLowerCase();
      filtered = filtered.filter(o =>
        (o.orderNumber && o.orderNumber.toLowerCase().includes(q)) ||
        (o.shopName && o.shopName.toLowerCase().includes(q)) ||
        (o.ownerName && o.ownerName.toLowerCase().includes(q)) ||
        (o.salesmanName && o.salesmanName.toLowerCase().includes(q)) ||
        (o.address && o.address.toLowerCase().includes(q))
      );
    }

    if (filtered.length === 0) {
      tbody.innerHTML = `
        <tr>
          <td colspan="9" style="text-align: center; padding: 36px; color: var(--text-muted);">
            No retail orders match current filter criteria. Field salesmen orders will sync here live.
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = filtered.map(o => {
      const st = (o.status || 'pending').toLowerCase();
      const statusBadgeClass = st === 'delivered' ? 'badge-delivered' : (st === 'dispatched' ? 'badge-active' : (st === 'confirmed' ? 'badge-trial' : 'badge-pending'));
      const orderDateStr = o.orderDate ? new Date(o.orderDate).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' }) : 'Recent';
      const itemsSummary = Array.isArray(o.items) && o.items.length > 0 
        ? `${o.items.length} items (${o.items.map(i => i.productName).slice(0, 2).join(', ')}${o.items.length > 2 ? '...' : ''})`
        : 'General FMCG Order';
      const initials = (o.shopName || 'RK').split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();

      return `
        <tr>
          <td>
            <span class="code-pill">${this.escapeHtml(o.orderNumber || o.id)}</span>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">${orderDateStr}</div>
          </td>
          <td>
            <div style="display: flex; align-items: center; gap: 10px;">
              <div style="width: 32px; height: 32px; border-radius: var(--radius-sm); background: linear-gradient(135deg, #059669, #10B981); color: white; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 800; flex-shrink: 0;">${this.escapeHtml(initials)}</div>
              <div>
                <strong style="color: var(--text-main); font-size: 13.5px; display: block;">${this.escapeHtml(o.shopName || 'Retail Kirana')}</strong>
                <div style="font-size: 11.5px; color: var(--text-muted);">${this.escapeHtml(o.ownerName || '')}${o.phone ? ' • 📞 ' + this.escapeHtml(o.phone) : ''}</div>
                <div style="font-size: 11px; color: var(--text-muted);">${this.escapeHtml(o.address || '')}</div>
              </div>
            </div>
          </td>
          <td>
            <div style="font-weight: 600; color: var(--text-main); font-size: 13px;">${this.escapeHtml(o.salesmanName || '—')}</div>
            <div style="font-size: 11px; color: var(--text-muted);">${this.escapeHtml(o.tenantName || o.tenantId || '')}</div>
          </td>
          <td style="font-size: 12px; color: var(--text-muted); max-width: 220px;">
            ${this.escapeHtml(itemsSummary)}
          </td>
          <td>
            <div style="font-size: 12.5px; color: var(--text-main); font-weight: 600;">₹${Number(o.subtotal || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
            <div style="font-size: 11px; color: var(--accent-emerald);">+ GST: ₹${Number(o.totalGst || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
          </td>
          <td>
            <div style="font-weight: 800; font-size: 14.5px; color: var(--text-main); font-family: 'JetBrains Mono', monospace;">₹${Number(o.grandTotal || 0).toLocaleString('en-IN', { minimumFractionDigits: 2 })}</div>
          </td>
          <td>
            <select class="form-control" style="font-size: 11.5px; padding: 4px 8px; height: auto; border-radius: var(--radius-xs); font-weight: 700; width: auto;" onchange="adminApp.updateRetailOrderStatus('${this.escapeJs(o.id)}', this.value)">
              <option value="Pending" ${st === 'pending' ? 'selected' : ''}>⏳ Pending</option>
              <option value="Confirmed" ${st === 'confirmed' ? 'selected' : ''}>📝 Confirmed</option>
              <option value="Processing" ${st === 'processing' ? 'selected' : ''}>📦 Processing</option>
              <option value="Dispatched" ${st === 'dispatched' ? 'selected' : ''}>🚚 Dispatched</option>
              <option value="Delivered" ${st === 'delivered' ? 'selected' : ''}>✅ Delivered</option>
              <option value="Cancelled" ${st === 'cancelled' ? 'selected' : ''}>❌ Cancelled</option>
            </select>
          </td>
          <td>
            <span class="badge ${o.paymentStatus === 'Paid' ? 'badge-delivered' : 'badge-pending'}">
              <span style="width: 5px; height: 5px; border-radius: 50%; background: currentColor;"></span>
              ${this.escapeHtml(o.paymentStatus || 'Not billed')}
            </span>
            ${o.invoiceNumber ? `<div style="font-size: 11px; color: var(--text-muted); margin-top: 3px;">Inv ${this.escapeHtml(o.invoiceNumber)}</div>` : ''}
          </td>
          <td>
            <div style="display: flex; gap: 6px;">
              <button class="btn btn-sm btn-outline" onclick="adminApp.viewOrderInvoice('${this.escapeJs(o.id || o.orderId)}')" title="View & Print Tax Invoice" style="padding: 5px 10px; font-size: 12px;">
                🧾 Invoice
              </button>
              <button class="btn btn-sm btn-outline" style="color: #DC2626; border-color: #FECACA; padding: 5px 8px; font-size: 12px;" onclick="adminApp.deleteRetailOrder('${this.escapeJs(o.id || o.orderId)}')" title="Delete Retail Order">
                🗑️
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  filterOrders(status) {
    this.orderFilter = status;
    document.querySelectorAll('.order-filter-btn').forEach(b => {
      b.classList.toggle('active', b.dataset.orderFilter === status);
    });
    this.renderOrdersView();
  }

  handleOrderSearch(query) {
    this.orderSearch = (query || '').toLowerCase().trim();
    const btn = document.getElementById('btnClearOrderSearch');
    if (btn) btn.style.display = this.orderSearch ? 'flex' : 'none';
    this.renderOrdersView();
  }

  clearOrderSearch() {
    this.orderSearch = '';
    const input = document.getElementById('searchOrdersInput');
    if (input) input.value = '';
    const btn = document.getElementById('btnClearOrderSearch');
    if (btn) btn.style.display = 'none';
    this.renderOrdersView();
  }

  async updateRetailOrderStatus(orderId, newStatus) {
    const order = (this.retailOrders || []).find(o => o.id === orderId);
    const ok = await this.apiMutate('/api/platform/retail-orders/status', { id: orderId, status: String(newStatus).toLowerCase() });
    if (!ok) { this.renderOrdersView(); return; }
    await this.fetchPlatformState(true);
    this.showToast(`Order ${order?.orderNumber || ''} set to ${newStatus}.`, '🚚');
  }

  openOrderDetailModal(orderId) {
    this.viewOrderInvoice(orderId);
  }

  viewOrderInvoice(orderId) {
    this.activeInvoiceOrderId = orderId;
    const order = (this.retailOrders || []).find(o => o.id === orderId || o.orderId === orderId);
    if (!order) return;

    const modal = document.getElementById('orderInvoiceModal');
    const body = document.getElementById('orderInvoiceModalBody');
    const title = document.getElementById('orderInvoiceModalTitle');
    if (!modal || !body) return;

    if (title) title.textContent = `Order Summary — ${order.orderNumber || order.id}`;

    const items = Array.isArray(order.items) ? order.items : [];

    // Per-tenant invoice details — look up the tenant that actually owns
    // this order instead of hardcoding the demo GSTIN.
    const tenant = (this.tenants || []).find(t =>
      t.id === order.tenantId || t.tenantId === order.tenantId
    ) || {};
    const tenantGstin = tenant.gstin || order.tenantGstin || '—';
    const tenantStateCode = (typeof tenantGstin === 'string' && tenantGstin.length >= 2 && /^[0-9]{2}/.test(tenantGstin))
      ? tenantGstin.substring(0, 2)
      : '—';
    const tenantFirmName = tenant.firmName || tenant.businessName || tenant.business_name || order.tenantName || 'SalesArmy Distribution Agency';

    body.innerHTML = `
      <div style="background: white; border-radius: 8px; border: 1px solid #E2E8F0; padding: 24px; color: #0F172A; font-family: system-ui, -apple-system, sans-serif;">
        <!-- Header -->
        <div style="display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #E2E8F0; padding-bottom: 16px;">
          <div>
            <h2 style="font-size: 20px; font-weight: 800; margin: 0; color: #1E3A8A;">${this.escapeHtml(tenantFirmName)}</h2>
            <div style="font-size: 12px; color: #64748B; margin-top: 4px;">
              GSTIN: <strong>${this.escapeHtml(tenantGstin)}</strong> | State Code: ${this.escapeHtml(tenantStateCode)}<br>
              Authorized FMCG Wholesale &amp; Super Distributor
            </div>
          </div>
          <div style="text-align: right;">
            <span style="background: #EFF6FF; color: #1D4ED8; font-weight: 800; font-size: 13px; padding: 4px 10px; border-radius: 6px;">${order.invoiceNumber ? 'INVOICED' : 'ORDER SUMMARY'}</span>
            ${order.invoiceNumber ? `<div style="font-size: 11px; color: #64748B; margin-top: 4px;">Invoice ${this.escapeHtml(order.invoiceNumber)}</div>` : ''}
            <div style="font-size: 13px; font-weight: 700; margin-top: 6px;">${this.escapeHtml(order.orderNumber || order.id)}</div>
            <div style="font-size: 11px; color: #64748B;">Date: ${new Date(order.orderDate || Date.now()).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}</div>
          </div>
        </div>

        <!-- Bill To / Ship To -->
        <div style="display: flex; justify-content: space-between; margin-top: 16px; font-size: 12.5px; line-height: 1.5;">
          <div>
            <strong style="color: #475569; text-transform: uppercase; font-size: 11px;">Billed & Delivered To:</strong>
            <div style="font-weight: 800; font-size: 14px; margin-top: 2px;">${this.escapeHtml(order.shopName || 'Retail Customer')}</div>
            <div>Owner: ${this.escapeHtml(order.ownerName || 'N/A')}</div>
            <div>Address: ${this.escapeHtml(order.address || 'Market Area')}</div>
            <div>Phone: ${this.escapeHtml(order.phone || 'N/A')}</div>
          </div>
          <div style="text-align: right;">
            <strong style="color: #475569; text-transform: uppercase; font-size: 11px;">Beat & Fulfillment:</strong>
            <div>Salesman: <strong>${this.escapeHtml(order.salesmanName || '—')}</strong></div>
            <div>Billing: <strong>${this.escapeHtml(order.paymentStatus || 'Not billed')}</strong></div>
            <div>Status: <span style="font-weight: 700; color: #059669;">${this.escapeHtml(order.status || '')}</span></div>
          </div>
        </div>

        <!-- Items Table -->
        <table style="width: 100%; margin-top: 20px; border-collapse: collapse; font-size: 12px;">
          <thead>
            <tr style="background: #F8FAFC; border-bottom: 1px solid #CBD5E1;">
              <th style="padding: 8px 6px; text-align: left;">#</th>
              <th style="padding: 8px 6px; text-align: left;">Product Description</th>
              <th style="padding: 8px 6px; text-align: center;">Qty</th>
              <th style="padding: 8px 6px; text-align: right;">Rate (₹)</th>
              <th style="padding: 8px 6px; text-align: center;">GST %</th>
              <th style="padding: 8px 6px; text-align: right;">Total (₹)</th>
            </tr>
          </thead>
          <tbody>
            ${items.length === 0 ? '<tr><td colspan="6" style="padding: 12px; text-align: center; color: #64748B;">No line items were recorded for this order.</td></tr>' : ''}
            ${items.map((it, idx) => `
              <tr style="border-bottom: 1px solid #F1F5F9;">
                <td style="padding: 8px 6px;">${idx + 1}</td>
                <td style="padding: 8px 6px; font-weight: 600;">${this.escapeHtml(it.productName || 'Product')}</td>
                <td style="padding: 8px 6px; text-align: center;">${Number(it.quantity || 0)}</td>
                <td style="padding: 8px 6px; text-align: right;">₹${Number(it.unitPrice || 0).toFixed(2)}</td>
                <td style="padding: 8px 6px; text-align: center;">${Number(it.gstRate || 0)}%</td>
                <td style="padding: 8px 6px; text-align: right; font-weight: 700;">₹${Number(it.total || 0).toFixed(2)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>

        <!-- Totals Breakdown -->
        <div style="display: flex; justify-content: space-between; margin-top: 16px;">
          <div style="max-width: 320px; font-size: 11.5px; color: #64748B;">
            ${order.notes ? `<strong>Beat Notes:</strong> ${this.escapeHtml(order.notes)}` : ''}
          </div>
          <div style="width: 260px; font-size: 12.5px; line-height: 1.6;">
            <div style="display: flex; justify-content: space-between;">
              <span style="color: #64748B;">Taxable Subtotal:</span>
              <span>₹${Number(order.subtotal || 0).toFixed(2)}</span>
            </div>
            <div style="display: flex; justify-content: space-between;">
              <span style="color: #64748B;">CGST + SGST (Split 50/50):</span>
              <span style="color: #059669;">₹${Number(order.totalGst || 0).toFixed(2)}</span>
            </div>
            <div style="display: flex; justify-content: space-between; border-top: 2px solid #0F172A; padding-top: 6px; margin-top: 4px; font-size: 15px; font-weight: 800;">
              <span>Grand Total:</span>
              <span style="color: #1E3A8A;">₹${Number(order.grandTotal || 0).toFixed(2)}</span>
            </div>
          </div>
        </div>

        <!-- Footer / Declaration -->
        <div style="margin-top: 24px; padding-top: 12px; border-top: 1px dashed #CBD5E1; font-size: 11px; color: #64748B;">
          This is an order summary from the SalesArmy admin console. GST tax invoices are issued by the agency from the SalesArmy app.
        </div>
      </div>
    `;

    modal.classList.add('active');
  }

  closeInvoiceModal() {
    const modal = document.getElementById('orderInvoiceModal');
    if (modal) modal.classList.remove('active');
  }

  shareInvoiceWhatsApp() {
    if (!this.activeInvoiceOrderId) return;
    const order = (this.retailOrders || []).find(o => o.id === this.activeInvoiceOrderId || o.orderId === this.activeInvoiceOrderId);
    if (!order) return;
    const phone = String(order.phone || '').replace(/[^0-9]/g, '');
    const itemsText = (order.items || []).map(i => `• ${i.productName} (x${i.quantity}) - ₹${Number(i.total || (i.quantity * i.unitPrice) || 0).toFixed(2)}`).join('\n');
    const msg = `🧾 *ORDER — ${order.orderNumber || order.id}*\n*Agency:* ${order.tenantName || 'SalesArmy Agency'}\n*Customer:* ${order.shopName || 'Retail Customer'}\n*Date:* ${new Date(order.orderDate || Date.now()).toLocaleDateString('en-IN')}\n\n*Ordered Items:*\n${itemsText || 'General FMCG Order'}\n\n*Taxable Subtotal:* ₹${Number(order.subtotal || 0).toFixed(2)}\n*GST (CGST+SGST):* ₹${Number(order.totalGst || 0).toFixed(2)}\n*Grand Total:* ₹${Number(order.grandTotal || 0).toFixed(2)}\n*Billing:* ${order.paymentStatus || 'Not billed'}\n\nThank you for your business! 🙏`;
    const targetUrl = phone.length >= 10 
      ? `https://wa.me/91${phone.slice(-10)}?text=${encodeURIComponent(msg)}`
      : `https://wa.me/?text=${encodeURIComponent(msg)}`;
    window.open(targetUrl, '_blank');
  }

  openCreateOrderModal() {
    const modal = document.getElementById('createOrderModal');
    if (!modal) return;
    
    // Populate tenant select
    const sel = document.getElementById('ordTenantSelect');
    if (sel) {
      sel.innerHTML = (this.tenants || []).map(t => `<option value="${this.escapeHtml(t.id || t.tenantId)}" data-name="${this.escapeHtml(t.firmName)}">${this.escapeHtml(t.firmName)} (${this.escapeHtml(t.city)})</option>`).join('');
    }

    // Default order number
    const ordNumInput = document.getElementById('ordNumber');
    if (ordNumInput) {
      const nextNum = Math.floor(1000 + Math.random() * 9000);
      ordNumInput.value = `ORD-2026-${nextNum}`;
    }

    // Start the modal with one empty line item — do NOT seed demo FMCG rows.
    const linesContainer = document.getElementById('orderLineItemsContainer');
    if (linesContainer) {
      linesContainer.innerHTML = '';
      this.addOrderLineItem('', 1, 0, 18);
    }
    
    this.updateOrderCalculations();
    modal.classList.add('active');
  }

  closeCreateOrderModal() {
    const modal = document.getElementById('createOrderModal');
    if (modal) modal.classList.remove('active');
  }

  addOrderLineItem(name = '', qty = 1, price = 0, gst = 18) {
    const container = document.getElementById('orderLineItemsContainer');
    if (!container) return;
    const row = document.createElement('div');
    row.className = 'order-line-row';
    row.innerHTML = `
      <input type="text" class="form-control item-name" placeholder="Item Name (e.g. Britannia Bourbon)" value="${this.escapeHtml(name)}" required />
      <input type="number" class="form-control item-qty" min="1" step="1" value="${qty}" oninput="adminApp.updateOrderCalculations()" required />
      <input type="number" class="form-control item-price" min="0" step="0.01" value="${price}" oninput="adminApp.updateOrderCalculations()" required />
      <select class="form-control item-gst" onchange="adminApp.updateOrderCalculations()">
        <option value="0" ${gst === 0 ? 'selected' : ''}>0%</option>
        <option value="5" ${gst === 5 ? 'selected' : ''}>5%</option>
        <option value="12" ${gst === 12 ? 'selected' : ''}>12%</option>
        <option value="18" ${gst === 18 ? 'selected' : ''}>18%</option>
        <option value="28" ${gst === 28 ? 'selected' : ''}>28%</option>
      </select>
      <div class="item-line-total" style="font-weight: 700; font-size: 13px; color: var(--text-main); font-family: monospace;">₹0.00</div>
      <button type="button" class="btn btn-sm btn-outline" style="color: #DC2626; border-color: #FECACA; padding: 4px;" onclick="adminApp.removeOrderLineItem(this)" title="Remove Item">✕</button>
    `;
    container.appendChild(row);
    this.updateOrderCalculations();
  }

  removeOrderLineItem(btn) {
    const row = btn.closest('.order-line-row');
    if (row) {
      row.remove();
      this.updateOrderCalculations();
    }
  }

  updateOrderCalculations() {
    const rows = document.querySelectorAll('#orderLineItemsContainer .order-line-row');
    let subtotal = 0;
    let totalGst = 0;

    rows.forEach(r => {
      const qty = parseFloat(r.querySelector('.item-qty')?.value) || 0;
      const price = parseFloat(r.querySelector('.item-price')?.value) || 0;
      const gstRate = parseFloat(r.querySelector('.item-gst')?.value) || 0;
      
      const lineSubtotal = qty * price;
      const lineGst = lineSubtotal * (gstRate / 100);
      const lineGrand = lineSubtotal + lineGst;

      subtotal += lineSubtotal;
      totalGst += lineGst;

      const totalDisplay = r.querySelector('.item-line-total');
      if (totalDisplay) totalDisplay.textContent = `₹${lineGrand.toFixed(2)}`;
    });

    const grandTotal = subtotal + totalGst;

    const elSub = document.getElementById('calcOrderSubtotal') || document.getElementById('ordCalcSubtotal');
    const elGst = document.getElementById('calcOrderGst') || document.getElementById('ordCalcGst');
    const elGrand = document.getElementById('calcOrderGrandTotal') || document.getElementById('ordCalcGrandTotal');

    if (elSub) elSub.textContent = `₹${subtotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elGst) elGst.textContent = `₹${totalGst.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
    if (elGrand) elGrand.textContent = `₹${grandTotal.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  }

  onOrderTenantChange(tenantId) {
    // Optionally update salesman default
  }

  async handleSaveOrder(e) {
    if (e) e.preventDefault();
    const val = id => document.getElementById(id)?.value.trim() || '';
    const tenantId = document.getElementById('ordTenantSelect')?.value;
    if (!tenantId) { this.showToast('Select the agency this order belongs to.', '⚠️', 'warning'); return; }

    const items = [];
    document.querySelectorAll('#orderLineItemsContainer .order-line-row').forEach(r => {
      const productName = r.querySelector('.item-name')?.value.trim();
      const quantity = parseInt(r.querySelector('.item-qty')?.value, 10) || 0;
      const unitPrice = parseFloat(r.querySelector('.item-price')?.value) || 0;
      const gstRate = parseFloat(r.querySelector('.item-gst')?.value) || 0;
      if (productName && quantity > 0) items.push({ productName, quantity, unitPrice, gstRate });
    });
    if (!items.length) { this.showToast('Add at least one line item.', '⚠️', 'warning'); return; }

    const orderNumber = val('ordNumber').replace(/[^A-Za-z0-9_-]/g, '-');
    const ok = await this.apiMutate('/api/platform/sync-order', {
      tenantId, orderNumber, items,
      shopName: val('ordShopName'), ownerName: val('ordOwnerName'), phone: val('ordPhone'), address: val('ordAddress'),
      paymentMethod: [document.getElementById('ordPaymentMethod')?.value, document.getElementById('ordPaymentStatus')?.value].filter(Boolean).join(' – '),
      status: (document.getElementById('ordStatus')?.value || 'confirmed').toLowerCase(),
      notes: [val('ordSalesmanName') && `Salesman: ${val('ordSalesmanName')}`, val('ordNotes')].filter(Boolean).join(' | '),
    });
    if (!ok) return;
    this.closeCreateOrderModal();
    await this.fetchPlatformState(true);
    this.showToast(`Order${orderNumber ? ` ${orderNumber}` : ''} created. Totals were calculated by the server.`, '📦');
  }

  async deleteRetailOrder(orderId) {
    const o = (this.retailOrders || []).find(x => x.id === orderId);
    if (!o) return;
    if (!confirm(`Permanently delete order "${o.orderNumber}" of ${o.tenantName}? Orders that are already invoiced cannot be deleted.`)) return;
    const ok = await this.apiMutate(`/api/platform/retail-orders/${encodeURIComponent(orderId)}`, null, { method: 'DELETE' });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`Order ${o.orderNumber} deleted.`, '🗑️');
  }

  async reconcileDatabases() {
    this.showToast('Running ledger & data integrity check…', '🔄');
    try {
      const res = await fetch('/api/platform/reconcile', { method: 'POST', headers: this.getAuthHeaders() });
      const data = await res.json();
      const drift = data.ledgerDrift || [];
      const badge = document.getElementById('reconcileStatusBadge');
      const count = document.getElementById('reconcileTablesCount');
      const lat = document.getElementById('reconcileLatencyMs');
      const statsBox = document.getElementById('reconciliationStatsBox');
      if (badge) {
        badge.textContent = drift.length ? `● ${drift.length} shop balance(s) differ from ledger` : '● Ledger balances verified';
        badge.style.color = drift.length ? '#D97706' : '#10B981';
      }
      if (count) count.textContent = `${Object.keys(data.counts || {}).length} tables checked`;
      if (lat) lat.textContent = `${data.latencyMs}ms`;
      if (statsBox) {
        const esc = v => this.escapeHtml(v);
        statsBox.innerHTML = `
          <div style="font-family: monospace; font-size: 11px; color: var(--text-secondary); line-height: 1.5;">
            ${Object.entries(data.counts || {}).map(([t, n]) => `<div>${esc(t)}: <strong>${esc(n)}</strong></div>`).join('')}
          </div>
          ${drift.length ? `
            <div style="margin-top: 10px; font-size: 11.5px;">
              <strong style="color:#D97706;">Balance drift (cached vs ledger):</strong>
              ${drift.slice(0, 20).map(d => `<div>${esc(d.tenant_id)} / ${esc(d.shop_name || d.shop_id)}: ₹${esc(d.cached)} vs ₹${esc(d.ledger)} (Δ ₹${esc(d.difference)})</div>`).join('')}
            </div>` : ''}
        `;
      }
      this.showToast(drift.length ? `Integrity check: ${drift.length} balance mismatch(es) found.` : 'Integrity check passed.', drift.length ? '⚠️' : '✓', drift.length ? 'warning' : 'success');
    } catch (_) { /* wrapper toasts the error */ }
  }

  async exportDataCSV(entity = 'orders') {
    try {
    const url = `/api/platform/export?entity=${encodeURIComponent(entity)}&format=csv`;
    const response = await fetch(url);
    const objectUrl = URL.createObjectURL(await response.blob());
    const a = document.createElement('a');
    a.href = objectUrl;
    a.download = `salesarmy_${entity}_${Date.now()}.csv`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(objectUrl);
    this.showToast(`Exporting ${entity.toUpperCase()} CSV...`, '📥');
    } catch (error) { this.showToast(error.message, '❌', 'danger'); }
  }

  // --- VIEW 2: Coupons Management ---
  /** Same rules as the server (api/catalog.mjs couponStatus); server value wins. */
  couponStatusOf(c) {
    if (c.status) return c.status;
    const day = (v, end) => new Date(String(v).length <= 10 ? `${v}T${end ? '23:59:59' : '00:00:00'}+05:30` : v);
    const now = new Date();
    if (c.isActive === false || c.isPaused === true) return 'paused';
    if (c.startDate && day(c.startDate, false) > now) return 'scheduled';
    const expiry = c.expiryDate || c.validUntil;
    if (expiry && day(expiry, true) <= now) return 'expired';
    if (Number(c.maxUses) > 0 && Number(c.usedCount || 0) >= Number(c.maxUses)) return 'used_up';
    return 'active';
  }

  couponPlanNames(ids) {
    const tiers = this.plans?.tiers || [];
    return (ids || []).map(id => tiers.find(t => t.id === id)?.name || id);
  }

  renderCouponsTable() {
    const tbody = document.getElementById('couponsTableBody');
    if (!tbody) return;
    const esc = v => this.escapeHtml(v);

    let list = this.coupons || [];

    // Filter type
    if (this.couponFilter && this.couponFilter !== 'all') {
      list = list.filter(c => c.type === this.couponFilter);
    }
    // Filter status
    if (this.couponStatusFilter && this.couponStatusFilter !== 'all') {
      list = list.filter(c => this.couponStatusOf(c) === this.couponStatusFilter);
    }
    // Search query
    if (this.couponSearch) {
      const q = this.couponSearch;
      list = list.filter(c =>
        String(c.code || '').toLowerCase().includes(q) ||
        String(c.title || '').toLowerCase().includes(q) ||
        String(c.description || '').toLowerCase().includes(q)
      );
    }

    if (list.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: #64748B; padding: 36px;">No coupons found matching criteria.</td></tr>`;
      return;
    }

    const STATUS = {
      active: ['badge-active', 'Active'],
      scheduled: ['badge-blue', 'Scheduled'],
      expired: ['badge-expired', 'Expired'],
      used_up: ['badge-warning', 'Used up'],
      paused: ['badge-expired', 'Paused'],
    };

    tbody.innerHTML = list.map(c => {
      const typeBadgeClass = c.type === 'trial' ? 'badge-trial' : (c.type === 'flat' ? 'badge-flat' : 'badge-pct');
      const typeLabel = c.type === 'trial' ? 'Membership Trial' : (c.type === 'flat' ? 'Flat Discount' : 'Percentage Off');
      const benefitText = c.type === 'trial'
        ? `+${esc(c.value)} Days Free Access`
        : (c.type === 'flat' ? `₹${esc(c.value)} OFF` : `${esc(c.value)}% OFF`);
      const used = Number(c.usedCount || 0);
      const max = Number(c.maxUses || 0);
      const usagePct = max > 0 ? Math.min(100, Math.round((used / max) * 100)) : 0;
      const status = this.couponStatusOf(c);
      const [statusClass, statusLabel] = STATUS[status] || STATUS.active;
      const plans = this.couponPlanNames(c.planIds);
      const limits = [
        plans.length ? `Plans: ${plans.map(esc).join(', ')}` : 'All plans',
        c.billingCycle === 'monthly' ? 'Monthly only' : c.billingCycle === 'yearly' ? 'Yearly only' : '',
        Number(c.minOrderValue || c.minAmount || 0) > 0 ? `Min ₹${esc(c.minOrderValue || c.minAmount)}` : '',
      ].filter(Boolean).join(' · ');
      const expiry = c.expiryDate || c.validUntil;
      const validity = `${c.startDate ? `From ${esc(c.startDate)}<br>` : ''}${expiry ? `Until ${esc(expiry)}` : 'No expiry'}`;
      const id = this.escapeJs(c.id);
      const canPause = status !== 'paused';

      return `
        <tr>
          <td>
            <div class="code-pill">
              <span>${esc(c.code)}</span>
              <button onclick="adminApp.copyText('${this.escapeJs(c.code)}')" style="background:transparent; border:none; color:var(--text-muted); cursor:pointer;" title="Copy Code">📋</button>
            </div>
            <div style="font-size: 11.5px; color: var(--text-muted); margin-top: 4px; font-weight: 600;">${esc(c.title)}</div>
          </td>
          <td>
            <span class="badge ${typeBadgeClass}">${typeLabel}</span>
          </td>
          <td>
            <strong style="color: var(--text-main); font-size: 14px;">${benefitText}</strong>
            <div style="font-size: 11px; color: var(--text-muted); max-width: 220px;">${limits}</div>
          </td>
          <td>
            <div style="display: flex; justify-content: space-between; font-size: 11.5px; margin-bottom: 4px; font-weight: 600; width: 110px;">
              <span style="color: var(--text-main);">${used} used</span>
              <span style="color: var(--text-muted);">${max ? `${Math.max(0, max - used)} left` : '∞'}</span>
            </div>
            <div style="width: 110px; height: 6px; background: var(--border-subtle); border-radius: 999px; overflow:hidden;">
              <div style="width: ${usagePct}%; height:100%; background: linear-gradient(90deg, #4F46E5, #3B82F6); border-radius: 999px;"></div>
            </div>
            <button class="btn btn-sm btn-outline" style="margin-top:6px; padding:2px 8px; font-size:11px;" onclick="adminApp.openCouponUsage('${this.escapeJs(c.code)}')">View usage</button>
          </td>
          <td style="font-size: 12px; color: var(--text-muted); font-family: 'JetBrains Mono', monospace;">
            ${validity}
          </td>
          <td>
            <span class="badge ${statusClass}">
              <span style="width: 5px; height: 5px; border-radius: 50%; background: currentColor;"></span>
              ${statusLabel}
            </span>
          </td>
          <td>
            <div style="display: flex; gap: 6px; flex-wrap: wrap;">
              <button class="btn btn-sm ${canPause ? 'btn-outline' : 'btn-primary'}" onclick="adminApp.toggleCouponStatus('${id}')">
                ${canPause ? 'Pause' : 'Activate'}
              </button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.editCoupon('${id}')">Edit</button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.duplicateCoupon('${id}')" title="Create a new coupon from this one">Duplicate</button>
              <button class="btn btn-sm btn-outline" style="color: var(--accent-rose); border-color: rgba(244, 63, 94, 0.3);" onclick="adminApp.deleteCoupon('${id}')">Delete</button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  renderCouponPlanChecks(selected = []) {
    const box = document.getElementById('couponPlanChecks');
    if (!box) return;
    const tiers = (this.plans?.tiers || []).filter(t => t.isActive !== false);
    box.innerHTML = tiers.length
      ? tiers.map(t => `
          <label style="display:flex; align-items:center; gap:6px; font-size:13px; cursor:pointer;">
            <input type="checkbox" class="coupon-plan-check" value="${this.escapeHtml(t.id)}" ${selected.includes(t.id) ? 'checked' : ''}>
            ${this.escapeHtml(t.name || t.id)}
          </label>`).join('')
      : '<span style="font-size:12px; color:var(--text-muted);">No plans configured.</span>';
  }

  /** mode: 'create' | 'edit' | 'duplicate' */
  openCouponModal(couponToEdit = null, mode = couponToEdit ? 'edit' : 'create') {
    const modal = document.getElementById('couponModal');
    const titleEl = document.getElementById('couponModalTitle');
    const submitBtn = document.getElementById('btnSubmitCoupon');
    const form = document.getElementById('couponForm');
    const codeEl = document.getElementById('couponCode');

    form.reset();
    codeEl.readOnly = false;
    codeEl.title = '';
    const set = (id, v) => { const el = document.getElementById(id); if (el) el.value = v ?? ''; };

    if (couponToEdit) {
      const isEdit = mode === 'edit';
      titleEl.textContent = isEdit ? `Edit Coupon: ${couponToEdit.code}` : `New Coupon (copy of ${couponToEdit.sourceCode || couponToEdit.code})`;
      submitBtn.textContent = isEdit ? 'Save Changes' : 'Publish Coupon';
      set('couponEditId', isEdit ? couponToEdit.id : '');
      set('couponCode', couponToEdit.code);
      set('couponTitle', couponToEdit.title);
      set('couponType', couponToEdit.type);
      set('couponValue', couponToEdit.value);
      set('couponMinOrder', couponToEdit.minOrderValue ?? couponToEdit.minAmount ?? 0);
      set('couponMaxUses', couponToEdit.maxUses);
      set('couponExpiry', couponToEdit.expiryDate || couponToEdit.validUntil || '');
      set('couponStartDate', couponToEdit.startDate || '');
      set('couponBillingCycle', couponToEdit.billingCycle || 'any');
      set('couponDescription', couponToEdit.description || '');
      this.renderCouponPlanChecks(couponToEdit.planIds || []);
      // Usage history is stored against the code, so a used code can't be renamed.
      if (isEdit && Number(couponToEdit.usedCount || 0) > 0) {
        codeEl.readOnly = true;
        codeEl.title = 'This code has already been used, so it cannot be renamed. Duplicate it to create a new code.';
      }
    } else {
      titleEl.textContent = 'Publish New Coupon / Trial Pass';
      submitBtn.textContent = 'Publish Coupon';
      set('couponEditId', '');
      set('couponCode', 'PROMO' + Math.floor(10 + Math.random() * 90));
      set('couponBillingCycle', 'any');
      this.renderCouponPlanChecks([]);
    }

    modal?.classList.add('active');
  }

  closeCouponModal() {
    document.getElementById('couponModal')?.classList.remove('active');
  }

  editCoupon(couponId) {
    const c = this.coupons.find(x => x.id === couponId);
    if (c) this.openCouponModal(c, 'edit');
  }

  async handleSaveCoupon() {
    const editId = document.getElementById('couponEditId').value;
    const code = document.getElementById('couponCode').value.trim().toUpperCase();
    const type = document.getElementById('couponType').value;
    const value = parseFloat(document.getElementById('couponValue').value);
    const existing = editId ? this.coupons.find(x => x.id === editId) : null;
    const startDate = document.getElementById('couponStartDate')?.value || null;
    const expiryDate = document.getElementById('couponExpiry').value || null;
    const planIds = [...document.querySelectorAll('#couponPlanChecks .coupon-plan-check:checked')].map(el => el.value);

    if (!/^[A-Z0-9_-]{3,32}$/.test(code)) {
      this.showToast('Coupon code must be 3-32 letters, digits, - or _.', '⚠️', 'warning');
      return;
    }
    if (!Number.isFinite(value) || value <= 0) {
      this.showToast('Enter a benefit value greater than 0.', '⚠️', 'warning');
      return;
    }
    if (type === 'percentage' && value > 100) {
      this.showToast('A percentage discount cannot be more than 100%.', '⚠️', 'warning');
      return;
    }
    if (startDate && expiryDate && startDate > expiryDate) {
      this.showToast('The start date must be on or before the expiry date.', '⚠️', 'warning');
      return;
    }
    if (!existing && this.coupons.some(c => c.code === code)) {
      this.showToast(`A coupon with code "${code}" already exists.`, '⚠️', 'warning');
      return;
    }
    if (existing && existing.code !== code && Number(existing.usedCount || 0) > 0) {
      this.showToast('This code has already been used and cannot be renamed. Duplicate it instead.', '⚠️', 'warning');
      return;
    }

    const payload = {
      // Keeping the same id makes a rename an in-place update (no delete + re-create).
      id: existing ? existing.id : code,
      code,
      title: document.getElementById('couponTitle').value.trim(),
      type,
      value,
      minAmount: parseFloat(document.getElementById('couponMinOrder').value) || 0,
      maxUses: parseInt(document.getElementById('couponMaxUses').value, 10) || 100,
      expiryDate,
      startDate,
      billingCycle: document.getElementById('couponBillingCycle')?.value || 'any',
      planIds,
      description: document.getElementById('couponDescription').value.trim(),
      isActive: existing ? existing.isActive !== false : true,
    };
    const ok = await this.apiMutate('/api/platform/coupon', payload);
    if (!ok) return;
    this.closeCouponModal();
    await this.fetchPlatformState(true);
    this.showToast(`Coupon "${code}" ${existing ? 'updated' : 'published'}.`, existing ? '✏️' : '🎉');
  }

  async toggleCouponStatus(couponId) {
    const c = this.coupons.find(x => x.id === couponId);
    if (!c) return;
    const activate = c.isActive === false || c.isPaused === true;
    const { usedCount, status, ...stored } = c;
    const ok = await this.apiMutate('/api/platform/coupon', { ...stored, isActive: activate, isPaused: !activate });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`Coupon "${c.code}" ${activate ? 'activated' : 'paused'}.`);
  }

  async deleteCoupon(couponId) {
    const c = this.coupons.find(x => x.id === couponId);
    if (!c) return;
    const usedNote = Number(c.usedCount || 0) > 0 ? ` It has been used ${c.usedCount} time(s); its usage history stays in billing records.` : '';
    if (!confirm(`Permanently delete coupon "${c.code}"? Customers will no longer be able to redeem it.${usedNote}`)) return;
    const ok = await this.apiMutate(`/api/platform/coupon/${encodeURIComponent(c.code)}`, null, { method: 'DELETE' });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`Coupon "${c.code}" removed.`, '🗑️');
  }

  duplicateCoupon(couponId) {
    const c = this.coupons.find(x => x.id === couponId);
    if (!c) return;
    const base = `${c.code}_COPY`.slice(0, 32);
    let code = base;
    for (let i = 2; this.coupons.some(x => x.code === code); i++) code = `${base.slice(0, 29)}_${i}`;
    this.openCouponModal({
      ...c,
      id: '',
      code,
      sourceCode: c.code,
      title: c.title ? `${c.title} (Copy)` : '',
      usedCount: 0,
    }, 'duplicate');
  }

  async openCouponUsage(code) {
    const modal = document.getElementById('couponUsageModal');
    const body = document.getElementById('couponUsageBody');
    const title = document.getElementById('couponUsageTitle');
    if (!modal || !body) return;
    const esc = v => this.escapeHtml(v);
    if (title) title.textContent = `Usage: ${code}`;
    body.innerHTML = '<div style="padding:24px; text-align:center; color:var(--text-muted);">Loading…</div>';
    modal.classList.add('active');
    try {
      const res = await fetch(`/api/platform/coupon/${encodeURIComponent(code)}/usage`, { headers: this.getAuthHeaders() });
      const data = await res.json();
      if (!data.success) throw new Error(data.error || 'Could not load usage');
      const s = data.summary || {};
      const money = v => (v === null || v === undefined) ? '—' : `₹${Number(v).toLocaleString('en-IN', { maximumFractionDigits: 2 })}`;
      const when = v => v ? new Date(v).toLocaleString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' }) : '—';
      const STATUS = { paid: 'badge-active', pending: 'badge-warning', expired: 'badge-expired', cancelled: 'badge-expired' };
      const stat = (label, value) => `
        <div style="flex:1; min-width:120px; padding:10px 12px; border:1px solid var(--border); border-radius:10px;">
          <div style="font-size:11px; color:var(--text-muted); font-weight:600;">${label}</div>
          <div style="font-size:18px; font-weight:800; color:var(--text-main);">${value}</div>
        </div>`;
      body.innerHTML = `
        <div style="display:flex; flex-wrap:wrap; gap:10px; margin-bottom:14px;">
          ${stat('Redemptions', esc(s.redemptions ?? 0))}
          ${stat('Agencies', esc(s.agencies ?? 0))}
          ${stat('Revenue', money(s.revenue))}
          ${stat('Discount given', money(s.discountGiven))}
          ${stat('Uses left', s.remaining === null || s.remaining === undefined ? '—' : esc(s.remaining))}
        </div>
        ${s.pending ? `<div style="font-size:12px; color:var(--text-muted); margin-bottom:10px;">${esc(s.pending)} checkout(s) waiting for payment.</div>` : ''}
        ${(data.uses || []).length ? `
          <div class="table-responsive">
            <table>
              <thead><tr><th>Agency</th><th>Plan</th><th>Status</th><th>Paid</th><th>Saved</th><th>Date</th></tr></thead>
              <tbody>
                ${data.uses.map(u => `
                  <tr>
                    <td><strong>${esc(u.tenantName)}</strong></td>
                    <td>${esc(u.planName || '—')}<div style="font-size:11px; color:var(--text-muted);">${esc(u.billing || '')}</div></td>
                    <td><span class="badge ${STATUS[u.status] || 'badge-expired'}">${esc(u.status)}</span></td>
                    <td>${money(u.amountPaid)}</td>
                    <td>${money(u.discount)}</td>
                    <td style="font-size:12px;">${when(u.paidAt || u.createdAt)}</td>
                  </tr>`).join('')}
              </tbody>
            </table>
          </div>` : '<div style="padding:24px; text-align:center; color:var(--text-muted);">This coupon has not been used yet.</div>'}
      `;
    } catch (err) {
      body.innerHTML = `<div style="padding:24px; text-align:center; color:#DC2626;">${esc(err.message)}</div>`;
    }
  }

  closeCouponUsage() {
    document.getElementById('couponUsageModal')?.classList.remove('active');
  }

  downloadCSV(headers, rows, filename) {
    // Normalise every cell: unwrap pre-quoted values, neutralise spreadsheet
    // formula prefixes (=, +, -, @) and re-quote.
    const cell = v => {
      let str = v === null || v === undefined ? '' : String(v);
      if (/^".*"$/s.test(str)) str = str.slice(1, -1).replace(/""/g, '"');
      if (/^[=+\-@\t\r]/.test(str)) str = `'${str}`;
      return `"${str.replace(/"/g, '""')}"`;
    };
    const csvContent = '\uFEFF' + [headers.map(cell).join(','), ...rows.map(e => e.map(cell).join(','))].join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', filename);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  }

  exportCouponsCSV() {
    const headers = ['Code', 'Title', 'Type', 'Value', 'MinOrder', 'Plans', 'BillingCycle', 'UsedCount', 'MaxUses', 'StartDate', 'ValidUntil', 'Status'];
    const rows = (this.coupons || []).map(c => [
      c.code,
      c.title || '',
      c.type,
      c.value,
      c.minOrderValue ?? c.minAmount ?? 0,
      (c.planIds || []).length ? this.couponPlanNames(c.planIds).join(' + ') : 'All plans',
      c.billingCycle || 'any',
      c.usedCount || 0,
      c.maxUses,
      c.startDate || '',
      c.expiryDate || c.validUntil || 'No expiry',
      this.couponStatusOf(c).toUpperCase(),
    ]);
    this.downloadCSV(headers, rows, `salesarmy_coupons_${Date.now()}.csv`);
    this.showToast('Coupons CSV exported successfully!', '📥');
  }

  exportPrintersCSV() {
    const headers = ['OrderID', 'AgencyName', 'Proprietor', 'Phone', 'City', 'PrinterModel', 'Quantity', 'Amount', 'PaymentStatus', 'FulfillmentStatus', 'TrackingNumber', 'Carrier'];
    const rows = (this.printerOrders || []).map(o => [
      `"${o.id || o.orderId}"`,
      `"${o.tenantName || ''}"`,
      `"${o.ownerName || ''}"`,
      `"${o.phone || ''}"`,
      `"${o.city || ''}"`,
      `"${o.printerModel || '58mm Bluetooth Thermal POS'}"`,
      o.quantity || 1,
      o.amount || 2499,
      `"${o.paymentStatus || 'Paid'}"`,
      `"${o.fulfillmentStatus || 'Pending'}"`,
      `"${o.trackingNumber || ''}"`,
      `"${o.shippingCarrier || ''}"`
    ]);
    this.downloadCSV(headers, rows, `salesarmy_hardware_printers_${Date.now()}.csv`);
    this.showToast('Hardware printer orders exported as CSV!', '📥');
  }

  exportOrdersCSV() {
    const headers = ['OrderNumber', 'ShopName', 'OwnerName', 'Phone', 'Address', 'Salesman', 'Agency', 'Date', 'Subtotal', 'GST', 'GrandTotal', 'PaymentStatus', 'FulfillmentStatus'];
    const rows = (this.retailOrders || []).map(o => [
      `"${o.orderNumber || o.id}"`,
      `"${o.shopName || ''}"`,
      `"${o.ownerName || ''}"`,
      `"${o.phone || ''}"`,
      `"${o.address || ''}"`,
      `"${o.salesmanName || ''}"`,
      `"${o.tenantName || ''}"`,
      `"${o.orderDate || ''}"`,
      o.subtotal || 0,
      o.totalGst || 0,
      o.grandTotal || 0,
      `"${o.paymentStatus || 'Pending'}"`,
      `"${o.status || 'Pending'}"`
    ]);
    this.downloadCSV(headers, rows, `salesarmy_retail_orders_${Date.now()}.csv`);
    this.showToast('Retail orders exported as CSV!', '📥');
  }

  exportTenantsCSV() {
    const headers = ['TenantID', 'UniqueID', 'FirmName', 'Proprietor', 'Phone', 'City', 'SubscriptionPlan', 'Status', 'ExpiryDate', 'LifetimeOrders'];
    const rows = (this.tenants || []).map(t => [
      `"${t.id || t.tenantId}"`,
      `"${t.userId || ''}"`,
      `"${t.firmName || ''}"`,
      `"${t.ownerName || ''}"`,
      `"${t.phone || ''}"`,
      `"${t.city || ''}"`,
      `"${t.planName || ''}"`,
      `"${t.subscriptionStatus || ''}"`,
      `"${t.expiryDate || ''}"`,
      t.ordersCount || 0
    ]);
    this.downloadCSV(headers, rows, `salesarmy_agencies_${Date.now()}.csv`);
    this.showToast('Agencies exported as CSV!', '📥');
  }

  exportUsersCSV() {
    const headers = ['UserID', 'FullName', 'Email', 'Phone', 'Role', 'Agency', 'Status'];
    const rows = (this.users || []).map(u => [
      `"${u.id || u.uid}"`,
      `"${u.name || ''}"`,
      `"${u.email || ''}"`,
      `"${u.phone || ''}"`,
      `"${u.role || ''}"`,
      `"${u.tenantName || ''}"`,
      `"${u.status || 'active'}"`
    ]);
    this.downloadCSV(headers, rows, `salesarmy_platform_users_${Date.now()}.csv`);
    this.showToast('Platform users exported as CSV!', '📥');
  }

  // --- VIEW 3: Plans & Pricing Management ---
  // --- Helpers for Dynamic Plans & Hardware Interop ---
  getDefaultPrinterOption() {
    if (!this.printerOptions || this.printerOptions.length === 0) {
      return DEFAULT_PRINTER_OPTIONS[0];
    }
    return this.printerOptions.find(p => p.isDefault) || this.printerOptions[0];
  }

  getDefaultPrinterPrice() {
    return this.getDefaultPrinterOption()?.price || 2499;
  }

  getMobilePlansPayload() {
    const tiers = (this.plans?.tiers && this.plans.tiers.length) ? this.plans.tiers : DEFAULT_PLANS.tiers;
    return tiers.map(t => {
      const maxStaff = Number(t.maxStaff ?? t.maxUsers ?? 5);
      const maxOrders = Number(t.maxOrdersPerMonth ?? (t.maxShops ? t.maxShops * 10 : 200));
      const maxBranches = Number(t.maxBranches ?? (maxStaff > 15 ? 5 : 1));
      const monthly = Number(t.monthlyPrice || 399);
      const yearlyEquiv = Number(t.yearlyMonthlyEquivalent || Math.round(monthly * 0.8));
      return {
        id: t.id,
        name: t.name,
        monthlyPrice: monthly,
        yearlyMonthlyEquivalent: yearlyEquiv,
        annualPrice: yearlyEquiv * 12,
        maxStaff: maxStaff,
        maxOrdersPerMonth: maxOrders,
        maxBranches: maxBranches,
        tagline: t.tagline || t.badge || '',
        features: t.features || [],
        isPopular: t.isPopular === true || t.highlight === true,
      };
    });
  }

  syncPricingToFirestore() {
    if (!this.db) return;
    try {
      const startup = this.plans?.tiers?.find(t => t.id === 'startup');
      const grow = this.plans?.tiers?.find(t => t.id === 'grow');
      const enterprise = this.plans?.tiers?.find(t => t.id === 'enterprise');

      const pricingPayload = {
        monthlyPlanPrice: startup ? startup.monthlyPrice : (this.plans.silverPrice || 399),
        quarterlyPlanPrice: grow ? grow.monthlyPrice : (this.plans.goldPrice || 599),
        annualPlanPrice: enterprise ? enterprise.monthlyPrice : (this.plans.platinumPrice || 899),
        startupMonthlyPrice: startup ? startup.monthlyPrice : 399,
        growMonthlyPrice: grow ? grow.monthlyPrice : 599,
        enterpriseMonthlyPrice: enterprise ? enterprise.monthlyPrice : 899,
        printerHardwarePrice: this.getDefaultPrinterPrice(),
        planGstRate: this.plans.planGst || 18,
        printerGstRate: this.plans.printerGst || 18,
        plans: this.getMobilePlansPayload(),
        printerOptions: this.printerOptions || DEFAULT_PRINTER_OPTIONS,
        updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
      };

      this.db.collection('platform_settings').doc('pricing_and_plans').set(pricingPayload, { merge: true });
      this.db.collection('platformSettings').doc('pricing_and_plans').set(pricingPayload, { merge: true });
    } catch (err) {
      console.warn('Firestore pricing sync error:', err);
    }
  }

  // --- VIEW 3: Plans & Pricing Management ---
  renderPlansGrid() {
    const container = document.getElementById('plansContainer');
    if (!container) return;

    if (!this.plans.tiers || this.plans.tiers.length === 0) {
      this.plans.tiers = JSON.parse(JSON.stringify(DEFAULT_PLANS.tiers));
    }

    const defaultPrinter = this.getDefaultPrinterOption();
    const defaultPrinterPrice = defaultPrinter?.price || 2499;

    container.innerHTML = this.plans.tiers.map(tier => {
      const isPopular = tier.isPopular === true || tier.highlight === true;
      const annualTotal = (tier.yearlyMonthlyEquivalent || tier.monthlyPrice) * 12;
      const maxStaff = tier.maxStaff ?? tier.maxUsers ?? 5;
      const rawOrders = tier.maxOrdersPerMonth ?? (tier.maxShops ? tier.maxShops * 10 : 200);
      const ordersDisplay = typeof rawOrders === 'number'
        ? (rawOrders >= 900000 ? 'Unlimited' : rawOrders.toLocaleString('en-IN'))
        : (rawOrders || '200+');
      const maxBranches = tier.maxBranches ?? (maxStaff > 15 ? 5 : 1);
      const defaultPrinterName = defaultPrinter?.name || '58mm Standard Bluetooth POS Thermal Printer';

      return `
        <div class="plan-card ${isPopular ? 'featured' : ''}">
          ${isPopular ? '<div class="plan-badge">Most Popular</div>' : ''}
          <div class="plan-name">${this.escapeHtml(tier.name)}</div>
          <div class="plan-price">
            ₹${tier.monthlyPrice} <span>/ month</span>
            <div style="font-size: 11.5px; font-weight: normal; color: #059669; margin-top: 4px;">
              ₹${tier.yearlyMonthlyEquivalent}/mo billed yearly (₹${annualTotal}/yr)
            </div>
          </div>
          <p style="font-size: 12px; color: #64748B; margin-bottom: 12px;">${this.escapeHtml(tier.tagline || tier.badge || '')}</p>
          <ul class="plan-features">
            <li>✓ <strong>${maxStaff >= 900 ? 'Unlimited' : 'Up to ' + maxStaff} Staff Logins</strong></li>
            <li>✓ <strong>${ordersDisplay} Orders / Mo</strong></li>
            <li>✓ <strong>${maxBranches >= 900 ? 'Unlimited' : maxBranches} Branch Locations</strong></li>
            ${(tier.features || []).map(f => `<li>✓ ${this.escapeHtml(f)}</li>`).join('')}
          </ul>
          <div class="printer-bundle-box">
            <div>
              <strong style="font-size: 12px; color: #1E3A8A;">Optional Hardware</strong>
              <div style="font-size: 11px; color: #64748B;">${this.escapeHtml(defaultPrinterName)}</div>
            </div>
            <strong style="font-size: 12px; color: #1D4ED8;">+₹${defaultPrinterPrice}</strong>
          </div>
          <div style="margin-top: 14px; padding-top: 12px; border-top: 1px solid var(--border);">
            <button class="btn btn-sm btn-outline" style="width: 100%; justify-content: center;" onclick="adminApp.openPlanEditModal('${tier.id}')">
              ✏️ Edit Tier Pricing & Features
            </button>
          </div>
        </div>
      `;
    }).join('');
  }

  // --- Dynamic POS Thermal Printers Catalog Grid ---
  renderPrintersGrid() {
    const container = document.getElementById('printersContainer');
    if (!container) return;

    if (!this.printerOptions || this.printerOptions.length === 0) {
      this.printerOptions = JSON.parse(JSON.stringify(DEFAULT_PRINTER_OPTIONS));
    }

    container.innerHTML = this.printerOptions.map(p => {
      const isDefault = p.isDefault === true;
      const isAvail = p.isAvailable !== false;
      return `
        <div class="plan-card ${isDefault ? 'featured' : ''}" style="border: 1px solid ${isDefault ? '#2563EB' : 'var(--border)'};">
          ${isDefault ? '<div class="plan-badge">Default Recommended</div>' : ''}
          <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 8px;">
            <div style="font-size: 28px;">🖨️</div>
            <div style="display: flex; gap: 6px; flex-wrap: wrap; justify-content: flex-end;">
              <span class="badge ${isAvail ? 'badge-active' : 'badge-expired'}">${isAvail ? 'In Stock' : 'Out of Stock'}</span>
              <span class="badge badge-flat">${this.escapeHtml(p.paperWidth || '58mm')}</span>
            </div>
          </div>
          <div class="plan-name" style="margin-top: 10px; font-size: 15.5px; line-height: 1.3;">${this.escapeHtml(p.name)}</div>
          <div class="plan-price" style="margin: 10px 0;">₹${p.price} <span style="font-size: 12px; font-weight: normal; color: #64748B;">+ ${p.gstRate || 18}% GST</span></div>
          <p style="font-size: 12px; color: #64748B; margin-bottom: 12px; min-height: 32px;">${this.escapeHtml(p.description || 'Wireless ESC/POS thermal printer.')}</p>
          <div style="font-size: 11px; color: #475569; margin-bottom: 8px;">
            <strong>Connectivity:</strong> ${this.escapeHtml(p.connectivity || 'Bluetooth')}
          </div>
          <ul class="plan-features" style="margin-top: 0; margin-bottom: 16px;">
            ${(p.features || []).map(f => `<li>✓ ${this.escapeHtml(f)}</li>`).join('')}
          </ul>
          <div style="margin-top: auto; padding-top: 14px; border-top: 1px solid var(--border); display: flex; gap: 8px; flex-wrap: wrap;">
            <button class="btn btn-sm ${isAvail ? 'btn-outline' : 'btn-primary'}" onclick="adminApp.togglePrinterStock('${p.id}')">
              ${isAvail ? 'Mark Out of Stock' : 'Mark In Stock'}
            </button>
            ${!isDefault ? `<button class="btn btn-sm btn-outline" onclick="adminApp.setDefaultPrinterOption('${p.id}')">Set Default</button>` : ''}
            <button class="btn btn-sm btn-outline" onclick="adminApp.openPrinterOptionModal('${p.id}')">✏️ Edit</button>
            ${this.printerOptions.length > 1 ? `<button class="btn btn-sm btn-outline" style="color: #EF4444; border-color: #FECACA;" onclick="adminApp.deletePrinterOption('${p.id}')">🗑️</button>` : ''}
          </div>
        </div>
      `;
    }).join('');
  }

  // --- Multi-Tier Subscription Plans & Feature Controls ---
  switchPlanTab(tabKey) {
    const tabs = ['startup', 'grow', 'enterprise', 'taxes'];
    tabs.forEach(t => {
      const btn = document.getElementById('tabBtn' + t.charAt(0).toUpperCase() + t.slice(1));
      const pane = document.getElementById('pane' + t.charAt(0).toUpperCase() + t.slice(1));
      if (btn) btn.classList.toggle('active', t === tabKey);
      if (pane) pane.style.display = t === tabKey ? 'block' : 'none';
    });
    const tracker = document.getElementById('activePlanTab');
    if (tracker) tracker.value = tabKey;
  }

  handlePopularPlanToggle(selectedTier) {
    ['startup', 'grow', 'enterprise'].forEach(t => {
      const chk = document.getElementById('cfg' + t.charAt(0).toUpperCase() + t.slice(1) + 'Popular');
      if (chk) chk.checked = (t === selectedTier);
    });
  }

  autoCalcYearly(tierKey) {
    const keyCap = tierKey.charAt(0).toUpperCase() + tierKey.slice(1);
    const mInput = document.getElementById('cfg' + keyCap + 'Price');
    const yInput = document.getElementById('cfg' + keyCap + 'YearlyPrice');
    if (mInput && yInput) {
      const m = parseFloat(mInput.value) || 0;
      yInput.value = Math.round(m * 0.8);
    }
  }

  renderCapabilityCheckboxes(tierId, selectedKeys) {
    const container = document.getElementById(`cfg${tierId.charAt(0).toUpperCase() + tierId.slice(1)}AllowedFeatures`);
    if (!container) return;
    const selected = new Set(Array.isArray(selectedKeys) ? selectedKeys : []);
    container.innerHTML = CAPABILITY_CATALOG.map(cap => `
      <label style="display:flex;align-items:center;gap:6px;font-size:12px;cursor:pointer;line-height:1.3;">
        <input type="checkbox" data-tier="${tierId}" data-cap="${cap.key}" ${selected.has(cap.key) ? 'checked' : ''}>
        <span><strong style="color:var(--text-main);">${cap.label}</strong><br><span style="color:var(--text-muted);font-size:10.5px;">${cap.group} · ${cap.key}</span></span>
      </label>
    `).join('');
  }

  collectAllowedFeatures(tierId) {
    const container = document.getElementById(`cfg${tierId.charAt(0).toUpperCase() + tierId.slice(1)}AllowedFeatures`);
    if (!container) return [];
    return Array.from(container.querySelectorAll('input[type="checkbox"]:checked')).map(cb => cb.getAttribute('data-cap'));
  }

  openPlanEditModal(selectedTier = 'startup') {
    if (!this.plans.tiers || this.plans.tiers.length === 0) {
      this.plans.tiers = JSON.parse(JSON.stringify(DEFAULT_PLANS.tiers));
    }
    const startup = this.plans.tiers.find(t => t.id === 'startup') || this.plans.tiers[0];
    const grow = this.plans.tiers.find(t => t.id === 'grow') || this.plans.tiers[1];
    const enterprise = this.plans.tiers.find(t => t.id === 'enterprise') || this.plans.tiers[2];

    const setVal = (id, val) => { const el = document.getElementById(id); if (el) el.value = val ?? ''; };
    for (const [key, tier, dProd, dShops] of [['Startup', startup, 50, 200], ['Grow', grow, 200, 1000], ['Enterprise', enterprise, 0, 10000]]) {
      setVal(`cfg${key}MaxProducts`, tier.maxProducts ?? dProd);
      setVal(`cfg${key}MaxShops`, tier.maxShops ?? dShops);
    }
    const setChecked = (id, val) => { const el = document.getElementById(id); if (el) el.checked = !!val; };

    // Startup
    setVal('cfgStartupName', startup.name || 'Startup Plan');
    setVal('cfgStartupTagline', startup.tagline || '');
    setVal('cfgStartupPrice', startup.monthlyPrice ?? 399);
    setVal('cfgStartupYearlyPrice', startup.yearlyMonthlyEquivalent ?? 319);
    setVal('cfgStartupMaxStaff', startup.maxStaff ?? 2);
    setVal('cfgStartupMaxOrders', startup.maxOrdersPerMonth ?? 200);
    setVal('cfgStartupMaxBranches', startup.maxBranches ?? 1);
    setVal('cfgStartupFeatures', (startup.features || []).join('\n'));
    setChecked('cfgStartupPopular', startup.isPopular);

    // Grow
    setVal('cfgGrowName', grow.name || 'Grow Plan');
    setVal('cfgGrowTagline', grow.tagline || '');
    setVal('cfgGrowPrice', grow.monthlyPrice ?? 599);
    setVal('cfgGrowYearlyPrice', grow.yearlyMonthlyEquivalent ?? 479);
    setVal('cfgGrowMaxStaff', grow.maxStaff ?? 10);
    setVal('cfgGrowMaxOrders', grow.maxOrdersPerMonth ?? 1000);
    setVal('cfgGrowMaxBranches', grow.maxBranches ?? 3);
    setVal('cfgGrowFeatures', (grow.features || []).join('\n'));
    setChecked('cfgGrowPopular', grow.isPopular);

    // Enterprise
    setVal('cfgEnterpriseName', enterprise.name || 'Enterprise Plan');
    setVal('cfgEnterpriseTagline', enterprise.tagline || '');
    setVal('cfgEnterprisePrice', enterprise.monthlyPrice ?? 899);
    setVal('cfgEnterpriseYearlyPrice', enterprise.yearlyMonthlyEquivalent ?? 719);
    setVal('cfgEnterpriseMaxStaff', enterprise.maxStaff ?? 999);
    setVal('cfgEnterpriseMaxOrders', enterprise.maxOrdersPerMonth ?? 999999);
    setVal('cfgEnterpriseMaxBranches', enterprise.maxBranches ?? 10);
    setVal('cfgEnterpriseFeatures', (enterprise.features || []).join('\n'));
    setChecked('cfgEnterprisePopular', enterprise.isPopular);

    // Taxes
    setVal('cfgPlanGst', this.plans.planGst || 18);
    setVal('cfgPrinterGst', this.plans.printerGst || 18);

    // Dynamic capability checkboxes per tier
    this.renderCapabilityCheckboxes('startup', startup.allowedFeatures || []);
    this.renderCapabilityCheckboxes('grow', grow.allowedFeatures || []);
    this.renderCapabilityCheckboxes('enterprise', enterprise.allowedFeatures || []);

    this.switchPlanTab(selectedTier || 'startup');
    document.getElementById('planEditModal')?.classList.add('active');
  }

  closePlanEditModal() {
    document.getElementById('planEditModal')?.classList.remove('active');
  }

  handleSavePlanSettings(e) {
    e.preventDefault();
    if (!this.plans.tiers || this.plans.tiers.length === 0) {
      this.plans.tiers = JSON.parse(JSON.stringify(DEFAULT_PLANS.tiers));
    }

    // Limits: 0 = unlimited (parseInt(..) || default would turn 0 back into the default).
    const readLimit = (id, dflt) => {
      const raw = document.getElementById(id)?.value;
      const n = parseInt(raw, 10);
      return Number.isInteger(n) && n >= 0 ? n : dflt;
    };
    const parseFeatures = (val) => (val || '')
      .split('\n')
      .map(s => s.replace(/^[•✓\-\*]\s*/, '').trim())
      .filter(s => s.length > 0);

    // 1. Startup Plan
    const startup = this.plans.tiers.find(t => t.id === 'startup') || {};
    startup.name = document.getElementById('cfgStartupName')?.value.trim() || 'Startup Plan';
    startup.tagline = document.getElementById('cfgStartupTagline')?.value.trim() || '';
    startup.monthlyPrice = parseFloat(document.getElementById('cfgStartupPrice')?.value) || 399;
    startup.yearlyMonthlyEquivalent = parseFloat(document.getElementById('cfgStartupYearlyPrice')?.value) || Math.round(startup.monthlyPrice * 0.8);
    startup.annualPrice = startup.yearlyMonthlyEquivalent * 12;
    startup.yearlyPrice = startup.annualPrice; // server reads yearlyPrice first — keep both in step
    startup.maxStaff = readLimit('cfgStartupMaxStaff', 2);
    startup.maxUsers = startup.maxStaff;
    startup.maxOrdersPerMonth = readLimit('cfgStartupMaxOrders', 200);
    startup.maxBranches = readLimit('cfgStartupMaxBranches', 1);
    startup.maxProducts = readLimit('cfgStartupMaxProducts', 50);
    startup.maxShops = readLimit('cfgStartupMaxShops', 200);
    startup.isPopular = document.getElementById('cfgStartupPopular')?.checked || false;
    const startupFeats = parseFeatures(document.getElementById('cfgStartupFeatures')?.value);
    if (startupFeats.length > 0) startup.features = startupFeats;
    startup.allowedFeatures = this.collectAllowedFeatures('startup');
    startup.featuresVersion = 2;

    // 2. Grow Plan
    const grow = this.plans.tiers.find(t => t.id === 'grow') || {};
    grow.name = document.getElementById('cfgGrowName')?.value.trim() || 'Grow Plan';
    grow.tagline = document.getElementById('cfgGrowTagline')?.value.trim() || '';
    grow.monthlyPrice = parseFloat(document.getElementById('cfgGrowPrice')?.value) || 599;
    grow.yearlyMonthlyEquivalent = parseFloat(document.getElementById('cfgGrowYearlyPrice')?.value) || Math.round(grow.monthlyPrice * 0.8);
    grow.annualPrice = grow.yearlyMonthlyEquivalent * 12;
    grow.yearlyPrice = grow.annualPrice; // server reads yearlyPrice first — keep both in step
    grow.maxStaff = readLimit('cfgGrowMaxStaff', 10);
    grow.maxUsers = grow.maxStaff;
    grow.maxOrdersPerMonth = readLimit('cfgGrowMaxOrders', 1000);
    grow.maxBranches = readLimit('cfgGrowMaxBranches', 3);
    grow.maxProducts = readLimit('cfgGrowMaxProducts', 200);
    grow.maxShops = readLimit('cfgGrowMaxShops', 1000);
    grow.isPopular = document.getElementById('cfgGrowPopular')?.checked || false;
    const growFeats = parseFeatures(document.getElementById('cfgGrowFeatures')?.value);
    if (growFeats.length > 0) grow.features = growFeats;
    grow.allowedFeatures = this.collectAllowedFeatures('grow');
    grow.featuresVersion = 2;

    // 3. Enterprise Plan
    const enterprise = this.plans.tiers.find(t => t.id === 'enterprise') || {};
    enterprise.name = document.getElementById('cfgEnterpriseName')?.value.trim() || 'Enterprise Plan';
    enterprise.tagline = document.getElementById('cfgEnterpriseTagline')?.value.trim() || '';
    enterprise.monthlyPrice = parseFloat(document.getElementById('cfgEnterprisePrice')?.value) || 899;
    enterprise.yearlyMonthlyEquivalent = parseFloat(document.getElementById('cfgEnterpriseYearlyPrice')?.value) || Math.round(enterprise.monthlyPrice * 0.8);
    enterprise.annualPrice = enterprise.yearlyMonthlyEquivalent * 12;
    enterprise.yearlyPrice = enterprise.annualPrice; // server reads yearlyPrice first — keep both in step
    enterprise.maxStaff = readLimit('cfgEnterpriseMaxStaff', 999);
    enterprise.maxUsers = enterprise.maxStaff;
    enterprise.maxOrdersPerMonth = readLimit('cfgEnterpriseMaxOrders', 999999);
    enterprise.maxBranches = readLimit('cfgEnterpriseMaxBranches', 10);
    enterprise.maxProducts = readLimit('cfgEnterpriseMaxProducts', 0);
    enterprise.maxShops = readLimit('cfgEnterpriseMaxShops', 10000);
    enterprise.isPopular = document.getElementById('cfgEnterprisePopular')?.checked || false;
    const enterpriseFeats = parseFeatures(document.getElementById('cfgEnterpriseFeatures')?.value);
    if (enterpriseFeats.length > 0) enterprise.features = enterpriseFeats;
    enterprise.allowedFeatures = this.collectAllowedFeatures('enterprise');
    enterprise.featuresVersion = 2;

    this.plans.silverPrice = startup.monthlyPrice;
    this.plans.goldPrice = grow.monthlyPrice;
    this.plans.platinumPrice = enterprise.monthlyPrice;
    this.plans.planGst = parseFloat(document.getElementById('cfgPlanGst')?.value) || 18;
    this.plans.printerGst = parseFloat(document.getElementById('cfgPrinterGst')?.value) || 18;

    this.saveData(STORAGE_KEYS.PLANS, this.plans);
    // Cloud sync is handled server-side by /api/platform/update (service_role).
    // Direct Supabase writes from the browser use the anon key, which RLS
    // policy `tenant_settings` blocks for `pricing_and_plans` — leaving a
    // misleading "Cloud write failed" toast even though the bridge write
    // succeeded. Rely on saveToBridge for cloud propagation.
    this.closePlanEditModal();
    this.renderPlansGrid();
    this.saveToBridge({ plans: this.plans }).then(ok => {
      if (ok) {
        this.showToast('Plans saved & pushed to all mobile devices.', '⚙️');
      } else {
        this.showToast('Saved locally — cloud bridge unreachable, retry when online.', '⚠️');
      }
    });
  }

  resetPlansToDefault() {
    if (confirm('Reset all plan rates and features to default seed values?')) {
      this.plans = JSON.parse(JSON.stringify(DEFAULT_PLANS));
      this.saveData(STORAGE_KEYS.PLANS, this.plans);
      this.renderPlansGrid();
      this.saveToBridge({ plans: this.plans }).then(ok => {
        this.showToast(ok ? 'Plans reset and synced to mobile.' : 'Plans reset locally (cloud unreachable).');
      });
    }
  }

  // --- Dynamic POS Printer Management Methods ---
  openPrinterOptionModal(printerId = null) {
    const title = document.getElementById('printerOptionModalTitle');
    const idInput = document.getElementById('cfgPrinterOptId');
    const nameInput = document.getElementById('cfgPrinterOptName');
    const priceInput = document.getElementById('cfgPrinterOptPrice');
    const gstInput = document.getElementById('cfgPrinterOptGst');
    const widthInput = document.getElementById('cfgPrinterOptWidth');
    const connInput = document.getElementById('cfgPrinterOptConnectivity');
    const descInput = document.getElementById('cfgPrinterOptDesc');
    const featsInput = document.getElementById('cfgPrinterOptFeatures');
    const availCheck = document.getElementById('cfgPrinterOptAvailable');
    const defCheck = document.getElementById('cfgPrinterOptDefault');

    if (printerId) {
      const p = this.printerOptions.find(x => x.id === printerId);
      if (p) {
        if (title) title.textContent = 'Edit POS Printer Model';
        if (idInput) idInput.value = p.id;
        if (nameInput) nameInput.value = p.name;
        if (priceInput) priceInput.value = p.price;
        if (gstInput) gstInput.value = p.gstRate || 18;
        if (widthInput) widthInput.value = p.paperWidth || '58mm (2-inch)';
        if (connInput) connInput.value = p.connectivity || 'Bluetooth + USB';
        if (descInput) descInput.value = p.description || '';
        if (featsInput) featsInput.value = (p.features || []).join(', ');
        if (availCheck) availCheck.checked = p.isAvailable !== false;
        if (defCheck) defCheck.checked = p.isDefault === true;
      }
    } else {
      if (title) title.textContent = 'Add New POS Printer Model';
      if (idInput) idInput.value = '';
      if (nameInput) nameInput.value = '';
      if (priceInput) priceInput.value = 2499;
      if (gstInput) gstInput.value = 18;
      if (widthInput) widthInput.value = '58mm (2-inch)';
      if (connInput) connInput.value = 'Bluetooth + USB';
      if (descInput) descInput.value = '';
      if (featsInput) featsInput.value = 'Fast print speed, Drop-in paper loading, Long battery life';
      if (availCheck) availCheck.checked = true;
      if (defCheck) defCheck.checked = false;
    }

    document.getElementById('printerOptionModal')?.classList.add('active');
  }

  closePrinterOptionModal() {
    document.getElementById('printerOptionModal')?.classList.remove('active');
  }

  handleSavePrinterOption(e) {
    e.preventDefault();
    const id = document.getElementById('cfgPrinterOptId')?.value.trim();
    const name = document.getElementById('cfgPrinterOptName')?.value.trim();
    const price = parseFloat(document.getElementById('cfgPrinterOptPrice')?.value) || 2499;
    const gstRate = parseFloat(document.getElementById('cfgPrinterOptGst')?.value) || 18;
    const paperWidth = document.getElementById('cfgPrinterOptWidth')?.value.trim() || '58mm (2-inch)';
    const connectivity = document.getElementById('cfgPrinterOptConnectivity')?.value.trim() || 'Bluetooth + USB';
    const description = document.getElementById('cfgPrinterOptDesc')?.value.trim() || '';
    const featsRaw = document.getElementById('cfgPrinterOptFeatures')?.value.trim() || '';
    const features = featsRaw ? featsRaw.split(',').map(s => s.trim()).filter(Boolean) : [];
    const isAvailable = document.getElementById('cfgPrinterOptAvailable')?.checked ?? true;
    const isDefault = document.getElementById('cfgPrinterOptDefault')?.checked ?? false;

    if (!name) {
      alert('Please specify a printer model name.');
      return;
    }

    if (!this.printerOptions) {
      this.printerOptions = JSON.parse(JSON.stringify(DEFAULT_PRINTER_OPTIONS));
    }

    if (isDefault) {
      this.printerOptions.forEach(p => p.isDefault = false);
    }

    if (id) {
      const idx = this.printerOptions.findIndex(p => p.id === id);
      if (idx !== -1) {
        this.printerOptions[idx] = {
          ...this.printerOptions[idx],
          name,
          price,
          gstRate,
          paperWidth,
          connectivity,
          description,
          features,
          isAvailable,
          isDefault,
        };
      }
      this.showToast(`Updated "${name}" model!`, '🖨️');
    } else {
      const newPrinter = {
        id: 'printer_' + Date.now(),
        name,
        price,
        gstRate,
        paperWidth,
        connectivity,
        description,
        features,
        isAvailable,
        isDefault,
      };
      this.printerOptions.push(newPrinter);
      this.showToast(`Added new printer "${name}"!`, '🎉');
    }

    // Ensure at least one printer is default
    if (!this.printerOptions.some(p => p.isDefault)) {
      this.printerOptions[0].isDefault = true;
    }

    this.saveData(STORAGE_KEYS.PRINTER_OPTIONS, this.printerOptions);
    this.saveToBridge({ printerOptions: this.printerOptions });
    this.closePrinterOptionModal();
    this.renderPlansGrid();
    this.renderPrintersGrid();
    this.renderAddonsGrid();
    this.populatePrinterOrderSelects();
  }

  togglePrinterStock(printerId) {
    const p = this.printerOptions.find(x => x.id === printerId);
    if (p) {
      p.isAvailable = !p.isAvailable;
      this.saveData(STORAGE_KEYS.PRINTER_OPTIONS, this.printerOptions);
      this.saveToBridge({ printerOptions: this.printerOptions });
      this.renderPrintersGrid();
      this.populatePrinterOrderSelects();
      this.showToast(`Printer "${p.name}" marked as ${p.isAvailable ? 'In Stock' : 'Out of Stock'}.`);
    }
  }

  setDefaultPrinterOption(printerId) {
    this.printerOptions.forEach(p => {
      p.isDefault = (p.id === printerId);
    });
    this.saveData(STORAGE_KEYS.PRINTER_OPTIONS, this.printerOptions);
    this.saveToBridge({ printerOptions: this.printerOptions });
    this.renderPlansGrid();
    this.renderPrintersGrid();
    this.renderAddonsGrid();
    this.showToast('Updated default recommended POS printer!', '⭐');
  }

  deletePrinterOption(printerId) {
    const p = this.printerOptions.find(x => x.id === printerId);
    if (!p) return;
    if (confirm(`Are you sure you want to delete printer model "${p.name}"?`)) {
      this.printerOptions = this.printerOptions.filter(x => x.id !== printerId);
      if (!this.printerOptions.some(x => x.isDefault) && this.printerOptions.length > 0) {
        this.printerOptions[0].isDefault = true;
      }
      this.saveData(STORAGE_KEYS.PRINTER_OPTIONS, this.printerOptions);
      this.saveToBridge({ printerOptions: this.printerOptions });
      this.renderPlansGrid();
      this.renderPrintersGrid();
      this.populatePrinterOrderSelects();
      this.showToast(`Deleted "${p.name}".`, '🗑️');
    }
  }

  resetPrintersToDefault() {
    if (confirm('Reset POS printer catalog back to default seed models?')) {
      this.printerOptions = JSON.parse(JSON.stringify(DEFAULT_PRINTER_OPTIONS));
      this.saveData(STORAGE_KEYS.PRINTER_OPTIONS, this.printerOptions);
      this.saveToBridge({ printerOptions: this.printerOptions });
      this.renderPlansGrid();
      this.renderPrintersGrid();
      this.populatePrinterOrderSelects();
      this.showToast('Printer catalog reset to defaults.');
    }
  }

  // --- Dynamic Subscription Add-ons Management ---
  renderAddonsGrid() {
    const container = document.getElementById('addonsContainer');
    if (!container) return;

    if (!this.subscriptionAddons || this.subscriptionAddons.length === 0) {
      this.subscriptionAddons = JSON.parse(JSON.stringify(DEFAULT_ADDONS));
    }

    const categoryIcons = {
      seats: '👥',
      directory: '🏪',
      notifications: '💬',
      supplies: '📦',
      hardware: '📟',
      support: '🛡️',
      integration: '⚡'
    };

    const categoryLabels = {
      seats: 'Staff & Seats',
      directory: 'Shop Directory',
      notifications: 'WhatsApp & SMS',
      supplies: 'Consumables',
      hardware: 'Hardware',
      support: 'VIP Support',
      integration: 'Integration'
    };

    container.innerHTML = this.subscriptionAddons.map(a => {
      const isAvail = a.isAvailable !== false && a.isActive !== false;
      const cat = (a.category || 'seats').toLowerCase();
      const icon = categoryIcons[cat] || '✨';
      const catLabel = categoryLabels[cat] || (cat.charAt(0).toUpperCase() + cat.slice(1));
      const periodLabel = a.period === 'one_time' ? '(One-Time)' : (a.period === 'yearly' ? '/ yr' : '/ mo');
      const title = a.title || a.name || 'Subscription Add-on';

      return `
        <div class="plan-card" style="border: 1px solid var(--border);">
          <div style="display: flex; align-items: flex-start; justify-content: space-between; gap: 8px;">
            <div style="font-size: 28px;">${icon}</div>
            <div style="display: flex; gap: 6px; flex-wrap: wrap; justify-content: flex-end;">
              <span class="badge ${isAvail ? 'badge-active' : 'badge-expired'}">${isAvail ? 'Active' : 'Inactive'}</span>
              <span class="badge badge-flat">${this.escapeHtml(catLabel)}</span>
            </div>
          </div>
          <div class="plan-name" style="margin-top: 10px; font-size: 15.5px; line-height: 1.3;">${this.escapeHtml(title)}</div>
          <div class="plan-price" style="margin: 10px 0;">₹${Number(a.price || 0).toLocaleString('en-IN')} <span style="font-size: 12px; font-weight: normal; color: #64748B;">${periodLabel} + ${a.gstRate || 18}% GST</span></div>
          <p style="font-size: 12px; color: #64748B; margin-bottom: 12px; min-height: 32px;">${this.escapeHtml(a.description || 'Platform add-on license.')}</p>
          <ul class="plan-features" style="margin-top: 0; margin-bottom: 16px;">
            ${(a.features || []).map(f => `<li>✓ ${this.escapeHtml(f)}</li>`).join('')}
          </ul>
          <div style="margin-top: auto; padding-top: 14px; border-top: 1px solid var(--border); display: flex; gap: 8px; flex-wrap: wrap;">
            <button class="btn btn-sm ${isAvail ? 'btn-outline' : 'btn-primary'}" onclick="adminApp.toggleAddonAvailability('${a.id}')">
              ${isAvail ? 'Deactivate' : 'Activate'}
            </button>
            <button class="btn btn-sm btn-outline" onclick="adminApp.openAddonModal('${a.id}')">✏️ Edit</button>
            ${this.subscriptionAddons.length > 1 ? `<button class="btn btn-sm btn-outline" style="color: #EF4444; border-color: #FECACA;" onclick="adminApp.deleteAddon('${a.id}')">🗑️</button>` : ''}
          </div>
        </div>
      `;
    }).join('');
  }

  openAddonModal(addonId = null) {
    const title = document.getElementById('addonOptionModalTitle');
    const idInput = document.getElementById('cfgAddonId');
    const titleInput = document.getElementById('cfgAddonTitle');
    const priceInput = document.getElementById('cfgAddonPrice');
    const gstInput = document.getElementById('cfgAddonGst');
    const catInput = document.getElementById('cfgAddonCategory');
    const periodInput = document.getElementById('cfgAddonPeriod');
    const descInput = document.getElementById('cfgAddonDesc');
    const featsInput = document.getElementById('cfgAddonFeatures');
    const availCheck = document.getElementById('cfgAddonAvailable');

    if (addonId) {
      const a = this.subscriptionAddons.find(x => x.id === addonId);
      if (a) {
        if (title) title.textContent = 'Edit Subscription Add-on';
        if (idInput) idInput.value = a.id;
        if (titleInput) titleInput.value = a.title || a.name || '';
        if (priceInput) priceInput.value = a.price || 0;
        if (gstInput) gstInput.value = a.gstRate !== undefined ? a.gstRate : 18;
        if (catInput) catInput.value = a.category || 'seats';
        if (periodInput) periodInput.value = a.period || 'monthly';
        if (descInput) descInput.value = a.description || '';
        if (featsInput) featsInput.value = (a.features || []).join(', ');
        if (availCheck) availCheck.checked = a.isAvailable !== false && a.isActive !== false;
      }
    } else {
      if (title) title.textContent = 'Add Subscription Add-on';
      if (idInput) idInput.value = '';
      if (titleInput) titleInput.value = '';
      if (priceInput) priceInput.value = 299;
      if (gstInput) gstInput.value = 18;
      if (catInput) catInput.value = 'seats';
      if (periodInput) periodInput.value = 'monthly';
      if (descInput) descInput.value = '';
      if (featsInput) featsInput.value = 'Fast instant activation, Multi-device sync, Dedicated support';
      if (availCheck) availCheck.checked = true;
    }

    document.getElementById('addonOptionModal')?.classList.add('active');
  }

  closeAddonModal() {
    document.getElementById('addonOptionModal')?.classList.remove('active');
  }

  handleSaveAddon(e) {
    e.preventDefault();
    const id = document.getElementById('cfgAddonId')?.value.trim();
    const title = document.getElementById('cfgAddonTitle')?.value.trim();
    const price = parseFloat(document.getElementById('cfgAddonPrice')?.value) || 0;
    const gstRate = parseFloat(document.getElementById('cfgAddonGst')?.value) || 18;
    const category = document.getElementById('cfgAddonCategory')?.value || 'seats';
    const period = document.getElementById('cfgAddonPeriod')?.value || 'monthly';
    const description = document.getElementById('cfgAddonDesc')?.value.trim() || '';
    const featsRaw = document.getElementById('cfgAddonFeatures')?.value.trim() || '';
    const features = featsRaw ? featsRaw.split(',').map(s => s.trim()).filter(Boolean) : [];
    const isAvailable = document.getElementById('cfgAddonAvailable')?.checked ?? true;

    if (!title) {
      alert('Please specify an add-on title.');
      return;
    }

    if (!this.subscriptionAddons) {
      this.subscriptionAddons = JSON.parse(JSON.stringify(DEFAULT_ADDONS));
    }

    let savedItem;
    if (id) {
      const idx = this.subscriptionAddons.findIndex(a => a.id === id);
      if (idx !== -1) {
        savedItem = {
          ...this.subscriptionAddons[idx],
          title,
          name: title,
          price,
          gstRate,
          category,
          period,
          description,
          features,
          isAvailable,
          isActive: isAvailable
        };
        this.subscriptionAddons[idx] = savedItem;
      }
      this.showToast(`Updated add-on "${title}"!`, '✨');
    } else {
      savedItem = {
        id: 'addon_' + Date.now(),
        title,
        name: title,
        price,
        gstRate,
        category,
        period,
        description,
        features,
        isAvailable,
        isActive: isAvailable
      };
      this.subscriptionAddons.push(savedItem);
      this.showToast(`Added new add-on "${title}"!`, '🎉');
    }

    this.saveData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, this.subscriptionAddons);
    this.saveToBridge({ subscriptionAddons: this.subscriptionAddons });
    this.syncPricingToSupabase();

    // Direct endpoint save for auditability
    try {
      fetch('/api/platform/subscription-addon', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', ...this.getAuthHeaders() },
        body: JSON.stringify(savedItem)
      }).catch(() => {});
    } catch (_) {}

    this.closeAddonModal();
    this.renderAddonsGrid();
  }

  toggleAddonAvailability(addonId) {
    const a = this.subscriptionAddons.find(x => x.id === addonId);
    if (a) {
      const next = !(a.isAvailable !== false && a.isActive !== false);
      a.isAvailable = next;
      a.isActive = next;
      this.saveData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, this.subscriptionAddons);
      this.saveToBridge({ subscriptionAddons: this.subscriptionAddons });
      this.syncPricingToSupabase();
      this.renderAddonsGrid();
      this.showToast(`Add-on "${a.title || a.name}" marked as ${next ? 'Active' : 'Inactive'}.`);
    }
  }

  deleteAddon(addonId) {
    const a = this.subscriptionAddons.find(x => x.id === addonId);
    if (!a) return;
    if (confirm(`Are you sure you want to delete add-on "${a.title || a.name}"?`)) {
      this.subscriptionAddons = this.subscriptionAddons.filter(x => x.id !== addonId);
      this.saveData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, this.subscriptionAddons);
      this.saveToBridge({ subscriptionAddons: this.subscriptionAddons });
      this.syncPricingToSupabase();
      try {
        fetch('/api/platform/subscription-addon/' + encodeURIComponent(addonId), {
          method: 'DELETE',
          headers: this.getAuthHeaders()
        }).catch(() => {});
      } catch (_) {}
      this.renderAddonsGrid();
      this.showToast(`Deleted "${a.title || a.name}".`, '🗑️');
    }
  }

  resetAddonsToDefault() {
    if (confirm('Reset subscription add-ons back to default catalog?')) {
      this.subscriptionAddons = JSON.parse(JSON.stringify(DEFAULT_ADDONS));
      this.saveData(STORAGE_KEYS.SUBSCRIPTION_ADDONS, this.subscriptionAddons);
      this.saveToBridge({ subscriptionAddons: this.subscriptionAddons });
      this.syncPricingToSupabase();
      this.renderAddonsGrid();
      this.showToast('Subscription add-ons reset to defaults.');
    }
  }

  // --- VIEW 4: Hardware / Printer Orders ---
  // Orders page shows subscriber hardware / supply orders only (client spec).
  switchOrderTab(tab = 'hardware') {
    const hardware = tab !== 'retail';
    const paneHw = document.getElementById('paneHardwareOrders');
    const paneRetail = document.getElementById('paneRetailOrders');
    if (paneHw) paneHw.style.display = hardware ? '' : 'none';
    if (paneRetail) paneRetail.style.display = hardware ? 'none' : '';
    document.getElementById('btnTabHardwareOrders')?.classList.toggle('btn-primary', hardware);
    document.getElementById('btnTabHardwareOrders')?.classList.toggle('btn-outline', !hardware);
    if (hardware) this.renderPrintersTable();
    else this.renderOrdersView();
  }

  renderHardwareOrderStats() {
    const orders = this.printerOrders || [];
    const st = o => String(o.status || '').toLowerCase();
    const setText = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
    setText('statHardwareGMV', this.formatRupees(orders.filter(o => st(o) !== 'cancelled').reduce((a, o) => a + Number(o.price || 0), 0)));
    setText('statHardwareOrdersCount', orders.length);
    setText('statHardwareDelivered', orders.filter(o => st(o) === 'delivered').length);
    setText('statHardwarePending', orders.filter(o => !['delivered', 'cancelled'].includes(st(o))).length);
  }

  renderPrintersTable() {
    this.renderHardwareOrderStats();
    const tbody = document.getElementById('printerOrdersTableBody');
    if (!tbody) return;
    const esc = v => this.escapeHtml(v);

    let list = this.printerOrders || [];

    if (this.printerFilter && this.printerFilter !== 'all') {
      list = list.filter(o => o.status === this.printerFilter);
    }

    if (this.printerSearch) {
      const q = this.printerSearch;
      list = list.filter(o => [o.id, o.customerName, o.agencyName, o.phone, o.trackingNumber, o.tenantId, o.printerItem, o.shippingAddress]
        .some(v => String(v || '').toLowerCase().includes(q)));
    }

    if (list.length === 0) {
      tbody.innerHTML = `<tr><td colspan="7" style="text-align: center; color: #64748B; padding: 36px;">No subscriber orders found.</td></tr>`;
      return;
    }

    const payBadge = { paid: 'badge-active', cod: 'badge-trial', pending: 'badge-warning', refunded: 'badge-expired' };
    tbody.innerHTML = list.map(order => {
      const d = order.orderedAt ? new Date(order.orderedAt) : null;
      const date = d && !isNaN(d) ? d.toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' }) : '—';
      const phone = String(order.phone || '').replace(/[^0-9]/g, '');
      const pay = String(order.paymentStatus || 'pending').toLowerCase();

      return `
        <tr>
          <td>
            <span class="code-pill">${esc(order.id)}</span>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 4px;">${esc(date)}</div>
          </td>
          <td>
            <strong style="color: var(--text-main); font-size: 13.5px; display: block;">${esc(order.agencyName || 'Subscriber')}</strong>
            <div style="font-size: 11.5px; color: var(--text-muted);">${esc(order.customerName || '')}</div>
            <div style="font-size: 11px; margin-top: 2px;">ID: <code>${esc(order.tenantId || '—')}</code></div>
            ${phone ? `<a href="https://wa.me/${phone.length === 10 ? '91' + phone : phone}" target="_blank" rel="noopener noreferrer" style="font-size: 11px; color: var(--primary); text-decoration: none; font-weight: 600;">💬 ${esc(order.phone)}</a>` : ''}
          </td>
          <td>
            <div style="font-size: 12.5px; font-weight: 700; color: var(--text-main);">${esc(order.printerItem || '—')}</div>
            <div style="font-size: 11.5px; color: var(--text-muted);">Qty: ${esc(order.quantity || 1)}</div>
          </td>
          <td style="max-width: 240px; font-size: 12px; color: var(--text-muted); white-space: normal;">
            ${esc(order.shippingAddress || '—')}
          </td>
          <td>
            <strong style="font-size: 13px; color: var(--text-main);">${esc(this.formatRupees(order.price))}</strong>
            <div style="margin-top: 4px;"><span class="badge ${payBadge[pay] || 'badge-warning'}">${esc(this.formatRoleLabel(pay))}</span></div>
          </td>
          <td>
            <select class="form-control" style="font-size: 11.5px; padding: 4px 8px; height: auto; border-radius: var(--radius-xs); width: auto; font-weight: 700; margin-bottom: 4px;" onchange="adminApp.updatePrinterStatus('${this.escapeJs(order.id)}', this.value)">
              ${[['Processing', '⚙️'], ['Packed', '📦'], ['Shipped', '🚚'], ['In Transit', '🛣️'], ['Delivered', '✅'], ['Cancelled', '❌']]
                .map(([st, icon]) => `<option value="${st}" ${order.status === st ? 'selected' : ''}>${icon} ${st}</option>`).join('')}
            </select>
            <div style="font-size: 11px; color: var(--text-muted);">${esc(order.courierName || 'No courier yet')} • <code>${esc(order.trackingNumber || 'Unassigned')}</code></div>
          </td>
          <td>
            <div style="display: flex; gap: 6px; flex-wrap: wrap;">
              <button class="btn btn-sm btn-outline" onclick="adminApp.openShippingLabel('${this.escapeJs(order.id)}')" title="Print Shipping Label" style="padding: 5px 10px; font-size: 12px;">
                🏷️ Label
              </button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.editTracking('${this.escapeJs(order.id)}')" title="Edit AWB Tracking" style="padding: 5px 10px; font-size: 12px;">
                AWB
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  populatePrinterOrderSelects() {
    const esc = v => this.escapeHtml(v);
    const itemSelect = document.getElementById('printerItemSelect');
    if (itemSelect) {
      itemSelect.innerHTML = (this.printerOptions || []).map(p => `
        <option value="${esc(p.id)}" ${p.isAvailable === false ? 'disabled' : ''}>
          ${esc(p.name)} (${esc(p.paperWidth)} – ₹${Number(p.price || 0).toLocaleString('en-IN')} + ${Number(p.gstRate ?? 18)}% GST)${p.isAvailable === false ? ' – out of stock' : ''}
        </option>`).join('');
    }
    const tenantSelect = document.getElementById('printerTenantSelect');
    if (tenantSelect) {
      tenantSelect.innerHTML = '<option value="">— Select agency —</option>' + (this.tenants || []).map(t =>
        `<option value="${esc(t.id)}">${esc(t.firmName)} (${esc(t.city || t.id)})</option>`).join('');
    }
  }

  onPrinterTenantChange(tenantId) {
    const t = this.findTenantById(tenantId);
    if (!t) return;
    const name = document.getElementById('printerCustomerName');
    const phone = document.getElementById('printerPhone');
    const addr = document.getElementById('printerAddress');
    if (name && !name.value) name.value = t.ownerName || '';
    if (phone && !phone.value) phone.value = t.phone || '';
    if (addr && !addr.value) addr.value = [t.address, t.city, t.state].filter(Boolean).join(', ');
  }

  openPrinterOrderModal() {
    document.getElementById('printerOrderForm')?.reset();
    this.populatePrinterOrderSelects();
    document.getElementById('printerOrderModal')?.classList.add('active');
  }

  closePrinterOrderModal() {
    document.getElementById('printerOrderModal')?.classList.remove('active');
  }

  async handleSavePrinterOrder(e) {
    e.preventDefault();
    const val = id => document.getElementById(id)?.value.trim() || '';
    const tenantId = val('printerTenantSelect');
    if (!tenantId) { this.showToast('Select the agency this hardware is for.', '⚠️', 'warning'); return; }
    const ok = await this.apiMutate('/api/platform/order-hardware', {
      tenantId,
      printerId: val('printerItemSelect'),
      quantity: parseInt(val('printerQuantity'), 10) || 1,
      paymentStatus: val('printerPaymentStatus') || 'pending',
      customerName: val('printerCustomerName'),
      phone: val('printerPhone'),
      shippingAddress: val('printerAddress'),
    });
    if (!ok) return;
    this.closePrinterOrderModal();
    await this.fetchPlatformState(true);
    this.showToast('Hardware order queued for dispatch.', '📦');
  }

  async updatePrinterStatus(orderId, newStatus) {
    const order = this.printerOrders.find(o => o.id === orderId);
    if (!order) return;
    const patch = { orderId, status: newStatus };
    const s = String(newStatus).toLowerCase();
    if ((s === 'shipped' || s === 'dispatched' || s === 'in transit') && (!order.trackingNumber || order.trackingNumber === 'Unassigned')) {
      const awb = prompt(`Courier tracking number (AWB) for ${order.id}:`, '');
      if (awb === null) { this.renderPrintersTable(); return; }
      const courier = prompt('Courier partner (e.g. BlueDart, Delhivery, DTDC):', order.courierName || '');
      patch.trackingNumber = awb.trim();
      if (courier !== null) patch.courierName = courier.trim();
    }
    const ok = await this.apiMutate('/api/platform/printer-order/status', patch);
    if (!ok) { this.renderPrintersTable(); return; }
    await this.fetchPlatformState(true);
    this.showToast(`Order ${orderId} marked as ${newStatus}.`, '🚚');
  }

  async editTracking(orderId) {
    const order = this.printerOrders.find(o => o.id === orderId);
    if (!order) return;
    const current = order.trackingNumber === 'Unassigned' ? '' : order.trackingNumber;
    const tracking = prompt(`Courier tracking number (AWB) for ${order.id}:`, current);
    if (tracking === null) return;
    const courier = prompt('Courier partner (e.g. BlueDart, Delhivery, DTDC):', order.courierName || '');
    const ok = await this.apiMutate('/api/platform/printer-order/status', {
      orderId, trackingNumber: tracking.trim(), ...(courier !== null ? { courierName: courier.trim() } : {}),
    });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`Tracking updated for ${order.id}.`);
  }

  openShippingLabel(orderId) {
    const order = this.printerOrders.find(o => o.id === orderId);
    if (!order) return;
    const esc = v => this.escapeHtml(v);
    const from = this.settings || {};
    const content = document.getElementById('shippingLabelContent');
    if (content) {
      content.innerHTML = `
        <div class="shipping-label-preview">
          <div class="shipping-label-header">
            <div>
              <strong style="font-size: 16px;">${esc(from.companyName || 'SalesArmy Fulfillment')}</strong><br>
              <span style="font-size: 11px;">${esc(from.supportPhone || '')}</span>
            </div>
            <div style="text-align: right;">
              <strong style="font-size: 16px;">${esc(order.courierName || 'Courier not assigned')}</strong>
            </div>
          </div>

          <div style="font-size: 12px; margin-bottom: 12px;">
            <strong>SHIP TO:</strong><br>
            <span style="font-size: 14px; font-weight: 800;">${esc(order.customerName)}</span><br>
            <span>${esc(order.agencyName)} (ID: ${esc(order.tenantId)})</span><br>
            <span>Ph: ${esc(order.phone)}</span><br>
            <span>${esc(order.shippingAddress)}</span>
          </div>

          <div class="shipping-barcode"></div>
          <div style="text-align: center; font-size: 11px; margin-bottom: 14px;">
            AWB: ${esc(order.trackingNumber && order.trackingNumber !== 'Unassigned' ? order.trackingNumber : 'PENDING')}
          </div>

          <div style="border-top: 1px dashed #0F172A; padding-top: 8px; font-size: 11px;">
            <strong>ITEM:</strong> ${esc(order.printerItem)} × ${esc(order.quantity || 1)}<br>
            <strong>ORDER REF:</strong> ${esc(order.id)} • <strong>DATE:</strong> ${esc(order.orderedAt ? new Date(order.orderedAt).toLocaleDateString('en-IN') : '')}
          </div>
        </div>
      `;
    }
    document.getElementById('shippingLabelModal')?.classList.add('active');
  }

  closeShippingLabelModal() {
    document.getElementById('shippingLabelModal')?.classList.remove('active');
  }

  /**
   * Open the label in an isolated popup window with its own stylesheet so
   * window.print() prints only the label, not the entire admin console
   * background (which was happening before this fix).
   */
  printShippingLabel() {
    const node = document.getElementById('shippingLabelContent');
    if (!node) return;
    const w = window.open('', 'shippingLabel', 'width=420,height=640');
    if (!w) {
      // Pop-up blocked — fall back to in-tab print (previous behaviour).
      window.print();
      return;
    }
    w.document.write(`<!doctype html><html><head><title>Shipping Label</title>
      <style>
        @page { size: 4in 6in; margin: 0.25in; }
        body { font-family: system-ui, -apple-system, sans-serif; margin: 0; padding: 16px; color: #0F172A; }
        .shipping-label-preview { border: 2px solid #0F172A; padding: 16px; }
        .shipping-label-header { display:flex; justify-content:space-between; border-bottom:2px dashed #0F172A; padding-bottom:8px; margin-bottom:12px; }
        .shipping-barcode { height: 32px; background: repeating-linear-gradient(90deg, #0F172A 0 2px, transparent 2px 5px); margin: 6px 0; }
      </style>
    </head><body>${node.innerHTML}</body></html>`);
    w.document.close();
    w.focus();
    setTimeout(() => { try { w.print(); w.close(); } catch (_) {} }, 150);
  }

  // --- VIEW 5: Agencies & Tenants Directory ---
  _getTenantAvatarGradient(plan, status) {
    if (status === 'suspended') return 'linear-gradient(135deg, #DC2626, #EF4444)';
    const p = (plan || '').toLowerCase();
    if (p.includes('enterprise')) return 'linear-gradient(135deg, #7C3AED, #9333EA)';
    if (p.includes('grow') || p.includes('gold') || p.includes('pro')) return 'linear-gradient(135deg, #2563EB, #3B82F6)';
    if (p.includes('startup') || p.includes('silver')) return 'linear-gradient(135deg, #059669, #10B981)';
    if (p.includes('trial')) return 'linear-gradient(135deg, #D97706, #F59E0B)';
    return 'linear-gradient(135deg, #4F46E5, #3B82F6)';
  }

  _getTenantStatusBadge(status, isSuspended) {
    if (isSuspended || status === 'suspended') {
      return { class: 'badge-expired', label: 'FROZEN / LOCKED', dotColor: '#EF4444' };
    }
    const s = (status || 'active').toLowerCase();
    if (s === 'active') return { class: 'badge-active', label: 'ACTIVE PRO', dotColor: '#10B981' };
    if (s === 'trial') return { class: 'badge-trial', label: 'FREE TRIAL', dotColor: '#F59E0B' };
    if (s === 'expired') return { class: 'badge-expired', label: 'EXPIRED · READ-ONLY', dotColor: '#EF4444' };
    return { class: 'badge-expired', label: s.toUpperCase(), dotColor: '#6B7280' };
  }

  _getTenantEmptyStateHTML() {
    return `
      <div style="text-align: center; padding: 48px 20px; color: var(--text-muted);">
        <div style="width: 52px; height: 52px; border-radius: 50%; background: var(--bg-subtle); display: inline-flex; align-items: center; justify-content: center; margin-bottom: 12px; color: var(--text-secondary);">
          <svg class="icon icon-lg" viewBox="0 0 24 24"><circle cx="11" cy="11" r="8"></circle><line x1="21" y1="21" x2="16.65" y2="16.65"></line></svg>
        </div>
        <div style="font-size: 15px; font-weight: 700; color: var(--text-main); margin-bottom: 4px;">No Agencies Found</div>
        <div style="font-size: 12.5px; color: var(--text-muted); max-width: 380px; margin: 0 auto 16px auto;">
          No agency tenants match your active search terms or filter criteria.
        </div>
        <button type="button" class="btn btn-outline btn-sm" onclick="adminApp.clearTenantSearch(); adminApp.filterTenantsByPlan('all'); adminApp.filterTenantsByCity('all'); adminApp.filterTenantsByState('all');">
          Clear Active Filters
        </button>
      </div>
    `;
  }

  getFilteredTenants() {
    let list = (this.tenants || []).slice();

    // 1. Status Filter
    if (this.tenantFilter && this.tenantFilter !== 'all') {
      if (this.tenantFilter === 'suspended') {
        list = list.filter(t => t.subscriptionStatus === 'suspended' || t.isSuspended === true);
      } else if (this.tenantFilter === 'usage_active') {
        list = list.filter(t => t.usageActive === true);
      } else if (this.tenantFilter === 'usage_inactive') {
        list = list.filter(t => t.usageActive !== true);
      } else {
        list = list.filter(t => t.subscriptionStatus === this.tenantFilter && !t.isSuspended);
      }
    }

    // 2. Plan Filter
    if (this.tenantPlanFilter && this.tenantPlanFilter !== 'all') {
      list = list.filter(t => {
        const p = (t.subscriptionPlanId || t.planName || '').toLowerCase();
        return p.includes(this.tenantPlanFilter);
      });
    }

    // 3. City Filter
    if (this.tenantCityFilter && this.tenantCityFilter !== 'all') {
      list = list.filter(t => (t.city || '').toLowerCase() === this.tenantCityFilter.toLowerCase());
    }

    // 3b. State Filter
    if (this.tenantStateFilter && this.tenantStateFilter !== 'all') {
      list = list.filter(t => (t.state || '').trim().toLowerCase() === this.tenantStateFilter.toLowerCase());
    }

    // 4. Search Filter
    if (this.tenantSearch) {
      const q = this.tenantSearch.toLowerCase();
      list = list.filter(t =>
        (t.userId || '').toLowerCase().includes(q) ||
        (t.id || '').toLowerCase().includes(q) ||
        (t.firmName || t.name || '').toLowerCase().includes(q) ||
        (t.ownerName || '').toLowerCase().includes(q) ||
        (t.city || '').toLowerCase().includes(q) ||
        (t.phone || '').toLowerCase().includes(q) ||
        (t.gstin || '').toLowerCase().includes(q)
      );
    }

    // 5. Sorting
    const sortKey = this.tenantSortKey || 'createdAt';
    const sortDir = this.tenantSortDir === 'asc' ? 1 : -1;

    list.sort((a, b) => {
      if (sortKey === 'firmName') {
        const valA = (a.firmName || a.name || '').toLowerCase();
        const valB = (b.firmName || b.name || '').toLowerCase();
        return valA.localeCompare(valB) * sortDir;
      }
      if (sortKey === 'userId') {
        const valA = (a.userId || a.id || '').toLowerCase();
        const valB = (b.userId || b.id || '').toLowerCase();
        return valA.localeCompare(valB) * sortDir;
      }
      if (sortKey === 'ordersCount') {
        const valA = Number(a.ordersCount) || 0;
        const valB = Number(b.ordersCount) || 0;
        return (valA - valB) * sortDir;
      }
      if (sortKey === 'expiryDate') {
        const valA = a.expiryDate ? new Date(a.expiryDate).getTime() : 0;
        const valB = b.expiryDate ? new Date(b.expiryDate).getTime() : 0;
        return (valA - valB) * sortDir;
      }
      if (sortKey === 'planTier') {
        const rank = (plan) => {
          const p = (plan || '').toLowerCase();
          if (p.includes('enterprise')) return 4;
          if (p.includes('grow') || p.includes('gold') || p.includes('pro')) return 3;
          if (p.includes('startup') || p.includes('silver')) return 2;
          if (p.includes('trial')) return 1;
          return 0;
        };
        const rankA = rank(a.planName || a.subscriptionPlanId);
        const rankB = rank(b.planName || b.subscriptionPlanId);
        return (rankA - rankB) * sortDir;
      }
      const valA = new Date(a.createdAt || a.updatedAt || 0).getTime();
      const valB = new Date(b.createdAt || b.updatedAt || 0).getTime();
      return (valA - valB) * sortDir;
    });

    return list;
  }

  renderTenantsView() {
    this.renderTenantsMetrics();
    this.populateTenantCityFilter();
    this.populateTenantStateFilter();
    this.setTenantViewMode(this.tenantViewMode); // syncs toggle buttons + renders
    this.updateTenantSortUI();
  }

  renderTenantsMetrics() {
    const tenants = this.tenants || [];
    const total = tenants.length;
    const active = tenants.filter(t => (t.subscriptionStatus || '').toLowerCase() === 'active' && !t.isSuspended).length;
    const trial = tenants.filter(t => (t.subscriptionStatus || '').toLowerCase() === 'trial').length;
    const freemium = tenants.filter(t => (t.subscriptionStatus || '').toLowerCase() === 'expired').length; // expired / read-only
    const suspended = tenants.filter(t => (t.subscriptionStatus || '').toLowerCase() === 'suspended' || t.isSuspended).length;

    const estMRR = tenants.reduce((sum, t) => {
      if ((t.subscriptionStatus || '').toLowerCase() !== 'active' || t.isSuspended) return sum;
      const p = (t.subscriptionPlanId || t.planName || '').toLowerCase();
      if (p.includes('enterprise')) return sum + 7999;
      if (p.includes('grow') || p.includes('gold') || p.includes('pro')) return sum + 3999;
      return sum + 1999;
    }, 0);

    const elTotal = document.getElementById('tenantStatTotal');
    if (elTotal) elTotal.textContent = total;
    const elActive = document.getElementById('tenantStatActive');
    if (elActive) elActive.textContent = active;
    const elMRR = document.getElementById('tenantStatMRR');
    if (elMRR) elMRR.textContent = `₹${estMRR.toLocaleString('en-IN')}/mo Est. MRR`;
    const elTrial = document.getElementById('tenantStatTrial');
    if (elTrial) elTrial.textContent = trial;
    const elFreemium = document.getElementById('tenantStatFreemium');
    if (elFreemium) elFreemium.textContent = freemium;
    const elHeaderCount = document.getElementById('badgeTenantHeaderCount');
    if (elHeaderCount) elHeaderCount.textContent = `${total} Total`;

    const cAll = document.getElementById('countFilterAll');
    if (cAll) cAll.textContent = total;
    // Active / Inactive pills = app usage in the last 30 days (not the paid status)
    const usageActive = tenants.filter(t => t.usageActive === true).length;
    const cActive = document.getElementById('countFilterActive');
    if (cActive) cActive.textContent = usageActive;
    const cInactive = document.getElementById('countFilterInactive');
    if (cInactive) cInactive.textContent = total - usageActive;
    const cTrial = document.getElementById('countFilterTrial');
    if (cTrial) cTrial.textContent = trial;
    const cFreemium = document.getElementById('countFilterFreemium');
    if (cFreemium) cFreemium.textContent = freemium;
    const cSuspended = document.getElementById('countFilterSuspended');
    if (cSuspended) cSuspended.textContent = suspended;
  }

  populateTenantCityFilter() {
    const sel = document.getElementById('filterTenantCity');
    if (!sel) return;
    const currentVal = this.tenantCityFilter || 'all';
    const cities = Array.from(new Set(
      (this.tenants || [])
        .map(t => (t.city || '').trim())
        .filter(Boolean)
    )).sort();

    sel.innerHTML = '<option value="all">All Cities</option>' + cities.map(c =>
      `<option value="${this.escapeHtml(c)}">${this.escapeHtml(c)}</option>`
    ).join('');
    sel.value = currentVal;
  }

  // Clicking anywhere on a subscriber card opens the profile (buttons/links keep their own action).
  onTenantCardClick(event, tenantId) {
    if (event?.target?.closest('a, button, select, input, label')) return;
    this.openTenantDetailModal(tenantId);
  }

  setTenantViewMode(mode) {
    this.tenantViewMode = mode === 'grid' ? 'grid' : 'table';
    const btnTable = document.getElementById('btnTenantViewTable');
    const btnGrid = document.getElementById('btnTenantViewGrid');
    const tableContainer = document.getElementById('tenantsTableViewContainer');
    const gridContainer = document.getElementById('tenantsCardsGrid');

    if (btnTable) btnTable.classList.toggle('active', this.tenantViewMode === 'table');
    if (btnGrid) btnGrid.classList.toggle('active', this.tenantViewMode === 'grid');

    if (tableContainer) tableContainer.style.display = this.tenantViewMode === 'table' ? 'block' : 'none';
    if (gridContainer) gridContainer.style.display = this.tenantViewMode === 'grid' ? 'grid' : 'none';

    if (this.tenantViewMode === 'grid') {
      this.renderTenantsGrid();
    } else {
      this.renderTenantsTable();
    }
  }

  filterTenantsByPlan(plan) {
    this.tenantPlanFilter = plan;
    this.renderTenantsView();
  }

  filterTenantsByCity(city) {
    this.tenantCityFilter = city;
    this.renderTenantsView();
  }

  populateTenantStateFilter() {
    const sel = document.getElementById('filterTenantState');
    if (!sel) return;
    const currentVal = this.tenantStateFilter || 'all';
    const states = Array.from(new Set((this.tenants || []).map(t => (t.state || '').trim()).filter(Boolean))).sort();
    sel.innerHTML = '<option value="all">All States</option>' + states.map(s =>
      `<option value="${this.escapeHtml(s)}">${this.escapeHtml(s)}</option>`).join('');
    sel.value = states.includes(currentVal) ? currentVal : 'all';
  }

  filterTenantsByState(state) {
    this.tenantStateFilter = state;
    this.renderTenantsView();
  }

  setTenantSortKey(key) {
    if (this.tenantSortKey !== key) {
      this.tenantSortKey = key;
      if (key === 'firmName' || key === 'userId') {
        this.tenantSortDir = 'asc';
      } else {
        this.tenantSortDir = 'desc';
      }
    }
    this.renderTenantsView();
  }

  toggleTenantSortDirection() {
    this.tenantSortDir = this.tenantSortDir === 'asc' ? 'desc' : 'asc';
    this.renderTenantsView();
  }

  toggleTenantColumnSort(colKey) {
    if (this.tenantSortKey === colKey) {
      this.tenantSortDir = this.tenantSortDir === 'asc' ? 'desc' : 'asc';
    } else {
      this.tenantSortKey = colKey;
      if (colKey === 'firmName' || colKey === 'userId') {
        this.tenantSortDir = 'asc';
      } else {
        this.tenantSortDir = 'desc';
      }
    }
    this.renderTenantsView();
  }

  updateTenantSortUI() {
    const sel = document.getElementById('sortTenantOrder');
    if (sel && sel.value !== this.tenantSortKey) {
      sel.value = this.tenantSortKey;
    }

    const icon = document.getElementById('tenantSortDirIcon');
    const dirBtn = document.getElementById('btnTenantSortDir');
    if (icon) {
      icon.textContent = this.tenantSortDir === 'asc' ? '↑' : '↓';
    }
    if (dirBtn) {
      dirBtn.title = this.tenantSortDir === 'asc' ? 'Ascending (Click for Descending)' : 'Descending (Click for Ascending)';
      dirBtn.classList.toggle('is-asc', this.tenantSortDir === 'asc');
    }

    const headers = document.querySelectorAll('th.sortable-col');
    headers.forEach(th => {
      const key = th.dataset.sortKey;
      const indicator = document.getElementById(`sortInd-${key}`);
      if (key === this.tenantSortKey) {
        th.classList.add('sort-active');
        if (indicator) {
          indicator.textContent = this.tenantSortDir === 'asc' ? '▲' : '▼';
          indicator.classList.add('active');
        }
      } else {
        th.classList.remove('sort-active');
        if (indicator) {
          indicator.textContent = '↕';
          indicator.classList.remove('active');
        }
      }
    });
  }

  sortTenants(order) {
    if (order === 'name_asc') {
      this.tenantSortKey = 'firmName';
      this.tenantSortDir = 'asc';
    } else if (order === 'name_desc') {
      this.tenantSortKey = 'firmName';
      this.tenantSortDir = 'desc';
    } else if (order === 'orders_desc') {
      this.tenantSortKey = 'ordersCount';
      this.tenantSortDir = 'desc';
    } else {
      this.tenantSortKey = 'createdAt';
      this.tenantSortDir = 'desc';
    }
    this.tenantSortOrder = order;
    this.renderTenantsView();
  }

  clearTenantSearch() {
    this.tenantSearch = '';
    const input = document.getElementById('searchTenantsInput');
    if (input) input.value = '';
    const btnClear = document.getElementById('btnClearTenantSearch');
    if (btnClear) btnClear.style.display = 'none';
    this.renderTenantsView();
  }

  renderTenantsTable() {
    const tbody = document.getElementById('tenantsTableBody');
    if (!tbody) return;

    const list = this.getFilteredTenants();

    if (list.length === 0) {
      tbody.innerHTML = `<tr><td colspan="6" style="padding: 0;">${this._getTenantEmptyStateHTML()}</td></tr>`;
      return;
    }

    tbody.innerHTML = list.map(t => {
      const isSuspended = t.subscriptionStatus === 'suspended' || t.isSuspended === true;
      const badge = this._getTenantStatusBadge(t.subscriptionStatus, isSuspended);
      const gradient = this._getTenantAvatarGradient(t.planName, t.subscriptionStatus);
      const initials = (t.firmName || t.name || 'TN').substring(0, 2).toUpperCase();
      const phoneClean = String(t.phone || '').replace(/[^0-9]/g, '');

      return `
        <tr style="${isSuspended ? 'background: rgba(244, 63, 94, 0.04); border-left: 3px solid var(--rose);' : ''}">
          <td>
            <div style="display: flex; align-items: center; gap: 12px;">
              <div style="width: 36px; height: 36px; border-radius: var(--radius-sm); background: ${gradient}; color: white; display: flex; align-items: center; justify-content: center; font-size: 13px; font-weight: 800; flex-shrink: 0; box-shadow: 0 2px 4px rgba(0,0,0,0.12);">${this.escapeHtml(initials)}</div>
              <div style="min-width: 0;">
                <div style="font-weight: 700; color: var(--text-main); font-size: 13.5px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;">${this.escapeHtml(t.firmName || t.name || 'Agency')}</div>
                <div style="font-size: 11.5px; color: var(--text-muted); display: flex; align-items: center; gap: 6px; margin-top: 2px;">
                  <span>👤 ${this.escapeHtml(t.ownerName || 'Proprietor')}</span>
                  <span>•</span>
                  <span>📍 ${this.escapeHtml(t.city || 'India')}</span>
                </div>
                ${phoneClean ? `
                  <div style="margin-top: 3px;">
                    <a href="https://wa.me/91${phoneClean}" target="_blank" style="font-size: 11px; color: #059669; text-decoration: none; font-weight: 600; display: inline-flex; align-items: center; gap: 4px;">
                      💬 +91 ${this.escapeHtml(t.phone)}
                    </a>
                  </div>
                ` : ''}
              </div>
            </div>
          </td>
          <td>
            <div class="code-pill">
              <span>${this.escapeHtml(t.userId || t.id)}</span>
              <button onclick="adminApp.copyText('${this.escapeJs(t.userId || t.id)}')" style="background:transparent; border:none; color:var(--text-muted); cursor:pointer;" title="Copy Unique ID">📋</button>
            </div>
            ${isSuspended ? '<div style="font-size: 10px; color: var(--rose); font-weight: 700; margin-top: 3px;">🔒 Remote App Lock Active</div>' : ''}
          </td>
          <td>
            <span class="badge ${badge.class}">${this.escapeHtml(t.planName || 'Startup Plan')}</span>
            <div style="font-size: 11px; color: var(--text-muted); margin-top: 3px;">Unlimited Bills • Full GST</div>
          </td>
          <td>
            <span class="badge ${badge.class}">
              <span style="display:inline-block; width:5px; height:5px; border-radius:50%; background:${badge.dotColor}; margin-right:4px;"></span>
              ${badge.label}
            </span>
            <div style="font-size: 11.5px; color: var(--text-muted); margin-top: 4px; font-variant-numeric: tabular-nums;">
              Renews: <strong>${this.escapeHtml(t.expiryDate || 'Active')}</strong>
            </div>
          </td>
          <td>
            <div style="display: flex; flex-direction: column; gap: 3px;">
              <span class="badge badge-delivered" style="font-size: 10.5px;">✓ Unrestricted Core</span>
              <span style="font-size: 11px; color: var(--text-muted); font-weight: 600;">${t.ordersCount || 0} Orders Logged</span>
            </div>
          </td>
          <td style="text-align: right;">
            <div style="display: inline-flex; gap: 6px; align-items: center; justify-content: flex-end; flex-wrap: wrap;">
              <button class="btn btn-sm btn-outline" onclick="adminApp.openTenantDrilldown('${this.escapeJs(t.id)}')" title="Drill-Down Snapshot" style="font-weight: 600; color: #3B82F6; border-color: rgba(59, 130, 246, 0.3);">
                🔍 Drill-Down
              </button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.openTenantDetailModal('${this.escapeJs(t.id)}')" title="Inspect Deep Profile" style="font-weight: 600;">
                Inspect
              </button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.openTenantModal('${this.escapeJs(t.id)}')" title="Edit Agency Profile">
                ✏️
              </button>
              <button class="btn btn-sm btn-outline" style="${isSuspended ? 'color:#10B981;border-color:rgba(16,185,129,0.3);font-weight:700;' : 'color:#DC2626;border-color:rgba(239,68,68,0.3);'}" onclick="adminApp.toggleTenantSuspension('${this.escapeJs(t.id)}')">
                ${isSuspended ? '⚡ Unfreeze' : '🛡️ Freeze'}
              </button>
              <button class="btn btn-sm btn-outline" onclick="adminApp.grantTenantTrialDays('${this.escapeJs(t.id)}', 14)" title="Grant +14 Days Trial">
                +14d
              </button>
              <button class="btn btn-sm btn-outline" style="color: #DC2626; border-color: rgba(239,68,68,0.25);" onclick="adminApp.deleteTenant('${this.escapeJs(t.id)}')" title="Delete Agency">
                ✕
              </button>
            </div>
          </td>
        </tr>
      `;
    }).join('');
  }

  renderTenantsGrid() {
    const container = document.getElementById('tenantsCardsGrid');
    if (!container) return;

    const list = this.getFilteredTenants();

    if (list.length === 0) {
      container.innerHTML = `<div style="grid-column: 1 / -1;">${this._getTenantEmptyStateHTML()}</div>`;
      return;
    }

    container.innerHTML = list.map(t => {
      const isSuspended = t.subscriptionStatus === 'suspended' || t.isSuspended === true;
      const badge = this._getTenantStatusBadge(t.subscriptionStatus, isSuspended);
      const gradient = this._getTenantAvatarGradient(t.planName, t.subscriptionStatus);
      const initials = (t.firmName || t.name || 'TN').substring(0, 2).toUpperCase();
      const phoneClean = String(t.phone || '').replace(/[^0-9]/g, '');

      return `
        <div class="tenant-card ${isSuspended ? 'suspended' : ''}" style="cursor: pointer;" title="Open subscriber profile" onclick="adminApp.onTenantCardClick(event, '${this.escapeJs(t.id)}')">
          <div class="tenant-card-header">
            <div class="tenant-card-avatar" style="background: ${gradient};">${this.escapeHtml(initials)}</div>
            <div class="tenant-card-main">
              <div class="tenant-card-firm">${this.escapeHtml(t.firmName || t.name || 'Agency')}</div>
              <div class="tenant-card-prop">Proprietor: ${this.escapeHtml(t.ownerName || 'Store Manager')} • ${this.escapeHtml(t.city || 'India')}</div>
            </div>
            <span class="badge ${badge.class}" style="font-size: 10.5px;">${badge.label}</span>
          </div>

          <div class="tenant-card-body">
            <div class="tenant-card-pill-row">
              <div class="code-pill">
                <span>${this.escapeHtml(t.userId || t.id)}</span>
                <button onclick="adminApp.copyText('${this.escapeJs(t.userId || t.id)}')" style="background:transparent; border:none; color:var(--text-muted); cursor:pointer;" title="Copy ID">📋</button>
              </div>
              <span class="badge badge-indigo" style="font-size: 11px;">${this.escapeHtml(t.planName || 'Startup Plan')}</span>
            </div>

            <div class="tenant-card-stats-box">
              <div>
                <div class="tenant-card-stat-label">Orders</div>
                <div class="tenant-card-stat-value">${t.ordersCount || 0}</div>
              </div>
              <div>
                <div class="tenant-card-stat-label">Core Billing</div>
                <div class="tenant-card-stat-value" style="color: var(--emerald-text);">Active</div>
              </div>
              <div>
                <div class="tenant-card-stat-label">Validity</div>
                <div class="tenant-card-stat-value" style="font-size: 11px;">${this.escapeHtml(t.expiryDate || 'Active')}</div>
              </div>
            </div>

            <div class="tenant-card-contact-row">
              ${phoneClean ? `
                <a class="tenant-contact-chip whatsapp" href="https://wa.me/91${phoneClean}?text=Hello%20${encodeURIComponent(t.ownerName || '')},%20your%20SalesArmy%20Agency%20ID%20is%20${encodeURIComponent(t.userId || t.id)}" target="_blank">
                  💬 WhatsApp
                </a>
                <a class="tenant-contact-chip" href="tel:+91${phoneClean}">
                  📞 +91 ${this.escapeHtml(t.phone)}
                </a>
              ` : `
                <span class="tenant-contact-chip">📍 ${this.escapeHtml(t.city || 'Location')}</span>
              `}
              ${t.gstin ? `<span class="tenant-contact-chip" style="font-family: var(--font-mono); font-size: 11px;">GST: ${this.escapeHtml(t.gstin)}</span>` : ''}
            </div>
          </div>

          <div class="tenant-card-footer">
            <button type="button" class="btn btn-sm btn-primary" onclick="adminApp.openTenantDetailModal('${this.escapeJs(t.id)}')">
              <span>Inspect Profile</span>
            </button>
            <div style="display: flex; gap: 6px;">
              <button type="button" class="btn btn-sm btn-outline" onclick="adminApp.openTenantModal('${this.escapeJs(t.id)}')" title="Edit Agency">
                ✏️
              </button>
              <button type="button" class="btn btn-sm btn-outline" style="${isSuspended ? 'color:#10B981;border-color:rgba(16,185,129,0.3);' : 'color:#DC2626;border-color:rgba(239,68,68,0.3);'}" onclick="adminApp.toggleTenantSuspension('${this.escapeJs(t.id)}')">
                ${isSuspended ? 'Unfreeze' : 'Freeze'}
              </button>
              <button type="button" class="btn btn-sm btn-outline" onclick="adminApp.grantTenantTrialDays('${this.escapeJs(t.id)}', 14)" title="+14 Days Trial">
                +14d
              </button>
            </div>
          </div>
        </div>
      `;
    }).join('');
  }

  findTenantById(tenantId) {
    return (this.tenants || []).find(t => t.id === tenantId || t.tenantId === tenantId || t.userId === tenantId);
  }

  // Send a validated partial update for one agency, then reload from the DB.
  async updateTenant(tenantId, patch, successMessage, icon = '🏢') {
    const ok = await this.apiMutate('/api/platform/sync-tenant', { id: tenantId, ...patch });
    if (!ok) return false;
    await this.fetchPlatformState(true);
    // Stay on the agency's profile page and show the updated details there
    if (this.currentView === 'tenant-profile' && this._tdTenantId === tenantId) {
      const y = window.scrollY;
      this.openTenantDetailModal(tenantId);
      window.scrollTo(0, y);
    }
    if (successMessage) this.showToast(successMessage, icon);
    return true;
  }

  async toggleTenantSuspension(tenantId) {
    const tenant = this.findTenantById(tenantId);
    if (!tenant) return;
    const suspending = !tenant.isSuspended;
    if (suspending && !confirm(`Freeze "${tenant.firmName}"? Its staff will be blocked from billing until you unfreeze it.`)) return;
    await this.updateTenant(tenant.id, { isSuspended: suspending },
      `"${tenant.firmName}" is now ${suspending ? 'FROZEN' : 'ACTIVE'}.`, suspending ? '🛡️' : '⚡');
  }

  async grantTenantTrialDays(tenantId, days) {
    const tenant = this.findTenantById(tenantId);
    if (!tenant) return;
    await this.updateTenant(tenant.id, { extendDays: days }, `Extended "${tenant.firmName}" by ${days} days.`, '🎁');
  }

  grantTrialDays(tenantId, days = 14) { return this.grantTenantTrialDays(tenantId, days); }

  async assignTenantPlan(tenantId, planId) {
    const tenant = this.findTenantById(tenantId);
    if (!tenant) return;
    const tier = (this.plans?.tiers || []).find(t => t.id === planId);
    if (!tier) { this.showToast(`Unknown plan "${planId}".`, '⚠️', 'warning'); return; }
    await this.updateTenant(tenant.id, { subscriptionPlanId: planId, subscriptionStatus: 'active' },
      `Assigned "${tenant.firmName}" to ${tier.name} (${tier.maxStaff ?? tier.maxUsers} users, ${tier.maxShops || 'unlimited'} shops).`, '🏷️');
  }

  upgradeTenantPlan(tenantId, planId) { return this.assignTenantPlan(tenantId, planId); }

  async activatePro(tenantId) {
    const tenant = this.findTenantById(tenantId);
    if (!tenant) return;
    const exp = new Date(); exp.setFullYear(exp.getFullYear() + 1);
    await this.updateTenant(tenant.id, { subscriptionPlanId: 'enterprise', subscriptionStatus: 'active', expiryDate: exp.toISOString().slice(0, 10) },
      `"${tenant.firmName}" activated on Enterprise for 1 year.`, '⭐');
  }

  // There is no free tier any more: this ends the agency's plan now (read-only).
  async expireTenantNow(tenantId) {
    const tenant = this.findTenantById(tenantId);
    if (!tenant) return;
    if (!confirm(`End "${tenant.firmName}"'s plan now?\n\nThe app becomes read-only for them until they renew.`)) return;
    await this.updateTenant(tenant.id, { subscriptionStatus: 'expired', expiryDate: new Date().toISOString() },
      `"${tenant.firmName}" plan ended (read-only).`, '⚡');
  }

  async createPaymentLink(tenantId) {
    const tenant = this.findTenantById(tenantId);
    if (!tenant) return;
    const tiers = (this.plans?.tiers || []).filter(t => t.isActive !== false);
    const planId = prompt(`Plan for "${tenant.firmName}" (${tiers.map(t => t.id).join(' / ')}):`, tenant.subscriptionPlanId || (tiers[0]?.id || 'startup'));
    if (!planId) return;
    const yearly = confirm('Bill yearly? (OK = yearly, Cancel = monthly)');
    try {
      const res = await fetch('/api/platform/gateway/create-link', {
        method: 'POST',
        headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({ tenantId: tenant.id, planId: planId.trim(), yearly }),
      });
      const data = await res.json();
      if (data.checkoutUrl) {
        navigator.clipboard?.writeText(data.checkoutUrl).catch(() => {});
        prompt(`Payment link for ₹${Number(data.amount).toLocaleString('en-IN')} (copied to clipboard). Share it with the agency:`, data.checkoutUrl);
      } else {
        this.showToast(`Checkout ${data.status || 'created'} (₹${Number(data.amount || 0).toLocaleString('en-IN')}).`, '💳');
      }
      this.renderBilling();
    } catch (_) { /* fetch wrapper shows the error */ }
  }

  async deleteTenant(tenantId) {
    const t = this.findTenantById(tenantId);
    if (!t) return;
    const tid = t.id || t.tenantId;
    const typed = prompt(`⚠️ This permanently deletes "${t.firmName}", ALL of its shops, orders, invoices, payments and every staff login.\n\nType the agency ID to confirm:\n${tid}`);
    if (typed === null) return;
    if (typed.trim() !== tid) {
      this.showToast('Agency ID did not match. Nothing was deleted.', '⚠️', 'warning');
      return;
    }
    const ok = await this.apiMutate(`/api/platform/tenant/${encodeURIComponent(tid)}?confirm=${encodeURIComponent(tid)}`, null, { method: 'DELETE' });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast(`Agency "${t.firmName}" deleted.`, '🗑️');
  }

  openTenantModal(tenantId = null) {
    const form = document.getElementById('tenantForm');
    if (form) form.reset();
    const editIdInput = document.getElementById('tenantEditId');
    const modalTitle = document.getElementById('tenantModalTitle');
    const pwdRow = document.getElementById('tenantPasswordRow');
    const pwdInput = document.getElementById('tenantPassword');
    const set = (id, v) => { const el = document.getElementById(id); if (el) el.value = v ?? ''; };

    if (tenantId) {
      const t = this.findTenantById(tenantId);
      if (t) {
        if (editIdInput) editIdInput.value = t.id || t.tenantId;
        if (modalTitle) modalTitle.innerText = `Edit Agency: ${t.firmName}`;
        if (pwdRow) pwdRow.style.display = 'none';
        if (pwdInput) pwdInput.required = false;
        set('tenantFirmName', t.firmName); set('tenantOwnerName', t.ownerName); set('tenantEmail', t.email);
        set('tenantPhone', t.phone); set('tenantCity', t.city); set('tenantGstin', t.gstin); set('tenantPan', t.pan);
        set('tenantAddress', t.address);
        set('tenantStatusSelect', t.subscriptionStatus || 'active');
        set('tenantPlanSelect', t.subscriptionPlanId || 'startup');
      }
    } else {
      if (editIdInput) editIdInput.value = '';
      if (modalTitle) modalTitle.innerText = 'Register New FMCG Distribution Agency';
      if (pwdRow) pwdRow.style.display = 'grid';
      if (pwdInput) { pwdInput.required = true; pwdInput.value = this.generateStrongPassword(); }
      set('tenantStatusSelect', 'trial');
      set('tenantPlanSelect', this.settings?.defaultPlanId || 'startup');
    }
    document.getElementById('tenantModal')?.classList.add('active');
  }

  closeTenantModal() {
    document.getElementById('tenantModal')?.classList.remove('active');
  }

  async handleSaveTenant(e) {
    e.preventDefault();
    const val = id => document.getElementById(id)?.value.trim() || '';
    const editId = val('tenantEditId');
    const fields = {
      firmName: val('tenantFirmName'), ownerName: val('tenantOwnerName'), email: val('tenantEmail'),
      phone: val('tenantPhone'), city: val('tenantCity'), gstin: val('tenantGstin'), pan: val('tenantPan'),
      address: val('tenantAddress'),
    };
    const status = document.getElementById('tenantStatusSelect')?.value || 'trial';
    const planId = document.getElementById('tenantPlanSelect')?.value || 'startup';
    if (!fields.firmName || !fields.ownerName || !fields.phone) {
      this.showToast('Agency name, owner name and mobile are required.', '⚠️', 'warning');
      return;
    }

    if (editId) {
      const ok = await this.updateTenant(editId, { ...fields, subscriptionStatus: status, subscriptionPlanId: planId }, `Updated agency "${fields.firmName}".`);
      if (ok) this.closeTenantModal();
      return;
    }

    const password = document.getElementById('tenantPassword')?.value || '';
    if (!fields.email) { this.showToast('Owner email is required to create their login.', '⚠️', 'warning'); return; }
    if (password.length < 8) { this.showToast('Owner password must be at least 8 characters.', '⚠️', 'warning'); return; }
    try {
      const res = await fetch('/api/auth/signup', {
        method: 'POST',
        headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }),
        body: JSON.stringify({
          accountType: 'agency', businessName: fields.firmName, name: fields.ownerName, email: fields.email, password,
          phone: fields.phone, city: fields.city, gstin: fields.gstin, pan: fields.pan, address: fields.address,
          planId, subscriptionStatus: status,
        }),
      });
      const data = await res.json();
      if (!res.ok || !data.success) {
        this.showToast(data.error || 'Could not register agency.', '❌', 'danger');
        return;
      }
      this.closeTenantModal();
      await this.fetchPlatformState(true);
      navigator.clipboard?.writeText(password).catch(() => {});
      this.showToast(`Agency "${fields.firmName}" created (ID ${data.tenantId}). Owner password copied to clipboard.`, '🏢');
    } catch (err) {
      this.showToast(err.message || 'Could not register agency.', '❌', 'danger');
    }
  }

  openTenantDetailModal(tenantId) {
    const t = this.findTenantById(tenantId);
    if (!t) return;
    const container = document.getElementById('tenantDetailModalContent');
    if (container) {
      const esc = v => this.escapeHtml(v);
      const jid = this.escapeJs(t.id);
      const isSuspended = t.isSuspended === true || t.subscriptionStatus === 'suspended';
      const badge = this._getTenantStatusBadge(t.subscriptionStatus, isSuspended);
      const gradient = this._getTenantAvatarGradient(t.planName, t.subscriptionStatus);
      const initials = (t.firmName || 'TN').substring(0, 2).toUpperCase();
      const phoneClean = String(t.phone || '').replace(/[^0-9]/g, '').slice(-10);
      const money = n => `₹${Number(n || 0).toLocaleString('en-IN', { maximumFractionDigits: 0 })}`;
      const tiers = (this.plans?.tiers || []).filter(x => x.isActive !== false);

      container.innerHTML = `
        <div class="tenant-inspector-header">
          <div class="tenant-avatar-large" style="background: ${gradient};">${esc(initials)}</div>
          <div style="flex: 1; min-width: 0;">
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              <h3 style="font-size: 17px; font-weight: 800; color: var(--text-main); margin: 0;">${esc(t.firmName || 'Agency')}</h3>
              <span class="badge ${badge.class}">${esc(badge.label)}</span>
            </div>
            <p style="font-size: 12.5px; color: var(--text-muted); margin: 3px 0 6px 0;">Owner: ${esc(t.ownerName || '—')} • ${esc(t.city || '—')} • ${esc(t.email || 'no email')}</p>
            <div style="display: flex; align-items: center; gap: 8px;">
              <span class="code-pill">${esc(t.id)}</span>
              <button onclick="adminApp.copyText('${jid}')" style="background:transparent; border:none; color:var(--text-muted); cursor:pointer; font-size: 12px;" title="Copy ID">📋</button>
            </div>
          </div>
        </div>

        <div class="tenant-detail-grid">
          <div class="tenant-detail-item"><div class="tenant-detail-label">Plan</div><div class="tenant-detail-value" style="color: var(--primary-accent);">${esc(t.planName)}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Status</div><div class="tenant-detail-value" style="color: ${badge.dotColor};">${esc(badge.label)}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Renewal / Expiry</div><div class="tenant-detail-value">${esc(t.expiryDate || '—')}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Seats / Shops quota</div><div class="tenant-detail-value">${esc(t.usersCount)} / ${esc(t.maxUsers ?? '—')} users • ${esc(t.shopsCount)} / ${esc(t.maxShops ?? '—')} shops</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Orders • Invoiced</div><div class="tenant-detail-value">${esc(t.ordersCount)} • ${money(t.revenue)}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Collected • Market dues</div><div class="tenant-detail-value">${money(t.collected)} • ${money(t.outstanding)}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Phone</div><div class="tenant-detail-value" style="font-family: var(--font-mono); font-size: 12px;">${esc(t.phone || 'N/A')}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">GSTIN</div><div class="tenant-detail-value" style="font-family: var(--font-mono); font-size: 12px;">${esc(t.gstin || 'Unregistered')}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Email</div><div class="tenant-detail-value" style="font-size: 12px;">${esc(t.email || 'N/A')}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">City • State</div><div class="tenant-detail-value">${esc(t.city || '—')} • ${esc(t.state || '—')}</div></div>
          <div class="tenant-detail-item" style="grid-column: 1 / -1;"><div class="tenant-detail-label">Address</div><div class="tenant-detail-value" style="font-size: 12px;">${esc(t.address || '—')}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">App usage (30 days)</div><div class="tenant-detail-value" style="color: ${t.usageActive ? '#10B981' : '#EF4444'};">${t.usageActive ? 'Active' : 'Inactive'}</div></div>
          <div class="tenant-detail-item"><div class="tenant-detail-label">Last activity</div><div class="tenant-detail-value">${esc(t.lastActiveAt ? new Date(t.lastActiveAt).toLocaleString('en-IN') : 'None in last 30 days')}</div></div>
        </div>

        <h4 style="font-size: 12px; font-weight: 700; color: var(--text-muted); margin: 16px 0 10px; text-transform: uppercase; letter-spacing: 0.04em;">Orders (subscriptions &amp; hardware)</h4>
        <div class="table-responsive" style="max-height: 220px; overflow: auto;">
          <table>
            <thead><tr><th>Order Ref</th><th>Date</th><th>Type</th><th>Item</th><th>Amount</th><th>Payment</th><th>Status</th></tr></thead>
            <tbody id="tdOrdersBody"><tr><td colspan="7" style="text-align:center; padding: 16px; color: var(--text-muted);">Loading…</td></tr></tbody>
          </table>
        </div>

        <div style="display: flex; justify-content: space-between; align-items: center; margin: 16px 0 10px; gap: 8px; flex-wrap: wrap;">
          <h4 style="font-size: 12px; font-weight: 700; color: var(--text-muted); margin: 0; text-transform: uppercase; letter-spacing: 0.04em;">Staff</h4>
          <select id="tdStaffRoleFilter" class="form-control" style="font-size: 12px; height: 30px; padding: 2px 8px; min-width: 150px;" onchange="adminApp.renderTenantDetailStaff()">
            <option value="all">All Roles</option>
          </select>
        </div>
        <div class="table-responsive" style="max-height: 220px; overflow: auto;">
          <table>
            <thead><tr><th>Name</th><th>Role</th><th>Phone</th><th>Email</th><th>Status</th><th>Last Login</th></tr></thead>
            <tbody id="tdStaffBody"><tr><td colspan="6" style="text-align:center; padding: 16px; color: var(--text-muted);">Loading…</td></tr></tbody>
          </table>
        </div>

        <h4 style="font-size: 12px; font-weight: 700; color: var(--text-muted); margin: 16px 0 10px; text-transform: uppercase; letter-spacing: 0.04em;">Download Reports</h4>
        <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); gap: 8px; margin-bottom: 20px;">
          ${[
            ['parties', '', 'Parties'],
            ['orders', '', 'All Orders'],
            ['orders', 'party', 'Orders — Party-wise'],
            ['orders', 'city', 'Orders — City-wise'],
            ['orders', 'state', 'Orders — State-wise'],
            ['ledger', '', 'Ledger — All Parties'],
            ['ledger', 'party', 'Ledger — Party-wise'],
            ['expenses', '', 'Expenses'],
            ['purchases', '', 'Purchases'],
            ['invoices', '', 'Invoices'],
          ].map(([type, by, label]) => `
            <div style="display: flex; flex-direction: column; gap: 6px; border: 1px solid var(--border); border-radius: 10px; padding: 8px 10px;">
              <div style="display: flex; align-items: center; justify-content: space-between; gap: 6px;">
                <span style="font-size: 12.5px; font-weight: 600;">${label}</span>
                <span style="display: flex; gap: 4px;">
                  <button type="button" class="btn btn-outline btn-xs" onclick="adminApp.downloadTenantReport('${jid}', '${type}', 'pdf', '${by}')">PDF</button>
                  <button type="button" class="btn btn-outline btn-xs" onclick="adminApp.downloadTenantReport('${jid}', '${type}', 'excel', '${by}')">Excel</button>
                </span>
              </div>
              ${by ? `<select class="form-control td-report-filter" id="tdReport-${type}-${by}" data-by="${by}" style="font-size: 12px; height: 30px; padding: 2px 8px;"><option value="">Loading…</option></select>` : ''}
            </div>`).join('')}
        </div>

        <h4 style="font-size: 12px; font-weight: 700; color: var(--text-muted); margin: 16px 0 10px; text-transform: uppercase; letter-spacing: 0.04em;">Assign Plan</h4>
        <div style="display: flex; gap: 8px; flex-wrap: wrap; margin-bottom: 20px;">
          ${tiers.map(tier => `
            <button type="button" class="btn ${tier.id === t.subscriptionPlanId ? 'btn-primary' : 'btn-outline'} btn-sm" onclick="adminApp.assignTenantPlan('${jid}', '${this.escapeJs(tier.id)}');">
              ${esc(tier.name)} (${esc(tier.maxUsers)} users, ${esc(tier.maxShops)} shops)
            </button>`).join('')}
          <button type="button" class="btn btn-outline btn-sm" onclick="adminApp.expireTenantNow('${jid}');">End plan now</button>
        </div>

        <h4 style="font-size: 12px; font-weight: 700; color: var(--text-muted); margin-bottom: 10px; text-transform: uppercase; letter-spacing: 0.04em;">Actions</h4>
        <div style="display: flex; gap: 8px; flex-wrap: wrap;">
          <button type="button" class="btn btn-primary btn-sm" onclick="adminApp.openTenantModal('${jid}');">✏️ Edit</button>
          <button type="button" class="btn btn-outline btn-sm" onclick="adminApp.closeTenantDetailModal(); adminApp.openTenantDrilldown('${jid}');">🔍 Drill-down</button>
          <button type="button" class="btn btn-outline btn-sm" onclick="adminApp.createPaymentLink('${jid}');">💳 Payment link</button>
          <button type="button" class="btn btn-outline btn-sm" onclick="adminApp.grantTenantTrialDays('${jid}', 7);">+7 days</button>
          <button type="button" class="btn btn-outline btn-sm" onclick="adminApp.grantTenantTrialDays('${jid}', 30);">+30 days</button>
          <button type="button" class="btn btn-outline btn-sm" style="${isSuspended ? 'color:#10B981;' : 'color:#DC2626;'}" onclick="adminApp.toggleTenantSuspension('${jid}');">
            ${isSuspended ? '⚡ Unfreeze' : '🛡️ Freeze'}
          </button>
          ${phoneClean.length === 10 ? `<a class="btn btn-outline btn-sm" href="https://wa.me/91${phoneClean}" target="_blank" rel="noopener noreferrer" style="color: #059669;">💬 WhatsApp</a>` : ''}
          <button type="button" class="btn btn-outline btn-sm" style="color:#DC2626;" onclick="adminApp.closeTenantDetailModal(); adminApp.deleteTenant('${jid}');">🗑️ Delete</button>
        </div>
      `;
    }
    this.switchView('tenant-profile');
    window.scrollTo(0, 0);
    this.loadTenantDetailExtras(t.id);
  }

  // Orders + staff for the agency detail popup (client spec §2)
  async loadTenantDetailExtras(tenantId) {
    this._tdTenantId = tenantId;
    this._tdStaff = null;
    this._tdCheckouts = [];
    try {
      const res = await fetch(`/api/platform/tenant/${encodeURIComponent(tenantId)}/overview`, { headers: this.getAuthHeaders() });
      const j = await res.json();
      if (this._tdTenantId !== tenantId) return; // another agency was opened meanwhile
      if (j.success) {
        this._tdStaff = j.staff || [];
        this._tdCheckouts = (j.checkouts || []).filter(c => c.status === 'paid');
        this._tdShops = j.shops || [];
      }
    } catch (err) {
      console.warn('Agency detail load error:', err);
    }
    if (this._tdTenantId !== tenantId) return;
    if (!this._tdStaff) this._tdStaff = [];

    // Role filter options from this agency's staff
    const sel = document.getElementById('tdStaffRoleFilter');
    if (sel) {
      const roles = Array.from(new Set(this._tdStaff.map(s => s.role).filter(Boolean))).sort();
      sel.innerHTML = '<option value="all">All Roles</option>' + roles.map(r =>
        `<option value="${this.escapeHtml(r)}">${this.escapeHtml(this.formatRoleLabel(r))}</option>`).join('');
    }
    this.renderTenantDetailStaff();
    this.renderTenantDetailOrders();
    this.renderTenantReportFilters();
  }

  // Party / city / state pickers for the profile's report downloads.
  renderTenantReportFilters() {
    const shops = this._tdShops || [];
    const esc = v => this.escapeHtml(v);
    const uniq = arr => [...new Set(arr.map(v => String(v || '').trim()).filter(Boolean))].sort((a, b) => a.localeCompare(b));
    const options = {
      party: shops
        .map(s => [s.shop_id, s.shop_name || s.shop_id])
        .sort((a, b) => String(a[1]).localeCompare(String(b[1]))),
      city: uniq(shops.map(s => s.city)).map(v => [v, v]),
      state: uniq(shops.map(s => s.state)).map(v => [v, v]),
    };
    const hint = { party: 'party', city: 'city', state: 'state' };
    document.querySelectorAll('.td-report-filter').forEach(sel => {
      const list = options[sel.dataset.by] || [];
      sel.innerHTML = list.length
        ? `<option value="">Select ${hint[sel.dataset.by]}…</option>` + list.map(([v, l]) => `<option value="${esc(v)}">${esc(l)}</option>`).join('')
        : `<option value="">No ${hint[sel.dataset.by]} data</option>`;
    });
  }

  formatRoleLabel(role) {
    return String(role || '').split('_').map(w => w ? w.charAt(0).toUpperCase() + w.slice(1) : '').join(' ');
  }

  renderTenantDetailStaff() {
    const tbody = document.getElementById('tdStaffBody');
    if (!tbody) return;
    const role = document.getElementById('tdStaffRoleFilter')?.value || 'all';
    const rows = (this._tdStaff || []).filter(s => role === 'all' || s.role === role);
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding: 16px; color: var(--text-muted);">No staff found</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(s => {
      const status = s.is_active === false ? 'Suspended' : this.formatRoleLabel(s.account_status || 'active');
      return `
        <tr>
          <td>${this.escapeHtml(s.name || '—')}</td>
          <td>${this.escapeHtml(this.formatRoleLabel(s.role))}</td>
          <td>${this.escapeHtml(s.phone || '—')}</td>
          <td>${this.escapeHtml(s.email || '—')}</td>
          <td>${this.escapeHtml(status)}</td>
          <td>${this.escapeHtml(s.last_login_at ? new Date(s.last_login_at).toLocaleString('en-IN') : 'Never')}</td>
        </tr>`;
    }).join('');
  }

  renderTenantDetailOrders() {
    const tbody = document.getElementById('tdOrdersBody');
    if (!tbody) return;
    const tenantId = this._tdTenantId;
    const subs = (this._tdCheckouts || []).map(c => ({
      ref: c.id, date: c.paid_at || c.created_at, type: 'Subscription', item: c.quote?.planName || c.quote?.planId || '',
      amount: (Number(c.amount || 0) - Number(c.quote?.hardwareAmount || 0)) / 100, payment: 'Paid', status: '—',
    }));
    const hw = (this.printerOrders || []).filter(o => o.tenantId === tenantId).map(o => ({
      ref: o.orderId || o.id, date: o.orderedAt, type: 'Hardware', item: o.printerItem, amount: o.price,
      payment: this.formatRoleLabel(o.paymentStatus), status: o.status,
    }));
    const rows = subs.concat(hw).sort((a, b) => new Date(b.date || 0) - new Date(a.date || 0));
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 16px; color: var(--text-muted);">No orders yet</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(r => {
      const d = r.date ? new Date(r.date) : null;
      return `
        <tr>
          <td><strong style="font-family: var(--font-mono, monospace); font-size: 11.5px;">${this.escapeHtml(r.ref)}</strong></td>
          <td>${this.escapeHtml(d && !isNaN(d) ? d.toLocaleDateString('en-IN') : '—')}</td>
          <td>${this.escapeHtml(r.type)}</td>
          <td>${this.escapeHtml(r.item || '')}</td>
          <td><strong>${this.escapeHtml(this.formatRupees(r.amount))}</strong></td>
          <td>${this.escapeHtml(r.payment || '—')}</td>
          <td>${this.escapeHtml(r.status || '—')}</td>
        </tr>`;
    }).join('');
  }

  // ---- Agency report downloads (PDF via jsPDF, Excel via SheetJS) ----
  loadVendorScript(src, globalName) {
    if (window[globalName]) return Promise.resolve();
    this._vendorLoads = this._vendorLoads || {};
    if (!this._vendorLoads[src]) {
      this._vendorLoads[src] = new Promise((resolve, reject) => {
        const s = document.createElement('script');
        s.src = src;
        s.onload = () => resolve();
        s.onerror = () => { delete this._vendorLoads[src]; reject(new Error(`Could not load ${src}`)); };
        document.head.appendChild(s);
      });
    }
    return this._vendorLoads[src];
  }

  async downloadTenantReport(tenantId, type, format, by = '') {
    try {
      const params = new URLSearchParams({ type });
      if (by) {
        const value = document.getElementById(`tdReport-${type}-${by}`)?.value || '';
        if (!value) { this.showToast(`Select a ${by} first.`, '⚠️', 'warning'); return; }
        params.set(by === 'party' ? 'partyId' : by, value);
      }
      const res = await fetch(`/api/platform/tenant/${encodeURIComponent(tenantId)}/report?${params}`, { headers: this.getAuthHeaders() });
      const report = await res.json();
      if (!report.success) { this.showToast(report.error || 'Could not load report', '⚠️', 'warning'); return; }
      if (!report.rows.length) { this.showToast(`No ${report.title} records for ${report.agency}.`, 'ℹ️'); return; }
      const safe = s => String(s || '').replace(/[^A-Za-z0-9]+/g, '_').replace(/^_|_$/g, '');
      const fileBase = `${safe(report.agency)}_${safe(report.title)}_${new Date().toISOString().slice(0, 10)}`;
      if (format === 'excel') await this.writeReportExcel(report, fileBase);
      else await this.writeReportPdf(report, fileBase);
      if (report.truncated) this.showToast('Report limited to the first 5,000 rows.', '⚠️', 'warning');
      else this.showToast(`${report.title} downloaded (${report.rows.length} rows).`, '✓');
    } catch (err) {
      console.warn('Report download error:', err);
      this.showToast(`Report download failed: ${err.message}`, '⚠️', 'warning');
    }
  }

  async writeReportExcel(report, fileBase) {
    await this.loadVendorScript('/vendor/xlsx.full.min.js', 'XLSX');
    const header = report.columns.map(c => c.label);
    const data = report.rows.map(r => report.columns.map(c => r[c.key]));
    const ws = window.XLSX.utils.aoa_to_sheet([
      [`${report.agency} — ${report.title}`], [`Generated ${new Date().toLocaleString('en-IN')}`], [], header, ...data,
    ]);
    const wb = window.XLSX.utils.book_new();
    window.XLSX.utils.book_append_sheet(wb, ws, report.title.slice(0, 31).replace(/[\\/?*[\]:]/g, ''));
    window.XLSX.writeFile(wb, `${fileBase}.xlsx`);
  }

  async writeReportPdf(report, fileBase) {
    await this.loadVendorScript('/vendor/jspdf.umd.min.js', 'jspdf');
    const doc = new window.jspdf.jsPDF({ orientation: 'landscape', unit: 'pt', format: 'a4' });
    const pageW = doc.internal.pageSize.getWidth();
    const pageH = doc.internal.pageSize.getHeight();
    const margin = 32;
    const cols = report.columns;
    // Text columns get more room than numbers/dates
    const WIDE = ['description', 'party', 'supplier', 'notes', 'title', 'category', 'orderId', 'invoiceNo', 'purchaseId', 'salesman', 'agency', 'plan', 'item', 'ref'];
    const weights = cols.map(c => (c.key === 'description' ? 3 : WIDE.includes(c.key) ? 1.8 : 1));
    const unit = (pageW - margin * 2) / weights.reduce((a, b) => a + b, 0);
    const widths = weights.map(w => w * unit);
    const xs = widths.map((_, i) => margin + widths.slice(0, i).reduce((a, b) => a + b, 0));
    const rowH = 18;
    // Built-in PDF fonts have no ₹ glyph, so amounts are written as plain numbers.
    const cell = v => (typeof v === 'number' ? v.toLocaleString('en-IN', { maximumFractionDigits: 2 }) : String(v ?? ''));
    const fit = (text, width) => {
      let t = text;
      while (t.length > 1 && doc.getTextWidth(t) > width - 8) t = t.slice(0, -1);
      return t.length < text.length ? t.slice(0, -1) + '…' : t;
    };
    let y = margin;
    const drawHeader = () => {
      doc.setFont('helvetica', 'bold'); doc.setFontSize(9);
      doc.setFillColor(226, 232, 240); doc.rect(margin, y, pageW - margin * 2, rowH, 'F');
      cols.forEach((c, i) => doc.text(fit(c.label, widths[i]), xs[i] + 4, y + 12));
      y += rowH;
      doc.setFont('helvetica', 'normal');
    };
    doc.setFont('helvetica', 'bold'); doc.setFontSize(14);
    doc.text(`${report.agency} — ${report.title}`, margin, y + 10);
    doc.setFont('helvetica', 'normal'); doc.setFontSize(9);
    doc.text(`Generated ${new Date().toLocaleString('en-IN')}  •  ${report.rows.length} records  •  Amounts in INR`, margin, y + 26);
    y += 40;
    drawHeader();
    report.rows.forEach((r, idx) => {
      if (y + rowH > pageH - margin) { doc.addPage(); y = margin; drawHeader(); }
      if (idx % 2 === 1) { doc.setFillColor(248, 250, 252); doc.rect(margin, y, pageW - margin * 2, rowH, 'F'); }
      doc.setFontSize(8.5);
      cols.forEach((c, i) => doc.text(fit(cell(r[c.key]), widths[i]), xs[i] + 4, y + 12));
      y += rowH;
    });
    doc.save(`${fileBase}.pdf`);
  }

  // The profile is now a page: "closing" it returns to the Agencies list.
  closeTenantDetailModal() {
    if (this.currentView === 'tenant-profile') this.switchView('tenants');
  }

  renderRemoteAppControl() {
    const container = document.getElementById('remoteFeaturesContainer');
    if (!container) return;

    if (!this.remoteConfig) {
      this.remoteConfig = JSON.parse(JSON.stringify(DEFAULT_REMOTE_CONFIG));
    }

    container.innerHTML = REMOTE_MODULES_METADATA.map(mod => {
      const isEnabled = this.remoteConfig.featureFlags ? (this.remoteConfig.featureFlags[mod.key] !== false) : true;
      const title = mod.name || mod.title || mod.key;
      const category = mod.category || 'Core Feature';
      const description = mod.description || mod.desc || 'Feature configuration and status.';

      return `
        <div class="feature-toggle-card ${isEnabled ? '' : 'disabled'}">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; gap: 12px; width: 100%;">
            <div class="feature-info" style="flex: 1;">
              <div style="display: flex; align-items: center; justify-content: space-between; margin-bottom: 4px;">
                <span style="font-size: 10px; color: var(--text-tertiary); text-transform: uppercase; font-weight: 600; letter-spacing: 0.05em;">${category}</span>
                <span class="badge ${isEnabled ? 'badge-active' : 'badge-expired'}" style="font-size: 9.5px; padding: 1px 5px;">
                  ${isEnabled ? 'Active' : 'Disabled'}
                </span>
              </div>
              <h4 style="font-size: 13px; font-weight: 600; color: var(--text-main); margin-bottom: 4px;">${title}</h4>
              <p style="font-size: 11.5px; color: var(--text-muted); line-height: 1.4; margin-bottom: 10px;">${description}</p>
              <div style="display: flex; align-items: center; justify-content: space-between; border-top: 1px solid var(--border); padding-top: 8px;">
                <label class="switch">
                  <input type="checkbox" ${isEnabled ? 'checked' : ''} onchange="adminApp.onFeatureToggleChanged('${mod.key}', this.checked)">
                  <span class="slider"></span>
                </label>
              </div>
            </div>
          </div>
        </div>
      `;
    }).join('');

    // Fill version & security inputs
    const elMinVersion = document.getElementById('ctrlMinAppVersion');
    if (elMinVersion) elMinVersion.value = this.remoteConfig.minAppVersion || 'v2.4.1';

    const elUpdateUrl = document.getElementById('ctrlUpdateUrl');
    if (elUpdateUrl) elUpdateUrl.value = this.remoteConfig.updateUrl || 'https://play.google.com/store/apps/details?id=com.salesarmy.app';

    const elHardUpdate = document.getElementById('ctrlEnforceHardUpdate');
    if (elHardUpdate) elHardUpdate.checked = this.remoteConfig.enforceHardUpdate !== false;

    const elSmsProvider = document.getElementById('ctrlSmsProvider');
    if (elSmsProvider) elSmsProvider.value = this.remoteConfig.smsProvider || 'firebase';

    const elOtpDigits = document.getElementById('ctrlOtpDigits');
    if (elOtpDigits) elOtpDigits.value = String(this.remoteConfig.otpDigits || 6);

    const elSmsMode = document.getElementById('ctrlSmsMode');
    if (elSmsMode) elSmsMode.value = this.remoteConfig.smsMode || 'live';

    const elEnforceOtp = document.getElementById('ctrlEnforceOtp');
    if (elEnforceOtp) elEnforceOtp.checked = this.remoteConfig.enforceOtp !== false;

    // Fill maintenance inputs
    const maintActive = this.remoteConfig.maintenance?.active === true;
    const elMaintCheck = document.getElementById('ctrlMaintenanceActive');
    if (elMaintCheck) elMaintCheck.checked = maintActive;

    const elMaintLabel = document.getElementById('maintenanceStatusLabel');
    if (elMaintLabel) {
      elMaintLabel.textContent = maintActive ? '🚨 MAINTENANCE ACTIVE (APPS LOCKED)' : 'MAINTENANCE IS OFF';
      elMaintLabel.style.color = maintActive ? '#DC2626' : '#92400E';
    }

    const elMaintMsg = document.getElementById('ctrlMaintenanceMessage');
    if (elMaintMsg) elMaintMsg.value = this.remoteConfig.maintenance?.message || 'SalesArmy is currently undergoing scheduled platform maintenance. Please check back shortly.';

    const elMaintEta = document.getElementById('ctrlMaintenanceEta');
    if (elMaintEta) elMaintEta.value = this.remoteConfig.maintenance?.eta || '30 minutes';

  }

  _persistRemoteConfig(eventName) {
    this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig);
    this.saveToBridge({ remoteConfig: this.remoteConfig });
    this.syncRemoteConfigToSupabase();
    this.broadcastChange(eventName, this.remoteConfig);
  }

  onFeatureToggleChanged(key, enabled) {
    if (!this.remoteConfig) {
      this.remoteConfig = JSON.parse(JSON.stringify(DEFAULT_REMOTE_CONFIG));
    }
    this.remoteConfig.featureFlags[key] = enabled;
    this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig); this.saveToBridge({ remoteConfig: this.remoteConfig });
    this.syncRemoteConfigToSupabase();
    this.broadcastChange('remote_config_update', this.remoteConfig);

    // Direct Real-Time Sync to Cloud Firestore
    if (this.db) {
      try {
        const payload = {
          featureFlags: { ...this.remoteConfig.featureFlags },
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        };
        this.db.collection('platform_settings').doc('remote_config').set(payload, { merge: true });
        this.db.collection('platformSettings').doc('remote_config').set(payload, { merge: true });
      } catch (err) {
        console.warn('Firestore remote_config sync error:', err);
      }
    }

    const mod = REMOTE_MODULES_METADATA.find(m => m.key === key);
    const modName = mod ? (mod.name || mod.title) : key;
    this.showToast(`Module "${modName}" ${enabled ? 'Enabled' : 'Disabled (Kill Switch Active)'}!`, enabled ? '⚡' : '⊘');
    this.renderRemoteAppControl();
  }

  onMaintenanceToggleChanged(enabled) {
    if (!this.remoteConfig) {
      this.remoteConfig = JSON.parse(JSON.stringify(DEFAULT_REMOTE_CONFIG));
    }
    if (!this.remoteConfig.maintenance) {
      this.remoteConfig.maintenance = { active: false, message: '', eta: '' };
    }
    this.remoteConfig.maintenance.active = enabled;
    // Keep what the admin typed in the message / ETA boxes (they were lost before)
    const typedMsg = document.getElementById('ctrlMaintenanceMessage')?.value.trim();
    const typedEta = document.getElementById('ctrlMaintenanceEta')?.value.trim();
    if (typedMsg) this.remoteConfig.maintenance.message = typedMsg;
    if (typedEta) this.remoteConfig.maintenance.eta = typedEta;

    // Also sync with settings
    this.settings.maintenanceMode = enabled;
    this.saveData(STORAGE_KEYS.SETTINGS, this.settings);
    this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig); this.saveToBridge({ remoteConfig: this.remoteConfig });
    this.syncRemoteConfigToSupabase();

    // Direct Real-Time Sync to Cloud Firestore
    if (this.db) {
      try {
        const maintPayload = {
          maintenance: { ...this.remoteConfig.maintenance },
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        };
        this.db.collection('platform_settings').doc('remote_config').set(maintPayload, { merge: true });
        this.db.collection('platformSettings').doc('remote_config').set(maintPayload, { merge: true });
        this.db.collection('platform_settings').doc('general').set({ maintenanceMode: enabled, updatedAt: firebase.firestore.FieldValue.serverTimestamp() }, { merge: true });
        this.db.collection('platformSettings').doc('general').set({ maintenanceMode: enabled, updatedAt: firebase.firestore.FieldValue.serverTimestamp() }, { merge: true });
      } catch (err) {
        console.warn('Firestore maintenance sync error:', err);
      }
    }

    const elMaintLabel = document.getElementById('maintenanceStatusLabel');
    if (elMaintLabel) {
      elMaintLabel.textContent = enabled ? '🚨 MAINTENANCE ACTIVE (APPS LOCKED)' : 'MAINTENANCE IS OFF';
      elMaintLabel.style.color = enabled ? '#DC2626' : '#92400E';
    }

    this.broadcastChange('maintenance_mode_update', this.remoteConfig.maintenance);
    this.showToast(`Global Maintenance Mode is now ${enabled ? 'ACTIVE (Mobile Apps Locked)' : 'OFF'}.`, enabled ? '⚠️' : '✓');
  }

  saveAndBroadcastRemoteConfig() {
    if (!this.remoteConfig) {
      this.remoteConfig = JSON.parse(JSON.stringify(DEFAULT_REMOTE_CONFIG));
    }

    const minVersion = document.getElementById('ctrlMinAppVersion')?.value.trim() || 'v2.4.1';
    const updateUrl = document.getElementById('ctrlUpdateUrl')?.value.trim() || 'https://play.google.com/store/apps/details?id=com.salesarmy.app';
    const hardUpdate = document.getElementById('ctrlEnforceHardUpdate')?.checked ?? true;
    const smsProvider = document.getElementById('ctrlSmsProvider')?.value || 'firebase';
    const otpDigits = parseInt(document.getElementById('ctrlOtpDigits')?.value) || 6;
    const smsMode = document.getElementById('ctrlSmsMode')?.value || 'live';
    const enforceOtp = document.getElementById('ctrlEnforceOtp')?.checked ?? false;
    const maintActive = document.getElementById('ctrlMaintenanceActive')?.checked ?? false;
    const maintMsg = document.getElementById('ctrlMaintenanceMessage')?.value.trim() || 'SalesArmy is currently undergoing scheduled platform maintenance. Please check back shortly.';
    const maintEta = document.getElementById('ctrlMaintenanceEta')?.value.trim() || '30 minutes';

    this.remoteConfig.minAppVersion = minVersion;
    this.remoteConfig.updateUrl = updateUrl;
    this.remoteConfig.enforceHardUpdate = hardUpdate;
    this.remoteConfig.smsProvider = smsProvider;
    this.remoteConfig.otpDigits = otpDigits;
    this.remoteConfig.smsMode = smsMode;
    this.remoteConfig.enforceOtp = enforceOtp;
    this.remoteConfig.maintenance = {
      active: maintActive,
      message: maintMsg,
      eta: maintEta,
    };

    this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig); this.saveToBridge({ remoteConfig: this.remoteConfig });
    this.syncRemoteConfigToSupabase();
    this.broadcastChange('remote_config_pushed', this.remoteConfig);

    // Direct Real-Time Sync to Cloud Firestore
    if (this.db) {
      try {
        const payload = {
          featureFlags: { ...this.remoteConfig.featureFlags },
          minAppVersion: this.remoteConfig.minAppVersion,
          updateUrl: this.remoteConfig.updateUrl,
          enforceHardUpdate: this.remoteConfig.enforceHardUpdate,
          smsProvider: this.remoteConfig.smsProvider,
          otpDigits: this.remoteConfig.otpDigits,
          smsMode: this.remoteConfig.smsMode,
          enforceOtp: this.remoteConfig.enforceOtp,
          maintenance: { ...this.remoteConfig.maintenance },
          updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        };
        this.db.collection('platform_settings').doc('remote_config').set(payload, { merge: true });
        this.db.collection('platformSettings').doc('remote_config').set(payload, { merge: true });
      } catch (err) {
        console.warn('Firestore remote config push error:', err);
      }
    }

    this.showToast('All Remote Mobile Configurations pushed to active clients!', '🚀');
    this.renderRemoteAppControl();
  }

  resetDefaultFeatureFlags() {
    if (confirm('Reset all remote feature flags and mobile policies to default values?')) {
      this.remoteConfig = JSON.parse(JSON.stringify(DEFAULT_REMOTE_CONFIG));
      this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig); this.saveToBridge({ remoteConfig: this.remoteConfig });
      this.broadcastChange('remote_config_reset', this.remoteConfig);

      if (this.db) {
        try {
          const payload = {
            featureFlags: { ...this.remoteConfig.featureFlags },
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
          };
          this.db.collection('platform_settings').doc('remote_config').set(payload, { merge: true });
          this.db.collection('platformSettings').doc('remote_config').set(payload, { merge: true });
        } catch (_) {}
      }

      this.showToast('Remote feature flags reset to defaults!', '🔄');
      this.renderRemoteAppControl();
    }
  }

  // --- VIEW: In-App Broadcast Center ---
  renderBroadcastCenter() {
    if (!this.broadcast) {
      this.broadcast = JSON.parse(JSON.stringify(DEFAULT_BROADCAST));
    }

    // 1. Populate Target Tenant dropdown dynamically from this.tenants
    const selTenant = document.getElementById('bcastTargetTenant');
    if (selTenant) {
      const current = selTenant.value || this.broadcast.targetTenant || 'all';
      selTenant.innerHTML = '<option value="all">🌐 All Agencies & Tenants (Global Broadcast)</option>' +
        (this.tenants || []).map(t => {
          const name = t.firmName || t.name || t.id;
          const loc = t.city ? ` (${t.city})` : '';
          const planTag = (t.subscriptionPlanId || t.planName || 'Grow').toUpperCase();
          return `<option value="${this.escapeHtml(t.id || t.tenantId)}">🏢 ${this.escapeHtml(name)}${this.escapeHtml(loc)} [${planTag}]</option>`;
        }).join('');
      selTenant.value = current;
    }

    // 2. Populate Target Plan dropdown
    const selPlan = document.getElementById('bcastTargetPlan');
    if (selPlan) {
      selPlan.value = this.broadcast.targetPlan || this.broadcast.targetRole || 'all';
    }

    // 3. Populate inputs
    const elTitle = document.getElementById('bcastTitle');
    if (elTitle) elTitle.value = this.broadcast.title || '';

    const elMsg = document.getElementById('bcastMessage');
    if (elMsg) elMsg.value = this.broadcast.message || '';

    const elType = document.getElementById('bcastType');
    if (elType) elType.value = this.broadcast.type || 'info';

    const elAction = document.getElementById('bcastActionText');
    if (elAction) elAction.value = this.broadcast.actionText || 'Got It';

    const elUrl = document.getElementById('bcastActionUrl');
    if (elUrl) elUrl.value = this.broadcast.actionUrl || '/orders';

    const elDismiss = document.getElementById('bcastDismissible');
    if (elDismiss) elDismiss.checked = this.broadcast.dismissible !== false;

    const elActive = document.getElementById('bcastActive');
    if (elActive) elActive.checked = this.broadcast.active !== false;

    const elSound = document.getElementById('bcastSound');
    if (elSound) elSound.checked = this.broadcast.playSound !== false;

    // 4. Highlight selected priority pill
    this.highlightPriorityPill(this.broadcast.type || 'info');

    // 5. Reset phone mockup dismissed state
    this.phoneMockupDismissed = false;

    // 6. Update clock and live preview
    this.updatePhoneClock();
    this.updateBroadcastMockup();

    // 7. Render Notifications History Table
    this.renderNotificationsTable();
  }

  highlightPriorityPill(type) {
    document.querySelectorAll('.priority-pill').forEach(pill => {
      pill.classList.toggle('active', pill.dataset.type === type);
    });
  }

  setBroadcastType(type) {
    const elType = document.getElementById('bcastType');
    if (elType) elType.value = type;
    this.highlightPriorityPill(type);
    this.updateBroadcastMockup();
  }

  updatePhoneClock() {
    const clockEl = document.getElementById('phoneClockTime');
    if (clockEl) {
      const now = new Date();
      const hours = String(now.getHours()).padStart(2, '0');
      const mins = String(now.getMinutes()).padStart(2, '0');
      clockEl.textContent = `${hours}:${mins}`;
    }
  }

  updateBroadcastMockup() {
    const title = document.getElementById('bcastTitle')?.value.trim() || '';
    const message = document.getElementById('bcastMessage')?.value.trim() || '';
    const type = document.getElementById('bcastType')?.value || 'info';
    const actionText = document.getElementById('bcastActionText')?.value.trim() || '';
    const targetTenant = document.getElementById('bcastTargetTenant')?.value || 'all';
    const targetPlan = document.getElementById('bcastTargetPlan')?.value || 'all';
    const dismissible = document.getElementById('bcastDismissible')?.checked ?? true;
    // Publishing always makes the banner live; use "Clear banner" to stop it.
    const active = true;
    const activeBox = document.getElementById('bcastActive');
    if (activeBox) activeBox.checked = true;

    // Update character counters
    const titleCountEl = document.getElementById('bcastTitleCount');
    if (titleCountEl) titleCountEl.textContent = `${title.length} / 60`;
    const msgCountEl = document.getElementById('bcastMessageCount');
    if (msgCountEl) msgCountEl.textContent = `${message.length} / 220`;

    // Update top panel status badge
    const statusBadge = document.getElementById('broadcastStatusBadge');
    if (statusBadge) {
      if (active) {
        statusBadge.className = 'badge badge-delivered';
        statusBadge.textContent = '● Active & Broadcasting';
      } else {
        statusBadge.className = 'badge badge-freemium';
        statusBadge.textContent = '○ Broadcast Paused';
      }
    }

    // Filter tenants matching targetTenant & targetPlan
    let filteredTenants = (this.tenants || []).slice();
    if (targetTenant !== 'all') {
      filteredTenants = filteredTenants.filter(t => (t.id || t.tenantId) === targetTenant);
    }
    if (targetPlan !== 'all') {
      filteredTenants = filteredTenants.filter(t => {
        const plan = (t.subscriptionPlanId || t.planName || '').toLowerCase();
        const status = (t.subscriptionStatus || '').toLowerCase();
        if (targetPlan === 'enterprise') return plan.includes('enterprise') || plan.includes('platinum');
        if (targetPlan === 'grow') return plan.includes('grow') || plan.includes('growth') || plan.includes('gold');
        if (targetPlan === 'startup') return plan.includes('startup') || plan.includes('silver');
        if (targetPlan === 'expired' || targetPlan === 'freemium') return status === 'expired';
        if (targetPlan === 'trial') return status === 'trial';
        return true;
      });
    }

    const tenantIds = new Set(filteredTenants.map(t => t.id || t.tenantId));
    let matchingUsers = (this.users || []).filter(u => tenantIds.has(u.tenantId || u.tenant_id));
    if (tenantIds.size === 0 && targetTenant === 'all' && targetPlan === 'all') {
      matchingUsers = this.users || [];
    }

    // Update Audience Reach Badge
    const reachBadge = document.getElementById('bcastReachBadge');
    if (reachBadge) {
      const aCount = filteredTenants.length;
      const uCount = matchingUsers.length || Math.max(1, aCount * 2);
      const planName = targetPlan === 'all' ? 'All Plans' : targetPlan.toUpperCase() + ' Tier';
      if (aCount === 0) {
        reachBadge.className = 'badge badge-freemium';
        reachBadge.textContent = `Reach: 0 Agencies match "${planName}"`;
      } else {
        reachBadge.className = 'badge badge-delivered';
        reachBadge.textContent = `Reach: ${aCount} ${aCount === 1 ? 'Agency' : 'Agencies'} (${planName}) • ~${uCount} Users`;
      }
    }

    // Update phone app bar agency name & avatar
    const nameEl = document.getElementById('phoneAgencyName');
    const avatarEl = document.getElementById('phoneAgencyAvatar');
    const planSuffix = targetPlan === 'all' ? 'All Plans' : `${targetPlan.toUpperCase()} Tier`;

    if (targetTenant === 'all') {
      if (nameEl) nameEl.textContent = `SalesArmy Global (${planSuffix})`;
      if (avatarEl) {
        avatarEl.textContent = 'SA';
        avatarEl.style.background = 'linear-gradient(135deg, #3B82F6, #1D4ED8)';
      }
    } else {
      const tenant = (this.tenants || []).find(t => (t.id || t.tenantId) === targetTenant);
      const firm = tenant ? (tenant.firmName || tenant.name || 'Agency') : 'Partner Agency';
      if (nameEl) nameEl.textContent = `${firm} (${planSuffix})`;
      if (avatarEl) {
        avatarEl.textContent = firm.substring(0, 2).toUpperCase();
        avatarEl.style.background = this._getTenantAvatarGradient(tenant?.planName, tenant?.subscriptionStatus);
      }
    }

    // Render banner in smartphone slot
    const slot = document.getElementById('phoneBroadcastSlot');
    if (!slot) return;

    if (!active) {
      slot.innerHTML = `
        <div style="margin: 6px 10px; padding: 6px 10px; background: rgba(0,0,0,0.04); border-radius: 8px; font-size: 9.5px; color: #94A3B8; text-align: center;">
          [Broadcast Banner Currently Inactive / Paused]
        </div>
      `;
      return;
    }

    if (this.phoneMockupDismissed) {
      slot.innerHTML = `
        <div class="banner-undo-chip" onclick="adminApp.restorePhoneMockupBanner()">
          <span>✕ Banner Dismissed by User</span>
          <strong style="color: #3B82F6;">Restore ↺</strong>
        </div>
      `;
      return;
    }

    const icons = {
      info: 'ℹ️',
      warning: '⚠️',
      critical: '🚨',
      festive: '🎉',
      success: '✅'
    };
    const icon = icons[type] || '📣';

    slot.innerHTML = `
      <div class="mobile-banner-widget ${type}" id="phoneActiveBannerWidget">
        <div class="banner-headline-row">
          <div class="banner-title-text">
            <span>${icon}</span>
            <span>${this.escapeHtml(title || 'Announcement Headline')}</span>
          </div>
          ${dismissible ? `<button type="button" class="banner-dismiss-btn" onclick="adminApp.dismissPhoneMockupBanner()" title="Dismiss Banner">✕</button>` : ''}
        </div>
        <div class="banner-message-text">${this.escapeHtml(message || 'Details will appear here on active mobile screens.')}</div>
        ${actionText ? `
          <button type="button" class="banner-action-btn" onclick="adminApp.clickPhoneBannerAction('${this.escapeJs(actionText)}')">
            <span>${this.escapeHtml(actionText)}</span>
            <span style="font-size: 8px;">→</span>
          </button>
        ` : ''}
      </div>
    `;
  }

  dismissPhoneMockupBanner() {
    this.phoneMockupDismissed = true;
    this.updateBroadcastMockup();
    this.showPhoneToast('Banner dismissed on mobile');
  }

  restorePhoneMockupBanner() {
    this.phoneMockupDismissed = false;
    this.updateBroadcastMockup();
    this.showPhoneToast('Banner restored to view');
  }

  clickPhoneBannerAction(actionText) {
    const url = document.getElementById('bcastActionUrl')?.value || '/orders';
    this.showPhoneToast(`Action: "${actionText}" -> ${url}`);
  }

  showPhoneToast(msg) {
    const toast = document.getElementById('phoneToastFeedback');
    if (!toast) return;
    toast.textContent = msg;
    toast.style.display = 'block';
    if (this._phoneToastTimer) clearTimeout(this._phoneToastTimer);
    this._phoneToastTimer = setTimeout(() => {
      toast.style.display = 'none';
    }, 2200);
  }

  setPhoneScreen(screen) {
    const dashContent = document.getElementById('phoneViewDashboardContent');
    const ordersContent = document.getElementById('phoneViewOrdersContent');
    const shopsContent = document.getElementById('phoneViewShopsContent');

    if (dashContent) dashContent.style.display = screen === 'dashboard' ? 'block' : 'none';
    if (ordersContent) ordersContent.style.display = screen === 'orders' ? 'block' : 'none';
    if (shopsContent) shopsContent.style.display = screen === 'shops' ? 'block' : 'none';

    document.getElementById('btnPhoneTabDashboard')?.classList.toggle('active', screen === 'dashboard');
    document.getElementById('btnPhoneTabOrders')?.classList.toggle('active', screen === 'orders');
    document.getElementById('btnPhoneTabShops')?.classList.toggle('active', screen === 'shops');

    document.getElementById('btnPhoneNavHome')?.classList.toggle('active', screen === 'dashboard');
    document.getElementById('btnPhoneNavOrders')?.classList.toggle('active', screen === 'orders');
    document.getElementById('btnPhoneNavShops')?.classList.toggle('active', screen === 'shops');

    this.showPhoneToast(`Mobile View: ${screen.toUpperCase()}`);
  }

  togglePhoneTheme() {
    const phoneScreen = document.getElementById('smartphoneScreen');
    const themeIcon = document.getElementById('phoneThemeIcon');
    if (phoneScreen) {
      phoneScreen.classList.toggle('dark-mode');
      const isDark = phoneScreen.classList.contains('dark-mode');
      if (themeIcon) themeIcon.textContent = isDark ? '☀️' : '🌙';
      this.showPhoneToast(isDark ? 'Dark Theme Active' : 'Light Theme Active');
    }
  }

  triggerPhonePushSimulation() {
    const title = document.getElementById('bcastTitle')?.value.trim() || 'Platform Announcement';
    const message = document.getElementById('bcastMessage')?.value.trim() || 'Emergency broadcast notification alert.';
    const overlay = document.getElementById('phonePushOverlay');
    const pushTitle = document.getElementById('phonePushTitle');
    const pushMsg = document.getElementById('phonePushMessage');

    if (pushTitle) pushTitle.textContent = title;
    if (pushMsg) pushMsg.textContent = message;

    if (overlay) {
      overlay.style.display = 'flex';
      overlay.style.animation = 'none';
      overlay.offsetHeight; // reflow
      overlay.style.animation = 'headsUpDrop 0.35s cubic-bezier(0.16, 1, 0.3, 1)';

      if (this._pushOverlayTimer) clearTimeout(this._pushOverlayTimer);
      this._pushOverlayTimer = setTimeout(() => {
        overlay.style.display = 'none';
      }, 4200);
    }
    this.showPhoneToast('🔔 Push Alert Triggered');
  }

  applyBroadcastPreset(presetKey) {
    const presets = {
      gst_downtime: {
        title: '⚠️ GST Portal Scheduled Maintenance',
        message: 'Government GST e-way / e-invoice servers are undergoing maintenance tonight from 11 PM to 2 AM. Offline kaccha billing remains active.',
        type: 'warning',
        actionText: 'Read Advisory',
        actionUrl: '/help/gst-offline',
        targetPlan: 'all',
        targetTenant: 'all'
      },
      festival_offer: {
        title: '🎉 Festive Season Bonus - 25% OFF Annual Pro',
        message: 'Upgrade now and get ₹1,000 off on Annual Platinum Pro plans with code FESTIVE25. Unlimited field staff and Bluetooth thermal printing included!',
        type: 'festive',
        actionText: 'Claim 25% Off',
        actionUrl: '/pricing',
        targetPlan: 'expired',
        targetTenant: 'all'
      },
      system_upgrade: {
        title: '🚀 SalesArmy v2.5.0 Released',
        message: 'New features available: Multi-warehouse van stock tracking and live Soundbox voice confirmation. Update now from Play Store.',
        type: 'info',
        actionText: "What's New",
        actionUrl: '/whats-new',
        targetPlan: 'all',
        targetTenant: 'all'
      },
      payment_success: {
        title: '💳 Instant Settlement UPI QR Live',
        message: 'Daily collections now settle directly into your linked bank account within 15 minutes. Verify UPI details under Settings.',
        type: 'success',
        actionText: 'Setup QR',
        actionUrl: '/settings/payment',
        targetPlan: 'grow',
        targetTenant: 'all'
      },
      monsoon_alert: {
        title: '🌧️ Severe Weather Route Advisory',
        message: 'Heavy rain forecast across western beat routes today. Van drivers advised to prioritize dry godowns and high-volume kirana outlets.',
        type: 'warning',
        actionText: 'View Route',
        actionUrl: '/visits',
        targetPlan: 'all',
        targetTenant: 'all'
      },
      critical_lock: {
        title: '🚨 Security Passcode Verification',
        message: 'Mandatory payment security update: Please re-authenticate your mobile device biometric credentials before next bill dispatch.',
        type: 'critical',
        actionText: 'Verify Now',
        actionUrl: '/security',
        targetPlan: 'all',
        targetTenant: 'all'
      },
    };

    const p = presets[presetKey];
    if (!p) return;

    const elTitle = document.getElementById('bcastTitle');
    if (elTitle) elTitle.value = p.title;

    const elMsg = document.getElementById('bcastMessage');
    if (elMsg) elMsg.value = p.message;

    const elType = document.getElementById('bcastType');
    if (elType) elType.value = p.type;

    const elAction = document.getElementById('bcastActionText');
    if (elAction) elAction.value = p.actionText;

    const elUrl = document.getElementById('bcastActionUrl');
    if (elUrl) elUrl.value = p.actionUrl;

    const elTenant = document.getElementById('bcastTargetTenant');
    if (elTenant) elTenant.value = p.targetTenant || 'all';

    const elPlan = document.getElementById('bcastTargetPlan');
    if (elPlan) elPlan.value = p.targetPlan || 'all';

    const elActive = document.getElementById('bcastActive');
    if (elActive) elActive.checked = true;

    this.phoneMockupDismissed = false;
    this.highlightPriorityPill(p.type);
    this.updateBroadcastMockup();
    this.showToast(`Template applied: "${p.title}"`, '✨');
  }

  async publishBroadcastBanner() {
    const title = document.getElementById('bcastTitle')?.value.trim();
    const message = document.getElementById('bcastMessage')?.value.trim();
    const type = document.getElementById('bcastType')?.value || 'info';
    const targetTenant = document.getElementById('bcastTargetTenant')?.value || 'all';
    const targetPlan = document.getElementById('bcastTargetPlan')?.value || 'all';
    const actionText = document.getElementById('bcastActionText')?.value.trim() || '';
    const actionUrl = document.getElementById('bcastActionUrl')?.value.trim() || '';
    const dismissible = document.getElementById('bcastDismissible')?.checked ?? true;
    // Publishing always makes the banner live; use "Clear banner" to stop it.
    const active = true;
    const activeBox = document.getElementById('bcastActive');
    if (activeBox) activeBox.checked = true;
    const playSound = document.getElementById('bcastSound')?.checked ?? true;

    if (!title || !message) {
      this.showToast('Please provide both an announcement headline and a message body.', '⚠️', 'warning');
      return;
    }

    this.broadcast = {
      title,
      message,
      type,
      severity: type,
      targetTenant,
      targetPlan,
      targetRole: targetPlan,
      actionText,
      actionUrl,
      dismissible,
      active,
      playSound,
      updatedAt: new Date().toISOString(),
    };

    const saved = await this.apiMutate('/api/platform/broadcast', this.broadcast);
    if (!saved) return;
    this.saveData(STORAGE_KEYS.BROADCAST, this.broadcast);

    // Also drop it into each targeted user's in-app notification inbox.
    await this.apiMutate('/api/platform/notifications', {
      title, message, type: 'broadcast', severity: type, targetTenant, targetPlan, targetRole: 'all',
      actionUrl: actionUrl.startsWith('/') || actionUrl.startsWith('https://') ? actionUrl : '',
    }, { silent: true });
    this.scheduleRefresh(200);

    this.phoneMockupDismissed = false;
    this.updateBroadcastMockup();
    this.triggerPhonePushSimulation();

    const planLabel = targetPlan === 'all' ? 'All Plans' : `${targetPlan.toUpperCase()} Tier`;
    const audName = targetTenant === 'all' ? 'All Agencies (Global)' : (this.tenants?.find(t => (t.id || t.tenantId) === targetTenant)?.firmName || targetTenant);
    this.showToast(`📢 Broadcast published live to ${audName} • ${planLabel}!`, '✓');
  }

  // --- Push Notifications & Broadcast History ---
  filterNotifications(filter, btn) {
    this.notificationFilter = filter;
    document.querySelectorAll('.filter-btn-notif').forEach(b => b.classList.remove('active'));
    if (btn) btn.classList.add('active');
    this.renderNotificationsTable();
  }

  renderNotificationsTable() {
    const tbody = document.getElementById('notificationsTableBody');
    if (!tbody) return;

    let items = this.notifications || [];
    if (this.notificationFilter && this.notificationFilter !== 'all') {
      items = items.filter(n => {
        const cat = (n.category || n.type || '').toLowerCase();
        return cat.includes(this.notificationFilter);
      });
    }

    if (!items.length) {
      tbody.innerHTML = `
        <tr>
          <td colspan="6" style="text-align: center; padding: 32px; color: #94A3B8;">
            <div style="font-size: 24px; margin-bottom: 6px;">🔔</div>
            <div style="font-weight: 700; color: #475569;">No Push Notifications Logged Yet</div>
            <div style="font-size: 12px;">Dispatched broadcasts and mobile triggers will appear here in real-time.</div>
          </td>
        </tr>
      `;
      return;
    }

    tbody.innerHTML = items.map(n => {
      const type = (n.type || n.category || 'broadcast').toLowerCase();
      let badgeClass = 'badge-active';
      let icon = '📢';
      if (type.includes('order')) { badgeClass = 'badge-blue'; icon = '🛍️'; }
      else if (type.includes('payment')) { badgeClass = 'badge-success'; icon = '💳'; }
      else if (type.includes('inventory')) { badgeClass = 'badge-warning'; icon = '📦'; }

      const timeStr = n.timestamp ? new Date(n.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : 'Just now';
      const dateStr = n.timestamp ? new Date(n.timestamp).toLocaleDateString([], { month: 'short', day: 'numeric' }) : '';

      const targetTenantName = n.targetTenant === 'all' || !n.targetTenant 
        ? '🌐 All Agencies' 
        : `🏢 ${this.escapeHtml(this.tenants?.find(t => (t.id || t.tenantId) === n.targetTenant)?.firmName || n.targetTenant)}`;
      
      const planVal = (n.targetPlan || n.targetRole || 'all').toLowerCase();
      let planBadge = '🌐 All Plans';
      if (planVal === 'enterprise') planBadge = '💎 Enterprise';
      else if (planVal === 'grow') planBadge = '🚀 Grow';
      else if (planVal === 'startup') planBadge = '⚡ Startup';
      else if (planVal === 'expired' || planVal === 'freemium') planBadge = '⏳ Expired';
      else if (planVal === 'trial') planBadge = '🎁 Trial';
      else if (planVal !== 'all') planBadge = `🏷️ ${this.escapeHtml(planVal.toUpperCase())}`;

      const notifId = n.id || n.notification_id;

      return `
        <tr>
          <td>
            <div style="font-weight: 700; color: #0F172A; font-size: 12px;">${timeStr}</div>
            <div style="font-size: 11px; color: #64748B;">${dateStr}</div>
          </td>
          <td>
            <span class="badge ${badgeClass}" style="display: inline-flex; align-items: center; gap: 4px;">
              <span>${icon}</span>
              <span>${this.escapeHtml((n.category || n.type || 'Broadcast').toUpperCase())}</span>
            </span>
          </td>
          <td>
            <div style="font-weight: 800; color: #0F172A; font-size: 13px;">${this.escapeHtml(n.title || '')}</div>
            <div style="font-size: 12px; color: #475569; margin-top: 2px;">${this.escapeHtml(n.message || '')}</div>
          </td>
          <td>
            <div style="font-size: 12px; font-weight: 700; color: #1E293B;">${targetTenantName}</div>
            <div style="font-size: 11px; color: #64748B; margin-top: 2px;">${planBadge}</div>
          </td>
          <td>
            <span style="font-size: 11px; font-weight: 700; color: #059669; display: flex; align-items: center; gap: 4px;">
              <span style="width: 6px; height: 6px; border-radius: 50%; background: #10B981;"></span>
              ${n.isBroadcast ? 'All users (inbox)' : 'Agency inbox'}
            </span>
          </td>
          <td style="text-align: center;">
            <button class="btn btn-outline btn-sm" style="color: #EF4444; border-color: #FECACA; padding: 4px 8px; font-size: 11px;" onclick="adminApp.deleteNotification('${this.escapeJs(notifId)}')" title="Delete Notification">
              🗑️
            </button>
          </td>
        </tr>
      `;
    }).join('');
  }

  scrollToBroadcastComposer() {
    const el = document.getElementById('bcastTitle');
    if (el) {
      el.scrollIntoView({ behavior: 'smooth', block: 'center' });
      el.focus();
    }
  }

  async deleteNotification(id) {
    if (!id) return;
    const ok = await this.apiMutate(`/api/platform/notifications/${encodeURIComponent(id)}`, null, { method: 'DELETE' });
    if (!ok) return;
    await this.fetchPlatformState(true);
    this.showToast('Notification removed.', '🗑️');
  }

  async clearBroadcastBanner() {
    if (!this.broadcast) {
      this.broadcast = JSON.parse(JSON.stringify(DEFAULT_BROADCAST));
    }
    this.broadcast.active = false;
    this.broadcast.updatedAt = new Date().toISOString();

    const elActive = document.getElementById('bcastActive');
    if (elActive) elActive.checked = false;

    const ok = await this.apiMutate('/api/platform/broadcast', { active: false });
    if (!ok) return;
    this.saveData(STORAGE_KEYS.BROADCAST, this.broadcast);

    this.phoneMockupDismissed = false;
    this.updateBroadcastMockup();
    this.showToast('⏸️ Active mobile broadcast banner cleared & paused.', '✓');
  }

  // --- VIEW 6: App Sync & Data Bridge ---
  renderSyncPills() {
    const container = document.getElementById('syncCouponsListPills');
    if (!container) return;

    container.innerHTML = this.coupons.filter(c => c.isActive).map(c => `
      <div style="background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 10px 14px; display: flex; align-items: center; gap: 10px;">
        <span class="code-pill">${this.escapeHtml(c.code)}</span>
        <div style="font-size: 12px;">
          <strong>${this.escapeHtml(c.title)}</strong> (${c.type === 'trial' ? `+${Number(c.value)} Days` : (c.type === 'flat' ? `₹${Number(c.value)} OFF` : `${Number(c.value)}% OFF`)})
        </div>
        <button class="btn btn-sm btn-outline" style="margin-left: auto;" onclick="adminApp.copyText('${this.escapeJs(c.code)}')">
          Copy
        </button>
      </div>
    `).join('');
  }

  exportDatabaseJSON() {
    const bundle = {
      exportTimestamp: new Date().toISOString(),
      platform: 'SalesArmy Monorepo Sync Engine',
      coupons: this.coupons,
      tenants: this.tenants,
      printerOrders: this.printerOrders,
      printerOptions: this.printerOptions,
      plans: this.plans,
      settings: this.settings,
      remoteConfig: this.remoteConfig,
      featureFlags: this.remoteConfig?.featureFlags,
      maintenance: this.remoteConfig?.maintenance,
      emergencyBroadcast: this.broadcast,
      broadcast: this.broadcast,
      users: this.users,
      retailOrders: this.retailOrders,
    };

    const dataStr = 'data:text/json;charset=utf-8,' + encodeURIComponent(JSON.stringify(bundle, null, 2));
    const dlAnchor = document.createElement('a');
    dlAnchor.setAttribute('href', dataStr);
    dlAnchor.setAttribute('download', `salesarmy_sync_bundle_${Date.now()}.json`);
    document.body.appendChild(dlAnchor);
    dlAnchor.click();
    dlAnchor.remove();
    this.showToast('Database exported as salesarmy_sync_bundle.json!', '💾');
  }

  handleFileImport(event) {
    const file = event.target.files[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = async (e) => {
      let parsed;
      try { parsed = JSON.parse(e.target.result); } catch (_) {
        this.showToast('Invalid JSON file.', '❌', 'danger');
        return;
      }
      // Restores catalog & configuration only. Agencies, users and orders
      // live in the database and are never overwritten from a browser file.
      const payload = {};
      for (const key of ['plans', 'printerOptions', 'subscriptionAddons', 'coupons', 'remoteConfig', 'broadcast', 'settings']) {
        if (parsed[key] !== undefined) payload[key] = parsed[key];
      }
      if (!Object.keys(payload).length) {
        this.showToast('The file contains no catalog or configuration to restore.', '⚠️', 'warning');
        return;
      }
      if (!confirm(`Restore ${Object.keys(payload).join(', ')} from this file? Current values will be replaced.`)) return;
      const ok = await this.saveToBridge(payload);
      if (ok) {
        await this.fetchPlatformState(true);
        this.showToast(`Restored: ${Object.keys(payload).join(', ')}.`, '🎉');
      }
      event.target.value = '';
    };
    reader.readAsText(file);
  }

  // --- VIEW: Billing & Subscriptions ---
  async renderBilling() {
    this.loadPlansPurchased();
    const tenants = this.tenants || [];
    const activePaid = tenants.filter(t => (t.subscriptionStatus === 'active' || t.subscription_status === 'active') && (t.subscriptionPlanId || t.planName) && (t.subscriptionPlanId || t.planName).toLowerCase() !== 'free_starter').length;
    const now = Date.now();
    const renewingSoon = tenants.filter(t => {
      const d = t.expiryDate || t.subscription_end_date;
      if (!d) return false;
      const ts = new Date(d).getTime();
      return !Number.isNaN(ts) && ts > now && ts - now < 7 * 24 * 3600 * 1000;
    }).length;

    const setText = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
    setText('billActivePaid', activePaid);
    setText('billRenewingSoon', renewingSoon);
    setText('billPendingLinks', '0');
    setText('billFailed24h', '0');

    const pendingBody = document.getElementById('billPendingLinksBody');
    const renewalsBody = document.getElementById('billRenewalsBody');
    if (pendingBody) pendingBody.innerHTML = '<tr><td colspan="6" style="text-align:center; padding: 24px; color:var(--text-muted);">Syncing live payment links…</td></tr>';
    if (renewalsBody) renewalsBody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding: 24px; color:var(--text-muted);">Syncing subscription renewal timeline…</td></tr>';

    let pending = [];
    let renewals = [];
    let failed = [];

    try {
      const res = await fetch('/api/platform/subscriptions', { headers: this.getAuthHeaders() });
      if (res.ok) {
        const data = await res.json();
        pending = Array.isArray(data.pending) ? data.pending : [];
        renewals = Array.isArray(data.renewals) ? data.renewals : [];
        failed = Array.isArray(data.failed) ? data.failed : [];
      }
    } catch (_) {}


    setText('billPendingLinks', pending.length);
    const since24h = Date.now() - 24 * 3600 * 1000;
    const failed24 = failed.filter(f => {
      const t = new Date(f.created_at || f.updated_at || 0).getTime();
      return t >= since24h;
    }).length;
    setText('billFailed24h', failed24);

    // Nav badge
    const nb = document.getElementById('badgePendingPayments');
    if (nb) {
      if (pending.length > 0) {
        nb.textContent = pending.length;
        nb.style.display = '';
      } else {
        nb.style.display = 'none';
      }
    }

    // Render pending payment links
    if (pendingBody) {
      if (pending.length === 0) {
        pendingBody.innerHTML = `
          <tr>
            <td colspan="6" style="text-align:center; padding: 36px 16px; color:var(--text-muted);">
              <div style="font-size: 20px; margin-bottom: 6px;">✓</div>
              <div style="font-weight: 700; color: var(--text-main); font-size: 13.5px;">All Payment Links Settled</div>
              <div style="font-size: 12px; margin-top: 4px;">No outstanding or awaiting payment links in the checkout queue.</div>
            </td>
          </tr>
        `;
      } else {
        pendingBody.innerHTML = pending.map(p => {
          const q = p.quote || {};
          const paise = Number(p.amount ?? q.amount);
          const amt = Number.isFinite(paise) ? `₹${(paise / 100).toLocaleString('en-IN', { minimumFractionDigits: 2 })}` : '—';
          const created = p.created_at ? new Date(p.created_at).toLocaleString('en-IN') : '—';
          const planId = q.planId || q.plan_id || '—';
          return `
            <tr>
              <td><span class="code-pill">${this.escapeHtml(p.id || '')}</span></td>
              <td style="font-weight: 600;">${this.escapeHtml(p.tenant_id || '—')}</td>
              <td><span class="badge badge-indigo">${this.escapeHtml(planId)}</span></td>
              <td style="font-weight: 800; color: var(--emerald-text); font-variant-numeric: tabular-nums;">${this.escapeHtml(amt)}</td>
              <td style="font-size: 12px; color: var(--text-muted);">${this.escapeHtml(created)}</td>
              <td style="text-align: right;">
                <button class="btn btn-sm btn-primary" onclick="adminApp.manuallySettleCheckout('${this.escapeJs(p.id || '')}')">
                  Settle Manually…
                </button>
              </td>
            </tr>
          `;
        }).join('');
      }
    }

    // Render renewals
    if (renewalsBody) {
      if (renewals.length === 0) {
        renewalsBody.innerHTML = '<tr><td colspan="5" style="text-align:center; padding: 36px 16px; color:var(--text-muted);">No subscription records found.</td></tr>';
      } else {
        renewalsBody.innerHTML = renewals.slice(0, 50).map(r => {
          const end = r.subscription_end_date ? new Date(r.subscription_end_date) : null;
          let daysLeft = '—';
          let badgeClass = 'badge-delivered';
          if (end && !Number.isNaN(end.getTime())) {
            const diffDays = Math.ceil((end.getTime() - Date.now()) / (24 * 3600 * 1000));
            if (diffDays <= 0) {
              daysLeft = 'Expired';
              badgeClass = 'badge-cancelled';
            } else if (diffDays <= 7) {
              daysLeft = `${diffDays}d left`;
              badgeClass = 'badge-pending';
            } else {
              daysLeft = `${diffDays}d active`;
              badgeClass = 'badge-delivered';
            }
          }
          const tId = r.tenant_id || '';
          return `
            <tr>
              <td>
                <div style="font-weight: 700; color: var(--text-main); font-size: 13.5px;">${this.escapeHtml(r.business_name || tId)}</div>
                <div style="font-size: 11px; color: var(--text-muted); font-family: var(--font-mono); margin-top: 2px;">${this.escapeHtml(tId)}</div>
              </td>
              <td>
                <span class="badge badge-indigo">${this.escapeHtml(r.plan_id || 'Startup')}</span>
              </td>
              <td style="font-variant-numeric: tabular-nums; font-size: 12.5px;">
                ${this.escapeHtml(end ? end.toLocaleDateString('en-IN', { year: 'numeric', month: 'short', day: 'numeric' }) : 'Continuous')}
              </td>
              <td>
                <span class="badge ${badgeClass}">${this.escapeHtml(daysLeft)}</span>
              </td>
              <td style="text-align: right;">
                <div style="display: inline-flex; gap: 6px; align-items: center; justify-content: flex-end;">
                  <button class="btn btn-sm btn-outline" onclick="adminApp.grantTenantTrialDays('${this.escapeJs(tId)}', 7)" title="Extend +7 Days">
                    +7 Days
                  </button>
                  <button class="btn btn-sm btn-outline" onclick="adminApp.openTenantDrilldown('${this.escapeJs(tId)}')" title="Drill Down Snapshot" style="color: #3B82F6;">
                    🔍 Drill-Down
                  </button>
                </div>
              </td>
            </tr>
          `;
        }).join('');
      }
    }
  }

  refreshBilling() { this.renderBilling(); }

  // ---- Shared: paid subscriptions + hardware orders (from /revenue-summary) ----
  async fetchRevenueData() {
    const res = await fetch('/api/platform/revenue-summary', { headers: this.getAuthHeaders() });
    const j = await res.json();
    if (!j.success) throw new Error(j.error || 'Could not load revenue data');
    this.revenueData = j;
    return j;
  }

  planPeriodLabel(s) {
    if (s.trial) return 'Trial (coupon)';
    if (s.days === 30) return 'Monthly';
    if (s.days === 365) return 'Yearly';
    return s.days ? `${s.days} days` : '—';
  }

  agencyNameOf(tenantId) {
    const t = (this.tenants || []).find(x => (x.id || x.tenantId) === tenantId);
    return t ? (t.firmName || t.name) : tenantId;
  }

  // ---- Revenue Reports page (client spec §3) ----
  setRevenuePeriod(period) {
    this.revenuePeriod = period;
    document.querySelectorAll('.revenue-period-btn').forEach(b => b.classList.toggle('active', b.dataset.period === period));
    const custom = document.getElementById('revenueCustomRange');
    if (custom) custom.style.display = period === 'custom' ? 'flex' : 'none';
    this.renderRevenueReports();
  }

  // Returns { from, to, label } in local time; null bound = open-ended.
  revenueRange() {
    const p = this.revenuePeriod || 'this_month';
    const now = new Date();
    const fmt = d => d.toLocaleDateString('en-IN');
    if (p === 'this_month') { const from = new Date(now.getFullYear(), now.getMonth(), 1); return { from, to: null, label: `${fmt(from)} – today` }; }
    if (p === 'last_month') {
      const from = new Date(now.getFullYear(), now.getMonth() - 1, 1);
      const to = new Date(now.getFullYear(), now.getMonth(), 1);
      return { from, to, label: `${fmt(from)} – ${fmt(new Date(to - 1))}` };
    }
    if (p === 'this_year') { const from = new Date(now.getFullYear(), 0, 1); return { from, to: null, label: `${fmt(from)} – today` }; }
    if (p === 'custom') {
      const fv = document.getElementById('revenueFrom')?.value;
      const tv = document.getElementById('revenueTo')?.value;
      const from = fv ? new Date(`${fv}T00:00:00`) : null;
      const to = tv ? new Date(new Date(`${tv}T00:00:00`).getTime() + 86400000) : null;
      return { from, to, label: `${from ? fmt(from) : 'start'} – ${to ? fmt(new Date(to - 1)) : 'today'}` };
    }
    return { from: null, to: null, label: 'All time' };
  }

  async loadRevenueReports() {
    try {
      await this.fetchRevenueData();
    } catch (err) {
      console.warn('Revenue reports error:', err);
      this.showToast(err.message, '⚠️', 'warning');
    }
    this.renderRevenueReports();
  }

  revenueReportData() {
    const data = this.revenueData || { subscriptions: [], hardwareOrders: [] };
    const { from, to, label } = this.revenueRange();
    const inRange = v => { if (!v) return false; const d = new Date(v); return (!from || d >= from) && (!to || d < to); };
    const subs = (data.subscriptions || []).filter(s => inRange(s.paidAt));
    const hw = (data.hardwareOrders || []).filter(h => inRange(h.orderedAt));
    const hwPaid = hw.filter(h => h.paymentStatus === 'paid');
    const round2 = n => Math.round(n * 100) / 100;
    const planRevenue = round2(subs.reduce((s, x) => s + Number(x.amount || 0), 0));
    const hardwareRevenue = round2(hwPaid.reduce((s, x) => s + Number(x.amount || 0), 0));
    const cap = v => { const s = String(v || ''); return s ? s.charAt(0).toUpperCase() + s.slice(1) : '—'; };
    const rows = subs.map(s => ({
      at: s.paidAt, type: 'Subscription', agency: this.agencyNameOf(s.tenantId),
      item: `${s.planName || ''} (${this.planPeriodLabel(s)})`, amount: Number(s.amount || 0), payment: 'Paid', status: '—',
    })).concat(hw.map(h => ({
      at: h.orderedAt, type: 'Hardware', agency: h.agencyName || this.agencyNameOf(h.tenantId),
      item: `${h.item}${h.quantity > 1 ? ` x${h.quantity}` : ''}`, amount: Number(h.amount || 0), payment: cap(h.paymentStatus), status: cap(h.status),
    }))).sort((a, b) => new Date(b.at || 0) - new Date(a.at || 0));
    return {
      label, rows, planRevenue, hardwareRevenue, totalRevenue: round2(planRevenue + hardwareRevenue),
      hwOrders: hw.length, hwPaid: hwPaid.length, plansCount: subs.length,
      subscribers: new Set(subs.map(s => s.tenantId)).size,
    };
  }

  renderRevenueReports() {
    if (!this.revenuePeriod) this.revenuePeriod = 'this_month';
    const r = this.revenueReportData();
    const setText = (id, v) => { const el = document.getElementById(id); if (el) el.textContent = v; };
    setText('revenuePeriodLabel', r.label);
    setText('revTotal', this.formatRupees(r.totalRevenue));
    setText('revPlans', this.formatRupees(r.planRevenue));
    setText('revHardware', this.formatRupees(r.hardwareRevenue));
    setText('revHwOrders', r.hwOrders);
    setText('revHwPaid', r.hwPaid);
    setText('revSubscribers', r.subscribers);
    setText('revPlansCount', r.plansCount);
    const tbody = document.getElementById('revenueTableBody');
    if (!tbody) return;
    if (!r.rows.length) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 24px; color: var(--text-muted);">No subscriptions or hardware orders in this period</td></tr>';
      return;
    }
    tbody.innerHTML = r.rows.map(x => {
      const d = x.at ? new Date(x.at) : null;
      return `
        <tr>
          <td>${this.escapeHtml(d && !isNaN(d) ? d.toLocaleDateString('en-IN') : '—')}</td>
          <td>${this.escapeHtml(x.type)}</td>
          <td>${this.escapeHtml(x.agency)}</td>
          <td>${this.escapeHtml(x.item)}</td>
          <td><strong>${this.escapeHtml(this.formatRupees(x.amount))}</strong></td>
          <td>${this.escapeHtml(x.payment)}</td>
          <td>${this.escapeHtml(x.status)}</td>
        </tr>`;
    }).join('');
  }

  async downloadRevenueReport(format) {
    try {
      if (!this.revenueData) await this.fetchRevenueData();
      const r = this.revenueReportData();
      const day = v => { const d = v ? new Date(v) : null; return d && !isNaN(d) ? d.toLocaleDateString('en-IN') : ''; };
      const rows = r.rows.map(x => ({ date: day(x.at), type: x.type, agency: x.agency, item: x.item, amount: x.amount, payment: x.payment, status: x.status }));
      const blank = { date: '', type: '', agency: '', item: '', amount: '', payment: '', status: '' };
      rows.push(
        { ...blank },
        { ...blank, item: 'Subscriptions revenue', amount: r.planRevenue },
        { ...blank, item: 'Hardware / Printer / Paper Roll revenue', amount: r.hardwareRevenue },
        { ...blank, item: 'TOTAL REVENUE', amount: r.totalRevenue },
        { ...blank, item: `Hardware orders: ${r.hwOrders} (paid ${r.hwPaid})` },
        { ...blank, item: `Paid subscribers: ${r.subscribers} (plans purchased ${r.plansCount})` },
      );
      const report = {
        agency: 'SalesArmy', title: `Revenue Report (${r.label})`,
        columns: [['date', 'Date'], ['type', 'Type'], ['agency', 'Agency'], ['item', 'Item'], ['amount', 'Amount'], ['payment', 'Payment'], ['status', 'Status']].map(([key, label]) => ({ key, label })),
        rows,
      };
      const fileBase = `SalesArmy_Revenue_Report_${(this.revenuePeriod || 'this_month')}_${new Date().toISOString().slice(0, 10)}`;
      if (format === 'excel') await this.writeReportExcel(report, fileBase);
      else await this.writeReportPdf(report, fileBase);
      this.showToast('Revenue report downloaded.', '✓');
    } catch (err) {
      console.warn('Revenue report download error:', err);
      this.showToast(`Download failed: ${err.message}`, '⚠️', 'warning');
    }
  }

  // ---- Subscriptions page: Plans Purchased (client spec §3) ----
  async loadPlansPurchased() {
    const tbody = document.getElementById('billPlansPurchasedBody');
    try {
      const data = await this.fetchRevenueData();
      this.renderPlansPurchased(data.subscriptions || []);
    } catch (err) {
      console.warn('Plans purchased error:', err);
      if (tbody) tbody.innerHTML = `<tr><td colspan="7" style="text-align:center; padding: 20px; color: var(--text-muted);">${this.escapeHtml(err.message)}</td></tr>`;
    }
  }

  plansPurchasedRows(subs) {
    const day = v => { const d = v ? new Date(v) : null; return d && !isNaN(d) ? d.toLocaleDateString('en-IN') : '—'; };
    return subs.map(s => ({
      paidDate: day(s.paidAt), agency: this.agencyNameOf(s.tenantId), plan: s.planName || '', period: this.planPeriodLabel(s),
      amount: Number(s.amount || 0), validTill: day(s.validTill), ref: s.id,
    }));
  }

  renderPlansPurchased(subs) {
    const tbody = document.getElementById('billPlansPurchasedBody');
    if (!tbody) return;
    const rows = this.plansPurchasedRows(subs);
    if (!rows.length) {
      tbody.innerHTML = '<tr><td colspan="7" style="text-align:center; padding: 20px; color: var(--text-muted);">No plans purchased yet</td></tr>';
      return;
    }
    tbody.innerHTML = rows.map(r => `
      <tr>
        <td>${this.escapeHtml(r.paidDate)}</td>
        <td>${this.escapeHtml(r.agency)}</td>
        <td>${this.escapeHtml(r.plan)}</td>
        <td>${this.escapeHtml(r.period)}</td>
        <td><strong>${this.escapeHtml(this.formatRupees(r.amount))}</strong></td>
        <td>${this.escapeHtml(r.validTill)}</td>
        <td style="font-family: var(--font-mono, monospace); font-size: 11px;">${this.escapeHtml(r.ref)}</td>
      </tr>`).join('');
  }

  async downloadPlansPurchased(format) {
    try {
      const data = await this.fetchRevenueData();
      const rows = this.plansPurchasedRows(data.subscriptions || []);
      if (!rows.length) { this.showToast('No plans purchased yet.', 'ℹ️'); return; }
      const report = {
        agency: 'SalesArmy', title: 'Plans Purchased',
        columns: [['paidDate', 'Paid Date'], ['agency', 'Agency'], ['plan', 'Plan'], ['period', 'Period'], ['amount', 'Amount'], ['validTill', 'Valid Till'], ['ref', 'Reference']].map(([key, label]) => ({ key, label })),
        rows,
      };
      const fileBase = `SalesArmy_Plans_Purchased_${new Date().toISOString().slice(0, 10)}`;
      if (format === 'excel') await this.writeReportExcel(report, fileBase);
      else await this.writeReportPdf(report, fileBase);
      this.showToast(`Plans Purchased downloaded (${rows.length} rows).`, '✓');
    } catch (err) {
      console.warn('Plans purchased download error:', err);
      this.showToast(`Download failed: ${err.message}`, '⚠️', 'warning');
    }
  }

  async manuallySettleCheckout(checkoutId) {
    const paymentReference = prompt('Bank UTR / UPI transaction ID of the payment you received (required):');
    if (!paymentReference || !paymentReference.trim()) return;
    const paymentMode = (prompt('Payment mode: upi / bank / cash / cheque', 'upi') || 'manual').trim().toLowerCase();
    if (!confirm(`Activate this subscription against payment reference "${paymentReference.trim()}"? Only confirm after you have verified the money was received.`)) return;
    const ok = await this.apiMutate('/api/platform/subscriptions/settle', { checkoutId, paymentReference: paymentReference.trim(), paymentMode });
    if (ok) {
      this.showToast('Payment recorded and subscription activated.', '✓');
      await this.fetchPlatformState(true);
      this.renderBilling();
    }
  }

  // --- VIEW: Tenant Drill-Down ---
  renderTenantDrilldown() {
    const sel = document.getElementById('drilldownTenantSelect');
    if (!sel) return;

    const tenants = this.tenants || [];
    const currentVal = sel.value;

    sel.innerHTML = '<option value="">— Choose an Agency —</option>' +
      tenants.map(t => {
        const name = t.firmName || t.name || t.id;
        const uid = t.userId || t.id;
        return `<option value="${this.escapeHtml(t.id || t.tenantId)}">${this.escapeHtml(name)} (${this.escapeHtml(uid)})</option>`;
      }).join('');

    if (this.activeDrilldownTenantId && tenants.some(t => (t.id || t.tenantId) === this.activeDrilldownTenantId)) {
      sel.value = this.activeDrilldownTenantId;
      this.loadTenantDrilldown(this.activeDrilldownTenantId);
    } else if (currentVal && tenants.some(t => (t.id || t.tenantId) === currentVal)) {
      sel.value = currentVal;
      this.loadTenantDrilldown(currentVal);
    } else if (tenants.length > 0) {
      const firstId = tenants[0].id || tenants[0].tenantId;
      sel.value = firstId;
      this.activeDrilldownTenantId = firstId;
      this.loadTenantDrilldown(firstId);
    } else {
      const body = document.getElementById('drilldownBody');
      if (body) {
        body.innerHTML = `
          <div style="text-align: center; padding: 48px 24px; color: var(--text-muted);">
            <p>No registered tenants found on this platform.</p>
          </div>
        `;
      }
    }
  }

  refreshActiveDrilldown() {
    const sel = document.getElementById('drilldownTenantSelect');
    if (sel && sel.value) {
      this.loadTenantDrilldown(sel.value);
    } else {
      this.renderTenantDrilldown();
    }
  }

  openTenantDrilldown(tenantId) {
    this.activeDrilldownTenantId = tenantId;
    this.switchView('tenant-drilldown');
    const sel = document.getElementById('drilldownTenantSelect');
    if (sel) {
      sel.value = tenantId;
      this.loadTenantDrilldown(tenantId);
    }
  }

  async loadTenantDrilldown(tenantId) {
    const body = document.getElementById('drilldownBody');
    if (!body) return;
    if (!tenantId) {
      body.innerHTML = `
        <div style="text-align: center; padding: 48px 24px; color: var(--text-muted);">
          <h3 style="font-size: 16px; font-weight: 700; color: var(--text-main); margin-bottom: 6px;">Select an Agency to Inspect</h3>
          <p style="font-size: 13px; max-width: 480px; margin: 0 auto;">Choose any registered tenant from the dropdown above to load their deep profile, store network, inventory catalog, field orders, and financial ledger.</p>
        </div>
      `;
      return;
    }

    this.activeDrilldownTenantId = tenantId;
    const localTenant = (this.tenants || []).find(x => x.id === tenantId || x.userId === tenantId || x.tenantId === tenantId) || {};

    body.innerHTML = `
      <div style="text-align: center; padding: 36px 20px; color: var(--text-muted);">
        <div style="display: inline-block; width: 28px; height: 28px; border: 3px solid rgba(59,130,246,0.2); border-top-color: #3B82F6; border-radius: 50%; animation: spin-sync 0.8s linear infinite; margin-bottom: 12px;"></div>
        <div style="font-weight: 600; font-size: 13.5px; color: var(--text-main);">Retrieving Agency Snapshot…</div>
        <div style="font-size: 12px; margin-top: 4px;">Loading outlets, catalog SKUs, orders, and ledger for ${this.escapeHtml(localTenant.firmName || tenantId)}</div>
      </div>
    `;

    let data = {
      tenant: localTenant,
      shops: [],
      products: [],
      orders: [],
      invoices: [],
      payments: [],
      ledger: []
    };

    try {
      const res = await fetch(`/api/platform/tenant/${encodeURIComponent(tenantId)}/overview`, {
        headers: this.getAuthHeaders(),
      });
      if (res.ok) {
        const json = await res.json();
        if (json.success) {
          data = json;
          if (!data.tenant || !data.tenant.business_name) {
            data.tenant = { ...localTenant, ...data.tenant };
          }
        }
      }
    } catch (_) {}

    // Fallbacks from local state if tables are empty
    const t = data.tenant || localTenant || {};
    const shops = Array.isArray(data.shops) && data.shops.length > 0 ? data.shops : [];
    const products = Array.isArray(data.products) && data.products.length > 0 ? data.products : [];
    const orders = Array.isArray(data.orders) && data.orders.length > 0
      ? data.orders
      : (this.retailOrders || []).filter(o => o.tenantId === tenantId || o.tenant_id === tenantId);
    const users = Array.isArray(data.staff)
      ? data.staff.map(u => ({ ...u, tenantId, status: u.is_active === false ? 'suspended' : (u.account_status || 'active') }))
      : (this.users || []).filter(u => u.tenantId === tenantId || u.tenant_id === tenantId);

    const firmName = t.business_name || t.firmName || t.name || tenantId;
    const isSuspended = t.subscription_status === 'suspended' || t.subscriptionStatus === 'suspended' || t.isSuspended === true;
    const badge = this._getTenantStatusBadge(t.subscription_status || t.subscriptionStatus, isSuspended);
    const gradient = this._getTenantAvatarGradient(t.plan_id || t.planName, t.subscription_status || t.subscriptionStatus);
    const initials = firmName.substring(0, 2).toUpperCase();
    const phoneClean = String(t.mobile || t.phone || '').replace(/[^0-9]/g, '');

    const totalGMV = orders.reduce((sum, o) => sum + (Number(o.grand_total || o.grandTotal || o.totalAmount) || 0), 0);

    body.innerHTML = `
      <!-- Agency Hero Banner -->
      <div class="drilldown-hero-card">
        <div class="drilldown-hero-left">
          <div class="drilldown-avatar" style="background: ${gradient};">${this.escapeHtml(initials)}</div>
          <div>
            <div style="display: flex; align-items: center; gap: 8px; flex-wrap: wrap;">
              <h2 class="drilldown-firm-title">${this.escapeHtml(firmName)}</h2>
              <span class="badge ${badge.class}">${badge.label}</span>
              <span class="badge badge-indigo">${this.escapeHtml(t.plan_id || t.planName || 'Startup Plan')}</span>
            </div>
            <div class="drilldown-meta-row">
              <span>👤 Proprietor: <strong>${this.escapeHtml(t.contact_person || t.ownerName || 'Proprietor')}</strong></span>
              <span>•</span>
              <span>📍 Location: <strong>${this.escapeHtml(t.city || 'India')}</strong>${t.state ? ', ' + this.escapeHtml(t.state) : ''}</span>
              <span>•</span>
              <span>📑 GSTIN: <strong style="font-family: var(--font-mono);">${this.escapeHtml(t.gstin || 'Unregistered')}</strong></span>
              ${phoneClean ? `
                <span>•</span>
                <a href="https://wa.me/91${phoneClean}" target="_blank" style="color: #059669; font-weight: 600; text-decoration: none;">💬 +91 ${this.escapeHtml(phoneClean)}</a>
              ` : ''}
            </div>
          </div>
        </div>
        <div style="display: flex; gap: 8px; align-items: center; flex-wrap: wrap;">
          <span class="code-pill">${this.escapeHtml(t.tenant_id || t.id || tenantId)}</span>
          <button class="btn btn-sm btn-outline" onclick="adminApp.grantTenantTrialDays('${this.escapeJs(t.tenant_id || t.id || tenantId)}', 7)" title="Grant +7 Days Extension">
            +7d Extension
          </button>
          <button class="btn btn-sm btn-outline" onclick="adminApp.openTenantDetailModal('${this.escapeJs(t.tenant_id || t.id || tenantId)}')" title="Inspect Deep Modal">
            Inspect Modal
          </button>
        </div>
      </div>

      <!-- Snapshot Metrics -->
      <div class="stats-grid" style="margin-bottom: 24px;">
        <div class="stat-card">
          <div class="stat-card-header">
            <span class="stat-label">Retail Outlets / Shops</span>
            <span class="stat-card-icon">🏬</span>
          </div>
          <div class="stat-value">${shops.length}</div>
          <div class="stat-footer"><span class="badge badge-delivered" style="font-size: 10.5px;">Beat Coverage</span></div>
        </div>

        <div class="stat-card">
          <div class="stat-card-header">
            <span class="stat-label">Product Catalog SKUs</span>
            <span class="stat-card-icon">📦</span>
          </div>
          <div class="stat-value">${products.length}</div>
          <div class="stat-footer"><span class="badge badge-indigo" style="font-size: 10.5px;">Active Items</span></div>
        </div>

        <div class="stat-card">
          <div class="stat-card-header">
            <span class="stat-label">Orders Logged &amp; GMV</span>
            <span class="stat-card-icon">📈</span>
          </div>
          <div class="stat-value">${orders.length} <span style="font-size: 13px; font-weight: 500; color: var(--text-muted);">(₹${totalGMV.toLocaleString('en-IN')})</span></div>
          <div class="stat-footer"><span class="badge badge-delivered" style="font-size: 10.5px;">Gross Volume</span></div>
        </div>

        <div class="stat-card">
          <div class="stat-card-header">
            <span class="stat-label">Workforce &amp; Staff Logins</span>
            <span class="stat-card-icon">👥</span>
          </div>
          <div class="stat-value">${users.length}</div>
          <div class="stat-footer"><span class="badge badge-delivered" style="font-size: 10.5px;">Field Reps &amp; Admins</span></div>
        </div>
      </div>

      <!-- Section: Retail Network Outlets -->
      <div class="drilldown-section">
        <div class="drilldown-section-header">
          <h4 class="drilldown-section-title">
            <span>🏬 Registered Outlets &amp; Retail Shops</span>
            <span class="badge badge-delivered" style="font-size: 10px;">${shops.length} Outlets</span>
          </h4>
        </div>
        <div class="table-responsive">
          <table>
            <thead>
              <tr>
                <th>Outlet / Store Name</th>
                <th>Proprietor</th>
                <th>City / Territory</th>
                <th>Contact</th>
                <th style="text-align: right;">Outstanding ₹</th>
              </tr>
            </thead>
            <tbody>
              ${shops.length === 0 ? `
                <tr><td colspan="5" style="text-align:center; padding: 24px; color:var(--text-muted);">No retail store outlets mapped under this agency yet.</td></tr>
              ` : shops.map(s => `
                <tr>
                  <td style="font-weight: 700;">${this.escapeHtml(s.shop_name || s.name || 'Store')}</td>
                  <td>${this.escapeHtml(s.owner_name || 'Proprietor')}</td>
                  <td>${this.escapeHtml(s.city || '—')}</td>
                  <td>${s.phone ? `<a href="tel:${this.escapeHtml(s.phone)}" style="color:var(--text-main); text-decoration:none;">📞 ${this.escapeHtml(s.phone)}</a>` : '—'}</td>
                  <td style="text-align: right; font-weight: 700; color: ${Number(s.current_outstanding) > 0 ? 'var(--rose-text)' : 'var(--text-main)'};">
                    ₹${(Number(s.current_outstanding) || 0).toLocaleString('en-IN')}
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>

      <!-- Section: Field Orders & Invoices -->
      <div class="drilldown-section">
        <div class="drilldown-section-header">
          <h4 class="drilldown-section-title">
            <span>📋 Field Orders &amp; Billing Velocity</span>
            <span class="badge badge-indigo" style="font-size: 10px;">${orders.length} Orders</span>
          </h4>
        </div>
        <div class="table-responsive">
          <table>
            <thead>
              <tr>
                <th>Order Reference</th>
                <th>Target Outlet</th>
                <th>Grand Total ₹</th>
                <th>Delivery Status</th>
                <th style="text-align: right;">Booking Timestamp</th>
              </tr>
            </thead>
            <tbody>
              ${orders.length === 0 ? `
                <tr><td colspan="5" style="text-align:center; padding: 24px; color:var(--text-muted);">No orders recorded for this agency.</td></tr>
              ` : orders.slice(0, 20).map(o => {
                const oid = o.orderNumber || o.order_id || o.orderId || o.id || '';
                const st = (o.status || 'delivered').toLowerCase();
                const stClass = st === 'delivered' ? 'badge-delivered' : (st === 'cancelled' ? 'badge-cancelled' : 'badge-pending');
                const amt = Number(o.grand_total || o.grandTotal || o.totalAmount) || 0;
                const date = o.orderDate || o.order_date || o.createdAt;
                return `
                  <tr>
                    <td><span class="code-pill">${this.escapeHtml(oid)}</span></td>
                    <td style="font-weight: 600;">${this.escapeHtml(o.shopName || o.shop_id || 'Retail Outlet')}</td>
                    <td style="font-weight: 800; font-variant-numeric: tabular-nums;">₹${amt.toLocaleString('en-IN')}</td>
                    <td><span class="badge ${stClass}">${this.escapeHtml(st.toUpperCase())}</span></td>
                    <td style="text-align: right; font-size: 12px; color: var(--text-muted);">
                      ${date ? new Date(date).toLocaleString('en-IN') : '—'}
                    </td>
                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      </div>

      <!-- Section: Workforce & Staff Team -->
      <div class="drilldown-section">
        <div class="drilldown-section-header">
          <h4 class="drilldown-section-title">
            <span>👥 Workforce Logins &amp; Staff Hierarchy</span>
            <span class="badge badge-delivered" style="font-size: 10px;">${users.length} Users</span>
          </h4>
        </div>
        <div class="table-responsive">
          <table>
            <thead>
              <tr>
                <th>Staff Name</th>
                <th>Email Address</th>
                <th>Mobile Number</th>
                <th>Platform Role</th>
                <th style="text-align: right;">Status</th>
              </tr>
            </thead>
            <tbody>
              ${users.length === 0 ? `
                <tr><td colspan="5" style="text-align:center; padding: 24px; color:var(--text-muted);">No staff members registered for this agency.</td></tr>
              ` : users.map(u => {
                const r = (u.role || 'sales_person').replace('_', ' ').toUpperCase();
                return `
                  <tr>
                    <td style="font-weight: 700;">${this.escapeHtml(u.name || 'User')}</td>
                    <td style="font-family: var(--font-mono); font-size: 12px;">${this.escapeHtml(u.email || '—')}</td>
                    <td>${this.escapeHtml(u.phone || '—')}</td>
                    <td><span class="badge badge-indigo">${this.escapeHtml(r)}</span></td>
                    <td style="text-align: right;"><span class="badge ${u.status === 'active' ? 'badge-delivered' : 'badge-cancelled'}">${this.escapeHtml((u.status || 'active').toUpperCase())}</span></td>
                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }
  
  // --- VIEW 7: Platform Settings ---
  renderPlatformSettings() {
    if (!this.settings) {
      this.settings = { ...DEFAULT_SETTINGS };
    }
    const planSelect = document.getElementById('settingDefaultPlanId');
    const liveTiers = (this.plans?.tiers || []).filter(t => t.isActive !== false);
    if (planSelect && liveTiers.length) {
      const lim = v => (Number(v) > 0 ? Number(v).toLocaleString('en-IN') : 'Unlimited');
      planSelect.innerHTML = liveTiers.map(t => `<option value="${this.escapeHtml(t.id)}">${this.escapeHtml(t.name)} — ${lim(t.maxStaff ?? t.maxUsers)} staff · ${lim(t.maxShops)} parties · ${lim(t.maxProducts)} products</option>`).join('');
    }
    const chkMaint = document.getElementById('chkMaintenanceMode');
    if (chkMaint) chkMaint.checked = this.settings.maintenanceMode === true || this.remoteConfig?.maintenance?.active === true;
    
    const elPass = document.getElementById('settingPasscode');
    if (elPass) { elPass.value = ''; elPass.placeholder = 'New account password'; }

    const elPhone = document.getElementById('settingSupportPhone');
    if (elPhone) elPhone.value = this.settings.supportPhone || '';

    const elEmail = document.getElementById('settingSupportEmail');
    if (elEmail) elEmail.value = this.settings.supportEmail || '';

    const elCompany = document.getElementById('settingCompanyName');
    if (elCompany) elCompany.value = this.settings.companyName || '';

    const elGstin = document.getElementById('settingGstin');
    if (elGstin) elGstin.value = this.settings.gstin || '';

    const elUpi = document.getElementById('settingUpiVpa');
    if (elUpi) elUpi.value = this.settings.upiVpa || '';

    const elDefPlan = document.getElementById('settingDefaultPlanId');
    if (elDefPlan) elDefPlan.value = this.settings.defaultPlanId || 'startup';

    const elTrialDays = document.getElementById('settingDefaultTrialDays');
    if (elTrialDays) elTrialDays.value = this.settings.defaultTrialDays !== undefined ? this.settings.defaultTrialDays : 14;

    const elGraceDays = document.getElementById('settingTrialGracePeriodDays');
    if (elGraceDays) elGraceDays.value = this.settings.trialGracePeriodDays !== undefined ? this.settings.trialGracePeriodDays : 3;

    const elTestAct = document.getElementById('settingAllowTestPlanActivation');
    if (elTestAct) elTestAct.checked = this.settings.allowTestPlanActivation === true;
  }

  async savePlatformSettings() {
    const supportPhone = document.getElementById('settingSupportPhone')?.value.trim() || '';
    const supportEmail = document.getElementById('settingSupportEmail')?.value.trim() || '';
    const companyName = document.getElementById('settingCompanyName')?.value.trim() || '';
    const gstin = document.getElementById('settingGstin')?.value.trim() || '';
    const upiVpa = document.getElementById('settingUpiVpa')?.value.trim() || '';
    const defaultPlanId = document.getElementById('settingDefaultPlanId')?.value || 'startup';
    const defaultTrialDays = parseInt(document.getElementById('settingDefaultTrialDays')?.value || '14', 10);
    const trialGracePeriodDays = parseInt(document.getElementById('settingTrialGracePeriodDays')?.value || '3', 10);
    const allowTestPlanActivation = document.getElementById('settingAllowTestPlanActivation')?.checked === true;

    this.settings = {
      ...this.settings,
      supportPhone,
      supportEmail,
      companyName,
      gstin,
      upiVpa,
      defaultPlanId,
      defaultTrialDays,
      trialGracePeriodDays,
      allowTestPlanActivation,
      updatedAt: new Date().toISOString()
    };

    delete this.settings.passcode;
    try {
      await fetch('/api/platform/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(this.settings)
      });
      this.saveData(STORAGE_KEYS.SETTINGS, this.settings);
      this.showToast('Platform settings saved & synchronized with mobile apps!', '⚙️');
    } catch (error) {
      this.showToast(error.message, '❌', 'danger');
    }
  }

  toggleMaintenanceMode(enabled) {
    this.settings.maintenanceMode = enabled;
    if (this.remoteConfig) {
      if (!this.remoteConfig.maintenance) this.remoteConfig.maintenance = { active: false, message: '', eta: '' };
      this.remoteConfig.maintenance.active = enabled;
      this.saveData(STORAGE_KEYS.REMOTE_CONFIG, this.remoteConfig); this.saveToBridge({ remoteConfig: this.remoteConfig });
    }
    this.saveData(STORAGE_KEYS.SETTINGS, this.settings);
    this.broadcastChange('maintenance_mode_update', { active: enabled });
    this.showToast(`Maintenance mode is now ${enabled ? 'ACTIVE' : 'OFF'}.`, enabled ? '⚠️' : '✓');
    this.renderRemoteAppControl();
    this.renderPlatformSettings();
  }

  async updatePasscode() {
    const val = document.getElementById('settingPasscode').value.trim();
    if (val.length < 8) {
      this.showToast('Password must be at least 8 characters.', '⚠️', 'warning');
      return;
    }
    try {
      const session = this.loadData(STORAGE_KEYS.AUTH, null);
      if (!session?.id) throw new Error('Sign in before changing your password.');
      await fetch('/api/platform/user/reset-password', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId: session.id, newPassword: val }),
      });
      document.getElementById('settingPasscode').value = '';
      this.showToast('Your administrator account password was updated.', '🔑');
    } catch (error) { this.showToast(error.message, '❌', 'danger'); }
  }

  async resetAllDataToFactoryDefaults() {
    // Only the sellable catalog and app configuration are reset. Agencies,
    // users and orders are never touched from here.
    const typed = prompt('Reset plans, printers, add-ons, coupons, remote config and broadcast to factory defaults? Type RESET to confirm.');
    if (typed !== 'RESET') return;
    const ok = await this.saveToBridge({
      plans: JSON.parse(JSON.stringify(DEFAULT_PLANS)),
      printerOptions: JSON.parse(JSON.stringify(DEFAULT_PRINTER_OPTIONS)),
      subscriptionAddons: JSON.parse(JSON.stringify(DEFAULT_ADDONS)),
      coupons: [],
      remoteConfig: JSON.parse(JSON.stringify(DEFAULT_REMOTE_CONFIG)),
      broadcast: { ...DEFAULT_BROADCAST, active: false },
    });
    if (ok) {
      await this.fetchPlatformState(true);
      this.showToast('Catalog and configuration reset to defaults.', '🔄');
    }
  }

  // --- Dashboard Overview Helpers ---
  renderRecentOrdersTable() {
    const tbody = document.getElementById('recentOrdersTableBody');
    if (!tbody) return;

    tbody.innerHTML = this.printerOrders.slice(0, 4).map(o => {
      const isDelivered = (o.status || '').toLowerCase() === 'delivered';
      const isShipped = (o.status || '').toLowerCase() === 'shipped' || (o.status || '').toLowerCase() === 'dispatched';
      const statusBadge = isDelivered ? 'badge-delivered' : (isShipped ? 'badge-active' : 'badge-pending');
      const initials = (o.customerName || 'SO').split(' ').map(w => w[0]).join('').substring(0, 2).toUpperCase();

      return `
      <tr>
        <td>
          <span class="code-pill">${this.escapeHtml(o.id)}</span>
          <div style="font-size: 11px; color: var(--text-muted); margin-top: 3px;">UID: <code>${this.escapeHtml(o.userId || 'platform_tenant')}</code></div>
        </td>
        <td>
          <div style="display: flex; align-items: center; gap: 8px;">
            <div style="width: 28px; height: 28px; border-radius: var(--radius-xs); background: linear-gradient(135deg, #4F46E5, #3B82F6); color: white; display: flex; align-items: center; justify-content: center; font-size: 11px; font-weight: 800; flex-shrink: 0;">${this.escapeHtml(initials)}</div>
            <div>
              <strong style="font-size: 13px; color: var(--text-main);">${this.escapeHtml(o.customerName || 'Store Manager')}</strong>
              <div style="font-size: 11px; color: var(--text-muted);">${this.escapeHtml(o.agencyName || 'Distributor Agency')}</div>
            </div>
          </div>
        </td>
        <td>
          <div style="font-size: 12.5px; font-weight: 700; color: var(--text-main);">${this.escapeHtml(o.printerItem || 'Thermal POS Printer')}</div>
          <div style="font-size: 11px; color: var(--text-muted);">₹${Number(o.price || 2499).toLocaleString('en-IN')}</div>
        </td>
        <td>
          <span class="badge ${statusBadge}">
            <span style="width: 5px; height: 5px; border-radius: 50%; background: currentColor;"></span>
            ${this.escapeHtml(o.status || 'Pending')}
          </span>
        </td>
        <td>
          <code>${this.escapeHtml(o.trackingNumber || 'Unassigned')}</code>
        </td>
        <td>
          <button class="btn btn-sm btn-outline" onclick="adminApp.openShippingLabel('${this.escapeJs(o.id)}')">
            Label
          </button>
        </td>
      </tr>
      `;
    }).join('');
  }

  copyText(text) {
    if (navigator.clipboard) {
      navigator.clipboard.writeText(text);
      this.showToast(`Copied "${text}" to clipboard!`, '📋');
    } else {
      prompt('Copy to clipboard: Ctrl+C, Enter', text);
    }
  }

  // ==============================================
  // VIEW: RAZORPAY PAYMENT GATEWAY SETTINGS
  // ==============================================
  async renderGatewaySettings() {
    const hookEl = document.getElementById('gatewayWebhookDisplayUrl');
    if (hookEl) hookEl.value = `${window.location.origin}/api/checkout/webhook`;
    try {
      const res = await fetch('/api/platform/gateway/config', { headers: this.getAuthHeaders() });
      const data = await res.json();
      if (!data.success || !data.config) return;
      const cfg = data.config;
      this.gatewayConfig = cfg;
      const isLive = cfg.mode === 'live';
      const show = (id, on) => { const el = document.getElementById(id); if (el) el.style.display = on ? 'inline-block' : 'none'; };
      const setVal = (id, v) => { const el = document.getElementById(id); if (el) el.value = v || ''; };

      const modeToggle = document.getElementById('gatewayModeToggle');
      if (modeToggle) modeToggle.checked = isLive;
      const modeLabel = document.getElementById('gatewayModeLabel');
      if (modeLabel) {
        modeLabel.textContent = cfg.keyId ? (isLive ? 'Production (Live)' : 'Sandbox (Test)') : 'Not configured';
        modeLabel.style.color = isLive ? '#10B981' : '#D97706';
      }
      const badge = document.getElementById('gatewayStatusBadge');
      if (badge) {
        badge.className = cfg.keyId ? (isLive ? 'badge badge-delivered' : 'badge badge-active') : 'badge badge-expired';
        badge.textContent = cfg.keyId ? `● Razorpay ${isLive ? 'Live' : 'Sandbox'}` : '● Razorpay not configured';
      }
      setVal('gatewayKeyId', cfg.keyId);
      setVal('gatewayKeySecret', '');
      setVal('gatewayWebhookSecret', '');
      setVal('gatewayMerchantName', cfg.merchantName);
      setVal('gatewayUpiVpa', cfg.upiVpa);
      const secretPh = document.getElementById('gatewayKeySecret');
      if (secretPh) secretPh.placeholder = cfg.hasSecret ? `Saved ${cfg.secretHint || ''} — leave empty to keep it` : 'Paste the Key Secret';
      const hookPh = document.getElementById('gatewayWebhookSecret');
      if (hookPh) hookPh.placeholder = cfg.hasWebhookSecret ? `Saved ${cfg.webhookSecretHint || ''} — leave empty to keep it` : 'Optional';
      show('gatewaySecretConfiguredBadge', cfg.hasSecret); show('gatewaySecretMissingBadge', !cfg.hasSecret);
      show('gatewayWebhookConfiguredBadge', cfg.hasWebhookSecret); show('gatewayWebhookMissingBadge', !cfg.hasWebhookSecret);
      const src = document.getElementById('gatewayKeysSourceBadge');
      if (src) {
        src.style.display = cfg.managedBy && cfg.managedBy !== 'none' ? 'inline-block' : 'none';
        src.textContent = cfg.managedBy === 'admin'
          ? `Keys saved in admin panel${cfg.keysUpdatedAt ? ` • ${new Date(cfg.keysUpdatedAt).toLocaleDateString('en-IN')}` : ''}`
          : 'Using server environment keys';
      }
      show('btnClearGatewayKeys', cfg.managedBy === 'admin');
      const autoCap = document.getElementById('gatewayAutoCapture');
      if (autoCap) autoCap.checked = cfg.autoCapture !== false;

      const diagStatus = document.getElementById('gatewayDiagnosticStatus');
      const diagMsg = document.getElementById('gatewayDiagnosticMessage');
      if (diagStatus) {
        diagStatus.className = cfg.testStatus === 'connected' ? 'badge badge-success' : (cfg.testStatus === 'failed' ? 'badge badge-expired' : 'badge badge-trial');
        diagStatus.textContent = cfg.testStatus === 'connected' ? 'API Connected' : (cfg.testStatus === 'failed' ? 'Last test failed' : 'Not verified');
      }
      if (diagMsg) diagMsg.textContent = cfg.lastTested ? `Last tested ${new Date(cfg.lastTested).toLocaleString('en-IN')}` : 'Run a connection test to verify the server keys.';
    } catch (_) {}
  }

  toggleGatewayMode() {
    this.showToast('Mode follows the configured Razorpay key (rzp_test_ / rzp_live_). Change the server secret to switch.', 'ℹ️');
    this.renderGatewaySettings();
  }

  togglePasswordVisibility(fieldId, btn) {
    const input = document.getElementById(fieldId);
    if (!input) return;
    input.type = input.type === 'password' ? 'text' : 'password';
    if (btn) btn.textContent = input.type === 'password' ? '👁️' : '🙈';
  }

  async saveGatewaySettings() {
    const keyId = document.getElementById('gatewayKeyId')?.value.trim() || '';
    const keySecret = document.getElementById('gatewayKeySecret')?.value.trim() || '';
    const webhookSecret = document.getElementById('gatewayWebhookSecret')?.value.trim() || '';
    const payload = {
      autoCapture: document.getElementById('gatewayAutoCapture')?.checked !== false,
      merchantName: document.getElementById('gatewayMerchantName')?.value.trim() || '',
      upiVpa: document.getElementById('gatewayUpiVpa')?.value.trim() || '',
    };
    // Only send keys that were entered / changed; secrets are never pre-filled.
    const keyChanged = keyId && keyId !== (this.gatewayConfig?.keyId || '');
    if (keyChanged) payload.keyId = keyId;
    if (keySecret) payload.keySecret = keySecret;
    if (webhookSecret) payload.webhookSecret = webhookSecret;
    if (keyChanged && !keySecret) {
      this.showToast('Enter the Key Secret for the new Key ID.', '⚠️', 'warning');
      return;
    }
    const ok = await this.apiMutate('/api/platform/gateway/config', payload);
    if (!ok) return;
    this.showToast(keyChanged || keySecret ? 'Razorpay keys verified and saved.' : 'Gateway settings saved.', '💾');
    await this.renderGatewaySettings();
  }

  async clearGatewayKeys() {
    if (!confirm('Remove the Razorpay keys saved in the admin panel? Payments will use the server environment keys (if any) instead.')) return;
    const ok = await this.apiMutate('/api/platform/gateway/config', { clearKeys: true });
    if (!ok) return;
    this.showToast('Saved Razorpay keys removed.', '🗑️');
    await this.renderGatewaySettings();
  }

  async testGatewayConnection() {
    const spinner = document.getElementById('gatewayPingSpinner');
    if (spinner) spinner.style.display = 'inline-block';
    const diagStatus = document.getElementById('gatewayDiagnosticStatus');
    const diagMsg = document.getElementById('gatewayDiagnosticMessage');
    if (diagStatus) { diagStatus.className = 'badge badge-trial'; diagStatus.textContent = 'Testing…'; }
    try {
      const res = await fetch('/api/platform/gateway/test', { method: 'POST', headers: this.getAuthHeaders({ 'Content-Type': 'application/json' }) });
      const data = await res.json();
      if (diagStatus) {
        diagStatus.className = data.success ? 'badge badge-success' : 'badge badge-expired';
        diagStatus.textContent = data.success ? `Connected (${data.latencyMs}ms)` : 'Connection rejected';
      }
      if (diagMsg) diagMsg.textContent = data.message || data.error || '';
      this.showToast(data.success ? 'Razorpay credentials verified.' : (data.error || 'Gateway test failed'), data.success ? '⚡' : '⚠️', data.success ? 'success' : 'danger');
    } catch (_) {
      if (diagStatus) { diagStatus.className = 'badge badge-expired'; diagStatus.textContent = 'Request failed'; }
    } finally {
      if (spinner) spinner.style.display = 'none';
    }
  }

  copyWebhookUrl() {
    const hookEl = document.getElementById('gatewayWebhookDisplayUrl');
    if (hookEl) {
      navigator.clipboard?.writeText(hookEl.value).catch(() => {});
      this.showToast('Webhook endpoint copied to clipboard!', '📋');
    }
  }

  // ==============================================
  // VIEW: AUDIT TRAIL & SYSTEM HEALTH
  // ==============================================
  async renderAuditLogs() {
    const tbody = document.getElementById('auditLogsTableBody');
    if (!tbody) return;

    try {
      const category = this.currentAuditCategory || 'all';
      const url = category === 'all' ? '/api/platform/audit-logs' : `/api/platform/audit-logs?category=${encodeURIComponent(category)}`;
      const res = await fetch(url, { headers: this.getAuthHeaders() });
      if (res.ok) {
        const data = await res.json();
        this.auditLogs = data.logs || [];

        // Update telemetry badge & count
        const countEl = document.getElementById('telemetryAuditCount');
        if (countEl) countEl.textContent = `${this.auditLogs.length} Events`;

        if (!this.auditLogs.length) {
          tbody.innerHTML = `
            <tr>
              <td colspan="6" style="text-align: center; padding: 32px; color: var(--text-muted);">
                🛡️ No audit records match category filter "${this.escapeHtml(category)}".
              </td>
            </tr>
          `;
          return;
        }

        tbody.innerHTML = this.auditLogs.map(item => {
          const time = item.timestamp ? new Date(item.timestamp).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' }) : '—';
          const date = item.timestamp ? new Date(item.timestamp).toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' }) : '';
          
          let catBadge = 'badge-active';
          const cat = (item.category || 'SYSTEM').toUpperCase();
          if (cat === 'GATEWAY') catBadge = 'badge-blue';
          else if (cat === 'BILLING') catBadge = 'badge-success';
          else if (cat === 'SECURITY') catBadge = 'badge-expired';
          else if (cat === 'BROADCAST') catBadge = 'badge-trial';
          else if (cat === 'CONFIG') catBadge = 'badge-flat';

          const status = (item.status || 'success').toLowerCase();
          let statusBadge = `<span class="badge badge-success" style="font-size: 10px;">OK</span>`;
          if (status === 'warning') statusBadge = `<span class="badge badge-trial" style="font-size: 10px;">WARN</span>`;
          if (status === 'failed') statusBadge = `<span class="badge badge-expired" style="font-size: 10px;">FAIL</span>`;

          return `
            <tr>
              <td>
                <div style="font-weight: 700; color: var(--text-main); font-size: 12px;">${time}</div>
                <div style="font-size: 11px; color: var(--text-muted);">${date}</div>
              </td>
              <td>
                <span class="badge ${catBadge}" style="font-size: 10.5px; font-weight: 700;">
                  ${this.escapeHtml(cat)}
                </span>
              </td>
              <td>
                <code style="font-size: 11.5px; font-weight: 700; color: var(--text-main);">${this.escapeHtml(item.action || '')}</code>
              </td>
              <td>
                <div style="font-size: 12.5px; color: var(--text-secondary);">${this.escapeHtml(item.details || '')}</div>
              </td>
              <td>
                <div style="font-size: 12px; font-weight: 600; color: var(--text-main);">${this.escapeHtml(item.actor || 'super_admin')}</div>
                <div style="font-size: 10.5px; color: var(--text-muted);">${this.escapeHtml(item.ip || '127.0.0.1')}</div>
              </td>
              <td>
                ${statusBadge}
              </td>
            </tr>
          `;
        }).join('');
      }
    } catch (_) {
      tbody.innerHTML = `
        <tr>
          <td colspan="6" style="text-align: center; padding: 24px; color: var(--text-muted);">
            Audit log stream temporarily unavailable. Click "Refresh Logs" to retry.
          </td>
        </tr>
      `;
    }
  }

  filterAuditLogs(category) {
    this.currentAuditCategory = category;
    document.querySelectorAll('.audit-filter-pill').forEach(pill => {
      pill.classList.toggle('active', pill.dataset.category === category);
    });
    this.renderAuditLogs();
  }

  async refreshAuditLogs() {
    await this.renderAuditLogs();
    this.showToast('Audit records re-synced.', '🛡️');
  }

  exportAuditLogs() {
    if (!this.auditLogs || !this.auditLogs.length) {
      this.showToast('No audit logs to export.', '⚠️');
      return;
    }
    const headers = ['Timestamp', 'Category', 'Action', 'Details', 'Actor', 'IP', 'Status'];
    const rows = this.auditLogs.map(l => [l.timestamp, l.category, l.action, l.details, l.actor, l.ip, l.status]);
    this.downloadCSV(headers, rows, `salesarmy_audit_trail_${new Date().toISOString().slice(0, 10)}.csv`);
    this.showToast('Audit log CSV exported.', '📥');
  }
}

// Global App Instance Initialization
let adminApp;
document.addEventListener('DOMContentLoaded', () => {
  adminApp = new AdminPortal();
  window.adminApp = adminApp;
});
