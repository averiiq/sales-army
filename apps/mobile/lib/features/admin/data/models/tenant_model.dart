class TenantModel {
  static Map<String, dynamic>? publicGatewayConfig(Map<String, dynamic>? config) {
    if (config == null) return null;
    return Map<String, dynamic>.from(config)..remove('keySecret')..remove('webhookSecret');
  }
  final String tenantId;
  final String distributorId;
  final String ownerUid;
  
  final String? representativeName;
  final String? mobile;
  final String? whatsappNumber;
  final String? email;
  
  final String? firmName;
  final String? agencyClassification;
  final String? logoUrl;
  final String? profileImageUrl;
  
  final String? gstin;
  final String? pan;
  final String? fssaiLicenseNo;
  final double? defaultGstRate;
  
  final List<String>? authorizedBrandsPortfolio;
  final String? warehouseAddress;
  final String? city;
  final String? state;
  final String? pincode;
  final String? territory;
  final String? beatRoute;
  
  final Map<String, dynamic>? bankAccount; // bankName, accountNumber, ifsc
  
  final String? accountStatus; // active, pending, paused, cancelled, suspended
  final String? subscriptionStatus; // trial, active, expired, cancelled, suspended, pending
  
  // Phase 14: Subscriptions + plans fields
  final String? subscriptionPlanId; // References global plans
  final DateTime? subscriptionEndDate;
  final int? maxUsers;
  final int? maxShops;

  // Settings: GST Tax Billing option
  final bool? isGstBillingEnabled;

  // Settings: UPI VPA, Payment Gateway, Hardware/Printer Configs
  final String? upiId;
  final Map<String, dynamic>? paymentGatewayConfig;
  final Map<String, dynamic>? hardwareConfig;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  String? get phone => mobile;
  String? get address => warehouseAddress;
  String get effectiveUpiId =>
      (upiId != null && upiId!.trim().isNotEmpty)
          ? upiId!.trim()
          : (bankAccount != null && bankAccount!['upiId'] != null && bankAccount!['upiId'].toString().trim().isNotEmpty
              ? bankAccount!['upiId'].toString().trim()
              : '');

  String get qrSource => paymentGatewayConfig?['qrSource'] as String? ?? 'dynamic';
  String? get staticQrImage => paymentGatewayConfig?['staticQrImage'] as String?;

  TenantModel({
    required this.tenantId,
    required this.distributorId,
    required this.ownerUid,
    this.representativeName,
    this.mobile,
    this.whatsappNumber,
    this.email,
    this.firmName,
    this.agencyClassification,
    this.logoUrl,
    this.profileImageUrl,
    this.gstin,
    this.pan,
    this.fssaiLicenseNo,
    this.defaultGstRate,
    this.authorizedBrandsPortfolio,
    this.warehouseAddress,
    this.city,
    this.state,
    this.pincode,
    this.territory,
    this.beatRoute,
    this.bankAccount,
    this.accountStatus,
    this.subscriptionStatus,
    this.subscriptionPlanId,
    this.subscriptionEndDate,
    this.maxUsers,
    this.maxShops,
    this.isGstBillingEnabled = true,
    this.upiId,
    this.paymentGatewayConfig,
    this.hardwareConfig,
    this.createdAt,
    this.updatedAt,
  });

  /// A truly blank tenant used as the initial state before any login and as
  /// the baseline after sign-out. Every editable business field (firmName,
  /// GSTIN, bank, UPI, warehouse, hardware, …) is null so Profile / Business
  /// Details / Payment Preferences all render empty for new signups. There is
  /// no free plan: plan, status and dates come from the server (the admin's
  /// signup trial) once the agency is loaded.
  factory TenantModel.empty({String tenantId = ''}) {
    return TenantModel(
      tenantId: tenantId,
      distributorId: '',
      ownerUid: '',
      accountStatus: 'active',
      isGstBillingEnabled: true,
    );
  }

  TenantModel copyWith({
    String? tenantId,
    String? distributorId,
    String? ownerUid,
    String? representativeName,
    String? mobile,
    String? whatsappNumber,
    String? email,
    String? firmName,
    String? agencyClassification,
    String? logoUrl,
    String? profileImageUrl,
    String? gstin,
    String? pan,
    String? fssaiLicenseNo,
    double? defaultGstRate,
    List<String>? authorizedBrandsPortfolio,
    String? warehouseAddress,
    String? city,
    String? state,
    String? pincode,
    String? territory,
    String? beatRoute,
    Map<String, dynamic>? bankAccount,
    String? accountStatus,
    String? subscriptionStatus,
    String? subscriptionPlanId,
    DateTime? subscriptionEndDate,
    int? maxUsers,
    int? maxShops,
    bool? isGstBillingEnabled,
    String? upiId,
    Map<String, dynamic>? paymentGatewayConfig,
    Map<String, dynamic>? hardwareConfig,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearLogo = false,
    bool clearProfileImage = false,
  }) {
    return TenantModel(
      tenantId: tenantId ?? this.tenantId,
      distributorId: distributorId ?? this.distributorId,
      ownerUid: ownerUid ?? this.ownerUid,
      representativeName: representativeName ?? this.representativeName,
      mobile: mobile ?? this.mobile,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      email: email ?? this.email,
      firmName: firmName ?? this.firmName,
      agencyClassification: agencyClassification ?? this.agencyClassification,
      logoUrl: clearLogo ? null : (logoUrl ?? this.logoUrl),
      profileImageUrl: clearProfileImage ? null : (profileImageUrl ?? this.profileImageUrl),
      gstin: gstin ?? this.gstin,
      pan: pan ?? this.pan,
      fssaiLicenseNo: fssaiLicenseNo ?? this.fssaiLicenseNo,
      defaultGstRate: defaultGstRate ?? this.defaultGstRate,
      authorizedBrandsPortfolio: authorizedBrandsPortfolio ?? this.authorizedBrandsPortfolio,
      warehouseAddress: warehouseAddress ?? this.warehouseAddress,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      territory: territory ?? this.territory,
      beatRoute: beatRoute ?? this.beatRoute,
      bankAccount: bankAccount ?? this.bankAccount,
      accountStatus: accountStatus ?? this.accountStatus,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      subscriptionPlanId: subscriptionPlanId ?? this.subscriptionPlanId,
      subscriptionEndDate: subscriptionEndDate ?? this.subscriptionEndDate,
      maxUsers: maxUsers ?? this.maxUsers,
      maxShops: maxShops ?? this.maxShops,
      isGstBillingEnabled: isGstBillingEnabled ?? this.isGstBillingEnabled,
      upiId: upiId ?? this.upiId,
      paymentGatewayConfig: paymentGatewayConfig ?? this.paymentGatewayConfig,
      hardwareConfig: hardwareConfig ?? this.hardwareConfig,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory TenantModel.fromMap(Map<String, dynamic> data, String documentId) {
    return TenantModel(
      tenantId: documentId,
      distributorId: data['distributorId'] ?? data['distributor_id'] ?? '',
      ownerUid: data['ownerUid'] ?? data['owner_uid'] ?? '',
      representativeName: data['representativeName'] ?? data['contactPerson'] ?? data['contact_person'],
      mobile: data['mobile'],
      whatsappNumber: data['whatsappNumber'] ?? data['whatsapp'] ?? data['whatsapp_number'],
      email: data['email'],
      firmName: data['firmName'] ?? data['businessName'] ?? data['business_name'] ?? data['legalName'] ?? data['legal_name'],
      agencyClassification: data['agencyClassification'] ?? data['agency_classification'],
      logoUrl: data['logoUrl'] ?? data['logo'] ?? data['logo_url'],
      profileImageUrl: data['profileImageUrl'] ?? data['photoUrl'] ?? data['photo_url'] ?? data['avatarUrl'],
      gstin: data['gstin'],
      pan: data['pan'],
      fssaiLicenseNo: data['fssaiLicenseNo'] ?? data['fssai'] ?? data['fssai_license_no'],
      defaultGstRate: (data['defaultGstRate'] ?? data['default_gst_rate'] as num?)?.toDouble(),
      authorizedBrandsPortfolio: (data['authorizedBrandsPortfolio'] is List)
          ? (data['authorizedBrandsPortfolio'] as List).map((e) => e.toString()).toList()
          : (data['authorized_brands'] is List)
              ? (data['authorized_brands'] as List).map((e) => e.toString()).toList()
              : null,
      warehouseAddress: data['warehouseAddress'] ?? data['warehouse_address'] ?? data['address'],
      city: data['city'] ?? data['territory'],
      state: data['state'],
      pincode: (data['pincode'] ?? data['pin_code'])?.toString(),
      territory: data['territory'],
      beatRoute: data['beatRoute'] ?? data['beat_route'],
      bankAccount: (data['bankAccount'] is Map
              ? Map<String, dynamic>.from(data['bankAccount'] as Map)
              : null) ??
          (data['bankDetails'] is Map
              ? Map<String, dynamic>.from(data['bankDetails'] as Map)
              : null) ??
          ((data['bank_name'] != null ||
                  data['bank_account_no'] != null ||
                  data['bankName'] != null ||
                  data['accountNumber'] != null)
              ? {
                  'bankName': data['bank_name'] ?? data['bankName'] ?? '',
                  'accountNumber':
                      data['bank_account_no'] ?? data['accountNumber'] ?? '',
                  'ifsc': (data['bank_ifsc'] ?? data['ifsc'] ?? '').toString().toUpperCase(),
                  'accountHolderName': data['account_holder_name'] ??
                      data['accountHolderName'] ??
                      data['contact_person'] ??
                      data['contactPerson'] ??
                      data['representativeName'] ??
                      data['business_name'] ??
                      data['firmName'] ??
                      '',
                  if (data['upi_id'] != null || data['upiId'] != null || data['vpa'] != null)
                    'upiId': data['upi_id'] ?? data['upiId'] ?? data['vpa'],
                }
              : null),
      accountStatus: data['accountStatus'] ?? data['account_status'],
      subscriptionStatus: data['subscriptionStatus'] ?? data['subscription_status'],
      subscriptionPlanId: data['subscriptionPlanId'] ?? data['planId'] ?? data['plan_id'],
      subscriptionEndDate: _parseDateTime(data['subscriptionEndDate'] ?? data['subscription_end_date'] ?? data['expiryDate']),
      maxUsers: (data['maxUsers'] ?? data['max_users'] as num?)?.toInt(),
      maxShops: (data['maxShops'] ?? data['max_shops'] as num?)?.toInt(),
      isGstBillingEnabled: data['isGstBillingEnabled'] ?? data['is_gst_billing_enabled'] as bool? ?? true,
      upiId: data['upiId'] ??
          data['vpa'] ??
          data['upi_id'] ??
          data['adminUpiId'] ??
          (data['bankAccount'] is Map ? data['bankAccount']['upiId'] : null) ??
          (data['bankDetails'] is Map ? data['bankDetails']['upiId'] : null),
      paymentGatewayConfig: data['paymentGatewayConfig'] != null
          ? publicGatewayConfig(Map<String, dynamic>.from(data['paymentGatewayConfig'] as Map))
          : null,
      hardwareConfig: data['hardwareConfig'] != null
          ? Map<String, dynamic>.from(data['hardwareConfig'] as Map)
          : null,
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      'distributorId': distributorId,
      'ownerUid': ownerUid,
      'representativeName': representativeName,
      'mobile': mobile,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'firmName': firmName,
      'agencyClassification': agencyClassification,
      'logoUrl': logoUrl,
      'profileImageUrl': profileImageUrl,
      'gstin': gstin,
      'pan': pan,
      'fssaiLicenseNo': fssaiLicenseNo,
      'defaultGstRate': defaultGstRate,
      'authorizedBrandsPortfolio': authorizedBrandsPortfolio,
      'warehouseAddress': warehouseAddress,
      'city': city,
      'state': state,
      'pincode': pincode,
      'territory': territory,
      'beatRoute': beatRoute,
      'bankAccount': bankAccount,
      'accountStatus': accountStatus,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionPlanId': subscriptionPlanId,
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'maxUsers': maxUsers,
      'maxShops': maxShops,
      'isGstBillingEnabled': isGstBillingEnabled ?? true,
      'upiId': upiId,
      'paymentGatewayConfig': publicGatewayConfig(paymentGatewayConfig),
      'hardwareConfig': hardwareConfig,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }

  /// JSON-safe serialization without Firestore Timestamp objects (for local storage & Supabase)
  Map<String, dynamic> toJsonMap() {
    return {
      'tenantId': tenantId,
      'distributorId': distributorId,
      'ownerUid': ownerUid,
      'representativeName': representativeName,
      'mobile': mobile,
      'whatsappNumber': whatsappNumber,
      'email': email,
      'firmName': firmName,
      'agencyClassification': agencyClassification,
      'logoUrl': logoUrl,
      'profileImageUrl': profileImageUrl,
      'gstin': gstin,
      'pan': pan,
      'fssaiLicenseNo': fssaiLicenseNo,
      'defaultGstRate': defaultGstRate,
      'authorizedBrandsPortfolio': authorizedBrandsPortfolio,
      'warehouseAddress': warehouseAddress,
      'city': city,
      'state': state,
      'pincode': pincode,
      'territory': territory,
      'beatRoute': beatRoute,
      'bankAccount': bankAccount,
      'accountStatus': accountStatus,
      'subscriptionStatus': subscriptionStatus,
      'subscriptionPlanId': subscriptionPlanId,
      'subscriptionEndDate': subscriptionEndDate?.toIso8601String(),
      'maxUsers': maxUsers,
      'maxShops': maxShops,
      'isGstBillingEnabled': isGstBillingEnabled ?? true,
      'upiId': upiId,
      'paymentGatewayConfig': publicGatewayConfig(paymentGatewayConfig),
      'hardwareConfig': hardwareConfig,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Selective update map for Firestore that strictly avoids touching protected
  /// subscription/governance fields ('accountStatus', 'subscriptionStatus', 'tenantId', 'distributorId', 'ownerUid', 'createdAt')
  Map<String, dynamic> toDistributorUpdateMap() {
    return {
      if (representativeName != null) 'representativeName': representativeName,
      if (mobile != null) 'mobile': mobile,
      if (whatsappNumber != null) 'whatsappNumber': whatsappNumber,
      if (email != null) 'email': email,
      if (firmName != null) 'firmName': firmName,
      if (agencyClassification != null) 'agencyClassification': agencyClassification,
      'logoUrl': logoUrl,
      'profileImageUrl': profileImageUrl,
      if (gstin != null) 'gstin': gstin,
      if (pan != null) 'pan': pan,
      if (fssaiLicenseNo != null) 'fssaiLicenseNo': fssaiLicenseNo,
      if (defaultGstRate != null) 'defaultGstRate': defaultGstRate,
      if (authorizedBrandsPortfolio != null) 'authorizedBrandsPortfolio': authorizedBrandsPortfolio,
      if (warehouseAddress != null) 'warehouseAddress': warehouseAddress,
      if (city != null) 'city': city,
      if (state != null) 'state': state,
      if (pincode != null) 'pincode': pincode,
      if (territory != null) 'territory': territory,
      if (beatRoute != null) 'beatRoute': beatRoute,
      if (bankAccount != null) 'bankAccount': bankAccount,
      if (isGstBillingEnabled != null) 'isGstBillingEnabled': isGstBillingEnabled,
      if (upiId != null) 'upiId': upiId,
      if (paymentGatewayConfig != null) 'paymentGatewayConfig': publicGatewayConfig(paymentGatewayConfig),
      if (hardwareConfig != null) 'hardwareConfig': hardwareConfig,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
