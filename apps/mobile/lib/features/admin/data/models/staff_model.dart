class StaffPermissions {
  final bool billing;
  final bool products;
  final bool profile;
  final bool orders;
  final bool inventory;
  final bool reports;
  final bool accounts;
  final bool staff;
  final bool purchase;
  final bool expense;
  final bool settings;

  const StaffPermissions({
    this.billing = true,
    this.products = true,
    this.profile = true,
    this.orders = true,
    this.inventory = true,
    this.reports = true,
    this.accounts = true,
    this.staff = false,
    this.purchase = true,
    this.expense = true,
    this.settings = false,
  });

  StaffPermissions copyWith({
    bool? billing,
    bool? products,
    bool? profile,
    bool? orders,
    bool? inventory,
    bool? reports,
    bool? accounts,
    bool? staff,
    bool? purchase,
    bool? expense,
    bool? settings,
  }) {
    return StaffPermissions(
      billing: billing ?? this.billing,
      products: products ?? this.products,
      profile: profile ?? this.profile,
      orders: orders ?? this.orders,
      inventory: inventory ?? this.inventory,
      reports: reports ?? this.reports,
      accounts: accounts ?? this.accounts,
      staff: staff ?? this.staff,
      purchase: purchase ?? this.purchase,
      expense: expense ?? this.expense,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'billing': billing,
      'products': products,
      'profile': profile,
      'orders': orders,
      'inventory': inventory,
      'reports': reports,
      'accounts': accounts,
      'staff': staff,
      'purchase': purchase,
      'expense': expense,
      'settings': settings,
    };
  }

  factory StaffPermissions.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StaffPermissions();
    return StaffPermissions(
      billing: map['billing'] as bool? ?? true,
      products: map['products'] as bool? ?? true,
      profile: map['profile'] as bool? ?? true,
      orders: map['orders'] as bool? ?? true,
      inventory: map['inventory'] as bool? ?? true,
      reports: map['reports'] as bool? ?? true,
      accounts: map['accounts'] as bool? ?? true,
      staff: map['staff'] as bool? ?? false,
      purchase: map['purchase'] as bool? ?? true,
      expense: map['expense'] as bool? ?? true,
      settings: map['settings'] as bool? ?? false,
    );
  }

  /// Preset for Owner: all modules enabled
  factory StaffPermissions.owner() {
    return const StaffPermissions(
      billing: true,
      products: true,
      profile: true,
      orders: true,
      inventory: true,
      reports: true,
      accounts: true,
      staff: true,
      purchase: true,
      expense: true,
      settings: true,
    );
  }

  /// Preset for Accountant: Billing, Reports, Accounts, Expenses, Purchases
  factory StaffPermissions.accountant() {
    return const StaffPermissions(
      billing: true,
      products: false,
      profile: false,
      orders: true,
      inventory: true,
      reports: true,
      accounts: true,
      staff: false,
      purchase: true,
      expense: true,
      settings: false,
    );
  }

  /// Preset for Delivery Staff: Orders and Field only, restricted from financial & settings
  factory StaffPermissions.delivery() {
    return const StaffPermissions(
      billing: false,
      products: false,
      profile: false,
      orders: true,
      inventory: false,
      reports: false,
      accounts: false,
      staff: false,
      purchase: false,
      expense: true,
      settings: false,
    );
  }

  /// Preset for Field Sales Staff: Orders, Products, Billing, Expenses
  factory StaffPermissions.fieldSales() {
    return const StaffPermissions(
      billing: true,
      products: true,
      profile: false,
      orders: true,
      inventory: true,
      reports: false,
      accounts: false,
      staff: false,
      purchase: false,
      expense: true,
      settings: false,
    );
  }
}

class StaffModel {
  final String id;
  final String name;
  final String email;
  final String mobile;
  final String role; // 'Owner', 'Accountant', 'Delivery Staff', 'Field Sales', 'Store Manager'
  final bool isActive;
  final StaffPermissions permissions;
  final DateTime createdAt;

  const StaffModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    required this.role,
    this.isActive = true,
    required this.permissions,
    required this.createdAt,
  });

  StaffModel copyWith({
    String? id,
    String? name,
    String? email,
    String? mobile,
    String? role,
    bool? isActive,
    StaffPermissions? permissions,
    DateTime? createdAt,
  }) {
    return StaffModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'role': role,
      'isActive': isActive,
      'permissions': permissions.toMap(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory StaffModel.fromMap(Map<String, dynamic> map, String id) {
    return StaffModel(
      id: id,
      name: map['name'] as String? ?? 'Staff Member',
      email: map['email'] as String? ?? '',
      mobile: map['mobile'] as String? ?? '',
      role: map['role'] as String? ?? 'Field Sales',
      isActive: map['isActive'] as bool? ?? true,
      permissions: StaffPermissions.fromMap(map['permissions'] as Map<String, dynamic>?),
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
