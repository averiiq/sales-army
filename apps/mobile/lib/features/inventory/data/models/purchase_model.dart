class PurchaseItemModel {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double total;

  const PurchaseItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
    };
  }

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      productId: map['productId']?.toString() ?? '',
      productName: map['productName']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: (map['unitPrice'] as num?)?.toDouble() ?? 0.0,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PurchaseModel {
  final String id;
  final String supplierName;
  final String billNumber;
  final DateTime purchaseDate;
  final String itemsDescription;
  final int totalUnits;
  final double totalAmount;
  final String paymentStatus; // 'paid', 'pending'
  final String paymentMode; // 'Bank Transfer', 'UPI', 'Cash'
  final String? notes;
  final DateTime createdAt;
  final List<PurchaseItemModel> items;

  const PurchaseModel({
    required this.id,
    required this.supplierName,
    required this.billNumber,
    required this.purchaseDate,
    required this.itemsDescription,
    this.totalUnits = 1,
    required this.totalAmount,
    this.paymentStatus = 'paid',
    this.paymentMode = 'Bank Transfer',
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  PurchaseModel copyWith({
    String? id,
    String? supplierName,
    String? billNumber,
    DateTime? purchaseDate,
    String? itemsDescription,
    int? totalUnits,
    double? totalAmount,
    String? paymentStatus,
    String? paymentMode,
    String? notes,
    DateTime? createdAt,
    List<PurchaseItemModel>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      supplierName: supplierName ?? this.supplierName,
      billNumber: billNumber ?? this.billNumber,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      itemsDescription: itemsDescription ?? this.itemsDescription,
      totalUnits: totalUnits ?? this.totalUnits,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentMode: paymentMode ?? this.paymentMode,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierName': supplierName,
      'billNumber': billNumber,
      'purchaseDate': purchaseDate.toIso8601String(),
      'itemsDescription': itemsDescription,
      'totalUnits': totalUnits,
      'totalAmount': totalAmount,
      'paymentStatus': paymentStatus,
      'paymentMode': paymentMode,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((i) => i.toMap()).toList(),
    };
  }

  factory PurchaseModel.fromMap(Map<String, dynamic> map, String id) {
    List<PurchaseItemModel> parsedItems = [];
    if (map['items'] != null && map['items'] is List) {
      parsedItems = (map['items'] as List)
          .map((itemMap) => PurchaseItemModel.fromMap(Map<String, dynamic>.from(itemMap as Map)))
          .toList();
    }

    return PurchaseModel(
      id: id,
      supplierName: map['supplierName'] as String? ?? 'Distributor Supplier',
      billNumber: map['billNumber'] as String? ?? 'PUR-0001',
      purchaseDate: map['purchaseDate'] != null
          ? DateTime.tryParse(map['purchaseDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      itemsDescription: map['itemsDescription'] as String? ?? 'Assorted FMCG Goods',
      totalUnits: (map['totalUnits'] as num?)?.toInt() ?? 1,
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paymentStatus: map['paymentStatus'] as String? ?? 'paid',
      paymentMode: map['paymentMode'] as String? ?? 'Bank Transfer',
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      items: parsedItems,
    );
  }
}
