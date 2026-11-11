class ProductEntity {
  final String productId;
  final String name;
  final String? variant;
  final String? size;
  final String? categoryId;
  final String? sku;
  final String? barcode;
  final String? hsnSacCode;
  final double basePrice;
  final double wholesalePrice;
  final double retailPrice;
  final double customerPrice;
  final double gstRate;
  final int stockQuantity;
  final int lowStockAlertQty;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? createdByUid;
  final String? updatedByUid;

  const ProductEntity({
    required this.productId,
    required this.name,
    this.variant,
    this.size,
    this.categoryId,
    this.sku,
    this.barcode,
    this.hsnSacCode,
    double? basePrice,
    double? wholesalePrice,
    double? retailPrice,
    double? customerPrice,
    required this.gstRate,
    this.stockQuantity = 0,
    this.lowStockAlertQty = 5,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
    this.createdByUid,
    this.updatedByUid,
  })  : wholesalePrice = wholesalePrice ?? basePrice ?? 0.0,
        retailPrice = retailPrice ?? basePrice ?? 0.0,
        customerPrice = customerPrice ?? basePrice ?? 0.0,
        basePrice = basePrice ?? wholesalePrice ?? 0.0;

  bool get isLowStock => stockQuantity <= lowStockAlertQty;
  bool get isInStock => stockQuantity > 0;
  double get priceWithTax => basePrice * (1 + (gstRate / 100));

  ProductEntity copyWith({
    String? productId,
    String? name,
    String? variant,
    String? size,
    String? categoryId,
    String? sku,
    String? barcode,
    String? hsnSacCode,
    double? basePrice,
    double? wholesalePrice,
    double? retailPrice,
    double? customerPrice,
    double? gstRate,
    int? stockQuantity,
    int? lowStockAlertQty,
    String? imageUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdByUid,
    String? updatedByUid,
  }) {
    return ProductEntity(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      variant: variant ?? this.variant,
      size: size ?? this.size,
      categoryId: categoryId ?? this.categoryId,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      hsnSacCode: hsnSacCode ?? this.hsnSacCode,
      basePrice: basePrice ?? this.basePrice,
      wholesalePrice: wholesalePrice ?? this.wholesalePrice,
      retailPrice: retailPrice ?? this.retailPrice,
      customerPrice: customerPrice ?? this.customerPrice,
      gstRate: gstRate ?? this.gstRate,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockAlertQty: lowStockAlertQty ?? this.lowStockAlertQty,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdByUid: createdByUid ?? this.createdByUid,
      updatedByUid: updatedByUid ?? this.updatedByUid,
    );
  }
}
