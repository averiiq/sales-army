class PaymentModel {
  final String paymentId;
  final String shopId;
  final String createdByUid;
  
  final double amount;
  final String paymentMode; // Cash, UPI, NEFT, Cheque
  final String? referenceNumber; // UTR or Cheque Number
  
  final DateTime date;
  final String? notes;
  
  final DateTime? createdAt;

  PaymentModel({
    required this.paymentId,
    required this.shopId,
    required this.createdByUid,
    required this.amount,
    required this.paymentMode,
    this.referenceNumber,
    required this.date,
    this.notes,
    this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory PaymentModel.fromMap(Map<String, dynamic> data, String documentId) {
    return PaymentModel(
      paymentId: data['paymentId'] ?? data['payment_id'] ?? documentId,
      shopId: data['shopId'] ?? data['shop_id'] ?? '',
      createdByUid: data['createdByUid'] ?? data['collected_by'] ?? data['collectedBy'] ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: data['paymentMode'] ?? data['mode'] ?? 'Cash',
      referenceNumber: data['referenceNumber'] ?? data['reference'] ?? data['razorpayPaymentId'],
      date: _parseDateTime(data['date'] ?? data['payment_date'] ?? data['paymentDate']) ?? DateTime.now(),
      notes: data['notes'],
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'paymentId': paymentId,
      'shopId': shopId,
      'createdByUid': createdByUid,
      'amount': amount,
      'paymentMode': paymentMode,
      'referenceNumber': referenceNumber,
      'date': date.toIso8601String(),
      'paymentDate': date.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }

  PaymentModel copyWith({
    String? paymentId,
    String? shopId,
    String? createdByUid,
    double? amount,
    String? paymentMode,
    String? referenceNumber,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return PaymentModel(
      paymentId: paymentId ?? this.paymentId,
      shopId: shopId ?? this.shopId,
      createdByUid: createdByUid ?? this.createdByUid,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
