class ShopEntity {
  final String shopId;
  final String shopName;
  final String ownerName;
  final String? phone;
  final String? whatsappNumber;
  final String? businessType;
  final String? categoryId;
  final String? gstin;
  final String? address;
  final String visitFrequency;
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

  const ShopEntity({
    required this.shopId,
    required this.shopName,
    required this.ownerName,
    this.phone,
    this.whatsappNumber,
    this.businessType,
    this.categoryId,
    this.gstin,
    this.address,
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

  bool get hasAvailableCredit => (creditLimit - currentOutstanding) > 0;
  double get availableCredit => (creditLimit - currentOutstanding).clamp(0.0, double.infinity);
  bool get hasOverdueBalance => currentOutstanding > creditLimit && creditLimit > 0;

  ShopEntity copyWith({
    String? shopId,
    String? shopName,
    String? ownerName,
    String? phone,
    String? whatsappNumber,
    String? businessType,
    String? categoryId,
    String? gstin,
    String? address,
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
    return ShopEntity(
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      ownerName: ownerName ?? this.ownerName,
      phone: phone ?? this.phone,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      businessType: businessType ?? this.businessType,
      categoryId: categoryId ?? this.categoryId,
      gstin: gstin ?? this.gstin,
      address: address ?? this.address,
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
}
