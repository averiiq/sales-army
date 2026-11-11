class OrderItemEntity {
  final String productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final double gstRate;
  final double itemSubtotal;
  final double itemGst;
  final double itemGrandTotal;

  const OrderItemEntity({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.gstRate,
    required this.itemSubtotal,
    required this.itemGst,
    required this.itemGrandTotal,
  });
}

class OrderEntity {
  final String orderId;
  final String shopId;
  final String createdByUid;
  final String status; // pending, confirmed, delivered, cancelled
  final List<OrderItemEntity> items;
  final double subtotal;
  final double totalGst;
  final double grandTotal;
  final String? deliveryNote;
  final DateTime? placedAt;
  final DateTime? deliveredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? clientMutationId; // UUIDv4 idempotency key

  const OrderEntity({
    required this.orderId,
    required this.shopId,
    required this.createdByUid,
    this.status = 'pending',
    required this.items,
    required this.subtotal,
    required this.totalGst,
    required this.grandTotal,
    this.deliveryNote,
    this.placedAt,
    this.deliveredAt,
    this.createdAt,
    this.updatedAt,
    this.clientMutationId,
  });

  OrderEntity copyWith({
    String? orderId,
    String? shopId,
    String? createdByUid,
    String? status,
    List<OrderItemEntity>? items,
    double? subtotal,
    double? totalGst,
    double? grandTotal,
    String? deliveryNote,
    DateTime? placedAt,
    DateTime? deliveredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? clientMutationId,
  }) {
    return OrderEntity(
      orderId: orderId ?? this.orderId,
      shopId: shopId ?? this.shopId,
      createdByUid: createdByUid ?? this.createdByUid,
      status: status ?? this.status,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      totalGst: totalGst ?? this.totalGst,
      grandTotal: grandTotal ?? this.grandTotal,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      placedAt: placedAt ?? this.placedAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      clientMutationId: clientMutationId ?? this.clientMutationId,
    );
  }
}
