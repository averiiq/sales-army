class LedgerEntryModel {
  final String ledgerId;
  final String shopId;
  final String createdByUid;
  
  final String type; // INVOICE, PAYMENT, CREDIT_NOTE, DEBIT_NOTE
  final String referenceId; // orderId, invoiceId, paymentId
  
  final double amount; // Positive for INVOICE, DEBIT_NOTE (increases debt). Negative for PAYMENT, CREDIT_NOTE (decreases debt).
  final double balanceAfter;
  
  final String description;
  final DateTime date;
  
  final DateTime? createdAt;

  LedgerEntryModel({
    required this.ledgerId,
    required this.shopId,
    required this.createdByUid,
    required this.type,
    required this.referenceId,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    required this.date,
    this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory LedgerEntryModel.fromMap(Map<String, dynamic> data, String documentId) {
    double amt = (data['amount'] as num?)?.toDouble() ?? 0.0;
    if (amt == 0.0) {
      final debit = (data['debit'] as num?)?.toDouble() ?? 0.0;
      final credit = (data['credit'] as num?)?.toDouble() ?? 0.0;
      if (debit > 0) {
        amt = debit;
      } else if (credit > 0) {
        amt = -credit;
      }
    }

    return LedgerEntryModel(
      ledgerId: data['ledgerId'] ?? data['entry_id'] ?? data['ledger_id'] ?? documentId,
      shopId: data['shopId'] ?? data['shop_id'] ?? '',
      createdByUid: data['createdByUid'] ?? data['created_by'] ?? data['createdBy'] ?? '',
      type: data['type'] ?? (data['transactionType'] ?? data['transaction_type'] != null
          ? (data['transactionType'] ?? data['transaction_type']).toString().toUpperCase()
          : 'INVOICE'),
      referenceId: data['referenceId'] ?? data['invoice_id'] ?? data['payment_id'] ?? data['invoiceId'] ?? data['paymentId'] ?? '',
      amount: amt,
      balanceAfter: ((data['balanceAfter'] ?? data['balance_after']) as num?)?.toDouble() ?? 0.0,
      description: data['description'] ?? '',
      date: _parseDateTime(data['date'] ?? data['created_at'] ?? data['createdAt']) ?? DateTime.now(),
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'shopId': shopId,
      'createdByUid': createdByUid,
      'type': type,
      'referenceId': referenceId,
      'amount': amount,
      'balanceAfter': balanceAfter,
      'description': description,
      'date': date.toIso8601String(),
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }
}
