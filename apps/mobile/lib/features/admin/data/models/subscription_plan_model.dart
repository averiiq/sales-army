/// A subscription plan as configured by the super admin (web admin → Plans).
///
/// [allowedFeatures] are capability keys (see FeatureGate.capabilityLabels /
/// web-admin CAPABILITIES) and are the ONLY source of what a plan unlocks.
/// Numeric limits use 0 for "unlimited".
class SubscriptionPlanModel {
  /// Capability-catalog version. Plans saved before v2 never listed the core
  /// selling keys because the app did not lock them; they are granted on load
  /// so existing customers keep what they had.
  static const int featuresVersion = 2;
  static const List<String> legacyImplicitFeatures = [
    'order_taking', 'estimate_bills', 'sales_returns', 'collections', 'purchases',
    'expenses', 'visits', 'staff_management', 'thermal_printer', 'reports',
  ];
  static const List<String> coreFeatures = [
    'order_taking', 'estimate_bills', 'invoicing', 'sales_returns', 'collections', 'khata_ledger',
    'purchases', 'expenses', 'visits', 'thermal_printer', 'reports', 'gst_reports', 'offline_sync',
  ];

  /// True when [limit] means "no limit".
  static bool isUnlimited(int limit) => limit <= 0;

  final String id;
  final String name; // 'Startup', 'Grow', 'Enterprise'
  final double monthlyPrice;
  final double yearlyMonthlyEquivalent; // Price per month when billed annually
  final double yearlyPrice;
  final int maxProducts;
  final int maxUsers; // legacy — mirrors maxStaff
  final int maxShops;
  final int maxStaff; // staff logins (web-admin: cfgXxxMaxStaff)
  final int maxOrdersPerMonth; // monthly order cap (web-admin: cfgXxxMaxOrders)
  final int maxBranches; // branch/godown locations (web-admin: cfgXxxMaxBranches)
  final String tagline;
  final String description;
  final List<String> features;
  final List<String> allowedFeatures;
  final bool isPopular;
  final bool isActive;

  String get planId => id;
  double get yearlyAnnualTotal => yearlyPrice > 0 ? yearlyPrice : yearlyMonthlyEquivalent * 12;

  const SubscriptionPlanModel({
    String? id,
    String? planId,
    required this.name,
    String? tagline,
    String? description,
    required this.monthlyPrice,
    double? yearlyMonthlyEquivalent,
    double? yearlyPrice,
    this.maxProducts = 50,
    int? maxUsers,
    this.maxShops = 500,
    int? maxStaff,
    this.maxOrdersPerMonth = 200,
    this.maxBranches = 1,
    List<String>? features,
    List<String>? allowedFeatures,
    this.isPopular = false,
    this.isActive = true,
  })  : id = id ?? planId ?? 'startup',
        tagline = tagline ?? description ?? '',
        description = description ?? tagline ?? '',
        yearlyPrice = yearlyPrice ?? ((yearlyMonthlyEquivalent ?? monthlyPrice * 0.8) * 12),
        yearlyMonthlyEquivalent = yearlyMonthlyEquivalent ?? (yearlyPrice != null ? (yearlyPrice / 12) : monthlyPrice * 0.8),
        features = features ?? const [],
        allowedFeatures = allowedFeatures ?? const [],
        maxStaff = maxStaff ?? maxUsers ?? 1,
        maxUsers = maxUsers ?? maxStaff ?? 1;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'planId': id,
      'name': name,
      'description': description,
      'tagline': tagline,
      'monthlyPrice': monthlyPrice,
      'yearlyPrice': yearlyPrice,
      'yearlyMonthlyEquivalent': yearlyMonthlyEquivalent,
      'maxProducts': maxProducts,
      'maxUsers': maxUsers,
      'maxShops': maxShops,
      'maxStaff': maxStaff,
      'maxOrdersPerMonth': maxOrdersPerMonth,
      'maxBranches': maxBranches,
      'features': features,
      'allowedFeatures': allowedFeatures,
      'featuresVersion': featuresVersion,
      'isPopular': isPopular,
      'isActive': isActive,
    };
  }

  factory SubscriptionPlanModel.fromMap(Map<String, dynamic> map, String documentId) {
    final mPrice = (map['monthlyPrice'] as num?)?.toDouble() ?? 399.0;
    final yPrice = ((map['yearlyPrice'] ?? map['annualPrice']) as num?)?.toDouble() ?? (mPrice * 12 * 0.8);
    final yEq = (map['yearlyMonthlyEquivalent'] as num?)?.toDouble() ?? (yPrice / 12);
    // Marketing bullets ("features") and capability keys ("allowedFeatures")
    // are different things — never fall back from one to the other.
    final featList = (map['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final allowed = <String>{
      ...((map['allowedFeatures'] as List?)?.map((e) => e.toString()) ?? const <String>[]),
    };
    final version = (map['featuresVersion'] as num?)?.toInt() ?? 1;
    if (version < featuresVersion) allowed.addAll(legacyImplicitFeatures);
    final staff = (map['maxStaff'] as num?)?.toInt() ?? (map['maxUsers'] as num?)?.toInt() ?? 1;
    final ordersPerMonth = (map['maxOrdersPerMonth'] as num?)?.toInt() ?? 200;
    final branches = (map['maxBranches'] as num?)?.toInt() ?? 1;

    return SubscriptionPlanModel(
      id: map['id'] ?? map['planId'] ?? documentId,
      name: map['name'] ?? 'Startup',
      description: map['description'] ?? '',
      tagline: map['tagline'] ?? map['description'] ?? '',
      monthlyPrice: mPrice,
      yearlyPrice: yPrice,
      yearlyMonthlyEquivalent: yEq,
      maxProducts: (map['maxProducts'] as num?)?.toInt() ?? 50,
      maxUsers: staff,
      maxStaff: staff,
      maxOrdersPerMonth: ordersPerMonth,
      maxBranches: branches,
      maxShops: (map['maxShops'] as num?)?.toInt() ?? 500,
      features: featList,
      allowedFeatures: allowed.toList(),
      isPopular: map['isPopular'] ?? map['highlight'] ?? false,
      isActive: map['isActive'] ?? true,
    );
  }

  SubscriptionPlanModel copyWith({
    String? name,
    double? monthlyPrice,
    double? yearlyMonthlyEquivalent,
    double? yearlyPrice,
    int? maxProducts,
    int? maxUsers,
    int? maxShops,
    int? maxStaff,
    int? maxOrdersPerMonth,
    int? maxBranches,
    String? tagline,
    String? description,
    List<String>? features,
    List<String>? allowedFeatures,
    bool? isPopular,
    bool? isActive,
  }) {
    return SubscriptionPlanModel(
      id: id,
      name: name ?? this.name,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      yearlyMonthlyEquivalent: yearlyMonthlyEquivalent ?? this.yearlyMonthlyEquivalent,
      yearlyPrice: yearlyPrice ?? this.yearlyPrice,
      maxProducts: maxProducts ?? this.maxProducts,
      maxUsers: maxUsers ?? this.maxUsers,
      maxShops: maxShops ?? this.maxShops,
      maxStaff: maxStaff ?? this.maxStaff,
      maxOrdersPerMonth: maxOrdersPerMonth ?? this.maxOrdersPerMonth,
      maxBranches: maxBranches ?? this.maxBranches,
      tagline: tagline ?? this.tagline,
      description: description ?? this.description,
      features: features ?? this.features,
      allowedFeatures: allowedFeatures ?? this.allowedFeatures,
      isPopular: isPopular ?? this.isPopular,
      isActive: isActive ?? this.isActive,
    );
  }

  static List<SubscriptionPlanModel> get defaultPlans => const [
    SubscriptionPlanModel(
      id: 'startup',
      name: 'Startup',
      monthlyPrice: 399.0,
      yearlyMonthlyEquivalent: 319.0,
      maxProducts: 50,
      maxStaff: 2,
      maxOrdersPerMonth: 200,
      maxBranches: 1,
      maxShops: 200,
      tagline: 'Ideal for independent distributors & single-beat routes',
      features: [
        'Up to 50 Products in Catalog',
        '1 Sub-user (Staff seat) included',
        'Unlimited Orders & Khata Invoicing',
        'Offline Outbox & Cloud Sync',
        'Bluetooth Thermal Printer Support',
        'Standard CSV & Excel Exports',
      ],
      allowedFeatures: [...coreFeatures, 'staff_management'],
      isPopular: false,
    ),
    SubscriptionPlanModel(
      id: 'grow',
      name: 'Grow',
      monthlyPrice: 599.0,
      yearlyMonthlyEquivalent: 479.0,
      maxProducts: 200,
      maxStaff: 5,
      maxOrdersPerMonth: 1000,
      maxBranches: 3,
      maxShops: 1000,
      tagline: 'Built for scaling wholesale agencies & 2-van routes',
      features: [
        'Up to 200 Products in Catalog',
        'Up to 5 Staff Users (Field Sales & Van Reps)',
        'Up to 1,000 Retail Shops in Beat Directory',
        'Full GST Tax Slabs & HSN Invoicing',
        'Real-time Beat Dispatch & Van Stock',
        'Automated 12 PM & 10 PM Batch Sync',
        'Priority Phone & WhatsApp Support',
      ],
      allowedFeatures: [...coreFeatures, 'staff_management', 'dynamic_upi_qr', 'live_tracking', 'van_stock', 'bulk_import', 'multi_branch', 'priority_support'],
      isPopular: true,
    ),
    SubscriptionPlanModel(
      id: 'enterprise',
      name: 'Enterprise',
      monthlyPrice: 899.0,
      yearlyMonthlyEquivalent: 719.0,
      maxProducts: 0, // unlimited
      maxStaff: 50,
      maxOrdersPerMonth: 0, // unlimited
      maxBranches: 10,
      maxShops: 10000,
      tagline: 'For high-volume multi-brand super stockists & teams',
      features: [
        '200+ Products (Unlimited Catalog)',
        'Up to 50 Users & Multi-Van Fleet',
        'Dedicated Graphical Business Reports',
        'Complete Audit Vault & Admin Customization',
        'Custom Tax Slabs & Full Multi-GST Slabs',
        '24/7 Dedicated Account Manager',
      ],
      allowedFeatures: [
        ...coreFeatures, 'staff_management', 'dynamic_upi_qr', 'live_tracking', 'van_stock', 'bulk_import',
        'multi_branch', 'multi_van', 'custom_branding', 'custom_tax_slabs', 'admin_customization', 'audit_vault',
        'priority_support', 'dedicated_manager',
      ],
      isPopular: false,
    ),
  ];
}
