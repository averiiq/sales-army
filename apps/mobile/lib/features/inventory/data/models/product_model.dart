import 'package:salesarmy/core/utils/product_image_helper.dart';

class ProductVariant {
  final String size;
  final String unit;
  final double? wholesalePrice;
  final double? retailPrice;
  final double? customerPrice;
  final int? stockQuantity;
  final String? sku;

  const ProductVariant({
    required this.size,
    required this.unit,
    this.wholesalePrice,
    this.retailPrice,
    this.customerPrice,
    this.stockQuantity,
    this.sku,
  });

  String get displayName => '$size $unit'.trim();

  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    return ProductVariant(
      size: map['size']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '',
      wholesalePrice: (map['wholesalePrice'] as num?)?.toDouble(),
      retailPrice: (map['retailPrice'] as num?)?.toDouble(),
      customerPrice: (map['customerPrice'] ?? map['mrp'] as num?)?.toDouble(),
      stockQuantity: (map['stockQuantity'] as num?)?.toInt(),
      sku: map['sku']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'size': size,
      'unit': unit,
      if (wholesalePrice != null) 'wholesalePrice': wholesalePrice,
      if (retailPrice != null) 'retailPrice': retailPrice,
      if (customerPrice != null) 'customerPrice': customerPrice,
      if (stockQuantity != null) 'stockQuantity': stockQuantity,
      if (sku != null) 'sku': sku,
    };
  }
}

class ProductModel {
  final String productId;
  final String name;
  final String? variant;
  final String? size;
  final String? categoryId;
  final List<ProductVariant>? variants;
  
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

  // Compatibility aliases
  int get currentStock => stockQuantity;
  int get lowStockAlert => lowStockAlertQty;

  String get displayImageUrl => ProductImageHelper.getImageUrl(
        imageUrl,
        productName: name,
        categoryId: categoryId,
      );

  ProductModel({
    required this.productId,
    required this.name,
    this.variant,
    this.size,
    this.categoryId,
    this.variants,
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

  static DateTime? _parseDateTime(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory ProductModel.fromMap(Map<String, dynamic> data, String documentId) {
    final base = (data['basePrice'] ?? data['base_price'] as num?)?.toDouble() ??
        (data['sellingPrice'] ?? data['selling_price'] as num?)?.toDouble() ??
        0.0;
    final ws = (data['wholesalePrice'] ?? data['wholesale_price'] as num?)?.toDouble() ?? base;
    final ret = (data['retailPrice'] ?? data['retail_price'] as num?)?.toDouble() ?? base;
    final cust = (data['customerPrice'] ?? data['customer_price'] as num?)?.toDouble() ??
        (data['mrp'] as num?)?.toDouble() ??
        base;

    List<ProductVariant>? parsedVariants;
    if (data['variants'] is List) {
      parsedVariants = (data['variants'] as List)
          .whereType<Map<String, dynamic>>()
          .map((m) => ProductVariant.fromMap(m))
          .toList();
    }

    return ProductModel(
      productId: data['productId'] ?? data['product_id'] ?? documentId,
      name: data['name'] ?? '',
      variant: data['variant'],
      size: data['size'],
      categoryId: data['categoryId'] ?? data['category_id'] ?? data['category'],
      variants: parsedVariants,
      sku: data['sku'],
      barcode: data['barcode'],
      hsnSacCode: data['hsnSacCode'] ?? data['hsn_sac'] ?? data['hsnSac'],
      basePrice: base > 0 ? base : ws,
      wholesalePrice: ws,
      retailPrice: ret,
      customerPrice: cust,
      gstRate: (data['gstRate'] ?? data['gst_rate'] as num?)?.toDouble() ?? 0.0,
      stockQuantity: (data['stockQuantity'] ?? data['stock_quantity'] as num?)?.toInt() ?? 0,
      lowStockAlertQty: (data['lowStockAlertQty'] ?? data['low_stock_threshold'] ?? data['lowStockThreshold'] as num?)?.toInt() ?? 5,
      imageUrl: data['imageUrl'] ?? data['image_url'],
      isActive: data['isActive'] ?? data['is_active'] ?? true,
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['updated_at']),
      createdByUid: data['createdByUid'] ?? data['created_by_uid'],
      updatedByUid: data['updatedByUid'] ?? data['updated_by_uid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'name': name,
      'variant': variant,
      'size': size,
      'categoryId': categoryId,
      if (variants != null) 'variants': variants!.map((v) => v.toMap()).toList(),
      'sku': sku,
      'barcode': barcode,
      'hsnSacCode': hsnSacCode,
      'basePrice': basePrice,
      'wholesalePrice': wholesalePrice,
      'retailPrice': retailPrice,
      'customerPrice': customerPrice,
      'gstRate': gstRate,
      'stockQuantity': stockQuantity,
      'lowStockAlertQty': lowStockAlertQty,
      'imageUrl': imageUrl,
      'isActive': isActive,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'createdByUid': createdByUid,
      'updatedByUid': updatedByUid,
    };
  }

  ProductModel copyWith({
    String? productId,
    String? name,
    String? variant,
    String? size,
    String? categoryId,
    List<ProductVariant>? variants,
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
    return ProductModel(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      variant: variant ?? this.variant,
      size: size ?? this.size,
      categoryId: categoryId ?? this.categoryId,
      variants: variants ?? this.variants,
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
