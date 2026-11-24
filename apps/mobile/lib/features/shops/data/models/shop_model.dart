/// Party categories. Older builds saved walk-in buyers as "Walk-in Customer";
/// they are shown and saved as "Customer" now.
String normalizeSellerCategory(Object? value) {
  final v = value?.toString().trim() ?? '';
  if (v.isEmpty) return 'Retailer';
  final lower = v.toLowerCase();
  if (lower == 'walk-in customer' || lower == 'walk-in' || lower == 'walkin customer') return 'Customer';
  return v;
}

class ShopModel {
  final String shopId;
  final String shopName;
  final String ownerName;
  
  final String? phone;
  final String? whatsappNumber;
  
  final String? businessType;
  final String? sellerCategory; // 'Retailer', 'Wholesaler' or 'Customer'
  final String? categoryId; // References categories collection
  final String? gstin;
  
  final String? address; // street address & landmark
  final String? city;
  final String? state;
  final String? pincode;
  
  final String visitFrequency; // weekly, biweekly, monthly
  
  final double creditLimit;
  final double currentOutstanding;
  
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  
  final String? notes;
  final bool isActive;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? updatedByUid;

  ShopModel({
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    this.phone,
    this.whatsappNumber,
    this.businessType,
    this.sellerCategory = 'Retailer',
    this.categoryId,
    this.gstin,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.visitFrequency = 'weekly',
    this.creditLimit = 0.0,
    this.currentOutstanding = 0.0,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.notes,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.updatedByUid,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory ShopModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ShopModel(
      shopId: data['shopId'] ?? data['shop_id'] ?? documentId,
      shopName: data['shopName'] ?? data['shop_name'] ?? '',
      ownerName: data['ownerName'] ?? data['owner_name'] ?? '',
      phone: data['phone'],
      whatsappNumber: data['whatsappNumber'] ?? data['whatsapp_number'] ?? data['whatsapp'],
      businessType: data['businessType'] ?? data['business_type'],
      sellerCategory: normalizeSellerCategory(data['sellerCategory'] ?? data['seller_category']),
      categoryId: data['categoryId'] ?? data['category_id'] ?? data['category'],
      gstin: data['gstin'],
      address: data['address'],
      city: data['city'],
      state: data['state'],
      pincode: (data['pincode'] ?? data['pin_code'])?.toString(),
      visitFrequency: data['visitFrequency'] ?? data['visit_frequency'] ?? 'weekly',
      creditLimit: (data['creditLimit'] ?? data['credit_limit'] as num?)?.toDouble() ?? 0.0,
      currentOutstanding: (data['currentOutstanding'] ?? data['current_outstanding'] as num?)?.toDouble() ?? 0.0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      imageUrl: data['imageUrl'] ?? data['image_url'],
      notes: data['notes'],
      isActive: data['isActive'] ?? data['is_active'] ?? true,
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['updated_at']),
      createdByUid: data['createdByUid'] ?? data['created_by_uid'],
      updatedByUid: data['updatedByUid'] ?? data['updated_by_uid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'shopId': shopId,
      'shopName': shopName,
      'ownerName': ownerName,
      'phone': phone,
      'whatsappNumber': whatsappNumber,
      'businessType': businessType,
      'sellerCategory': sellerCategory ?? 'Retailer',
      'categoryId': categoryId,
      'gstin': gstin,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'visitFrequency': visitFrequency,
      'creditLimit': creditLimit,
      'currentOutstanding': currentOutstanding,
      'latitude': latitude,
      'longitude': longitude,
      'imageUrl': imageUrl,
      'notes': notes,
      'isActive': isActive,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
    };
  }

  ShopModel copyWith({
    String? shopId,
    String? shopName,
    String? ownerName,
    String? phone,
    String? whatsappNumber,
    String? businessType,
    String? sellerCategory,
    String? categoryId,
    String? gstin,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? visitFrequency,
    double? creditLimit,
    double? currentOutstanding,
    double? latitude,
    double? longitude,
    String? imageUrl,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
  }) {
    return ShopModel(
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      businessType: businessType ?? this.businessType,
      sellerCategory: sellerCategory != null ? normalizeSellerCategory(sellerCategory) : this.sellerCategory,
      categoryId: categoryId ?? this.categoryId,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      visitFrequency: visitFrequency ?? this.visitFrequency,
      creditLimit: creditLimit ?? this.creditLimit,
      currentOutstanding: currentOutstanding ?? this.currentOutstanding,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      imageUrl: imageUrl ?? this.imageUrl,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }

  String get shopCategory => businessType ?? 'General';

  /// Street address + city, state and pincode as one line (for display,
  /// maps and sharing). Skips empty parts.
  String get fullAddress {
    final cityState = [city, state].where((p) => p != null && p.trim().isNotEmpty).map((p) => p!.trim()).join(', ');
    final tail = [cityState, pincode?.trim() ?? ''].where((p) => p.isNotEmpty).join(' - ');
    return [address?.trim() ?? '', tail].where((p) => p.isNotEmpty).join(', ');
  }
}
