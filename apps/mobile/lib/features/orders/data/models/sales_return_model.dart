import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';

class SalesReturnModel {
  final String returnId;
  final String returnNumber;
  final String shopId;
  final String shopName;
  final DateTime date;
  final List<TransactionItemSnapshot> items;
  final double totalAmount;
  final String reason;
  final String? notes;
  final DateTime? createdAt;
  final String? createdByUid;

  SalesReturnModel({
    required this.returnId,
    required this.returnNumber,
    required this.shopId,
    required this.shopName,
    required this.date,
    required this.items,
    required this.totalAmount,
    this.reason = 'Damaged Goods',
    this.notes,
    this.createdAt,
    this.createdByUid,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory SalesReturnModel.fromMap(Map<String, dynamic> data, String documentId) {
    return SalesReturnModel(
      returnId: data['returnId'] ?? documentId,
      returnNumber: data['returnNumber'] ?? 'RET-${documentId.substring(0, 6).toUpperCase()}',
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] ?? '',
      date: _parseDateTime(data['date']) ?? DateTime.now(),
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItemSnapshot.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      reason: data['reason'] ?? 'Damaged Goods',
      notes: data['notes'],
      createdAt: _parseDateTime(data['createdAt']),
      createdByUid: data['createdByUid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'returnId': returnId,
      'returnNumber': returnNumber,
      'shopId': shopId,
      'shopName': shopName,
      'date': date.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
      'totalAmount': totalAmount,
      'reason': reason,
      'notes': notes,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'createdByUid': createdByUid,
    };
  }
}
