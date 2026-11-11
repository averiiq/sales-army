import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';

class OrderModel {
  final String orderId;
  final String shopId;
  final String createdByUid;
  
  final String status; // pending, confirmed, delivered, cancelled
  
  final List<TransactionItemSnapshot> items;
  
  final double subtotal; // Taxable amount
  final double totalGst;
  final double grandTotal;
  
  final String? deliveryNote;
  
  final DateTime? placedAt;
  final DateTime? deliveredAt;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  OrderModel({
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
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory OrderModel.fromMap(Map<String, dynamic> data, String documentId) {
    return OrderModel(
      orderId: data['orderId'] ?? data['order_id'] ?? documentId,
      shopId: data['shopId'] ?? data['shop_id'] ?? '',
      createdByUid: data['createdByUid'] ?? data['sales_person_uid'] ?? data['salesPersonUid'] ?? '',
      status: data['status'] ?? 'pending',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItemSnapshot.fromMap(item as Map<String, dynamic>))
              .toList() ??
          (data['order_items'] as List<dynamic>?)
              ?.map((item) => TransactionItemSnapshot.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      totalGst: (data['totalGst'] ?? data['total_gst'] as num?)?.toDouble() ?? 0.0,
      grandTotal: (data['grandTotal'] ?? data['grand_total'] as num?)?.toDouble() ?? 0.0,
      deliveryNote: data['deliveryNote'] ?? data['delivery_note'] ?? data['notes'],
      placedAt: _parseDateTime(data['placedAt'] ?? data['order_date'] ?? data['orderDate']),
      deliveredAt: _parseDateTime(data['deliveredAt'] ?? data['delivered_at']),
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['updated_at']),
    );
  }

  OrderModel copyWith({
    String? orderId,
    String? shopId,
    String? createdByUid,
    String? status,
    List<TransactionItemSnapshot>? items,
    double? subtotal,
    double? totalGst,
    double? grandTotal,
    String? deliveryNote,
    DateTime? placedAt,
    DateTime? deliveredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrderModel(
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'shopId': shopId,
      'createdByUid': createdByUid,
      'status': status,
      'items': items.map((item) => item.toMap()).toList(),
      'subtotal': subtotal,
      'totalGst': totalGst,
      'grandTotal': grandTotal,
      'deliveryNote': deliveryNote,
      'placedAt': placedAt != null ? placedAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'orderDate': placedAt != null ? placedAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'deliveredAt': deliveredAt?.toIso8601String(),
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }
}
