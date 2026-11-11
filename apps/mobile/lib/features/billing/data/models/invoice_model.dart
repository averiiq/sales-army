import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';

class InvoiceModel {
  final String invoiceId;
  final String invoiceNumber;
  final String orderId;
  final String shopId;
  
  final String invoiceType; // GST, NON_GST, GST_ONLY
  final DateTime invoiceDate;
  
  // Seller Snapshot (Tenant at time of invoice)
  final Map<String, dynamic> seller; 
  // Buyer Snapshot (Shop at time of invoice)
  final Map<String, dynamic> buyer;
  
  final String placeOfSupply; // State name
  
  final List<TransactionItemSnapshot> items;
  
  final double taxableSubtotal;
  final double cgst;
  final double sgst;
  final double igst;
  final double grandTotal;
  
  final double paidAmount;
  final double dueAmount;
  
  final String paymentStatus; // paid, partial, unpaid
  
  final String? pdfUrl;
  final bool whatsappSent;
  
  final DateTime? createdAt;
  final DateTime? updatedAt;

  double get totalGst => cgst + sgst + igst;
  double get subtotal => taxableSubtotal;
  double get balanceDue => dueAmount;
  String get shopName => buyer['shopName'] as String? ?? buyer['name'] as String? ?? 'Valued Customer';

  InvoiceModel({
    required this.invoiceId,
    required this.invoiceNumber,
    required this.orderId,
    required this.shopId,
    required this.invoiceType,
    required this.invoiceDate,
    required this.seller,
    required this.buyer,
    required this.placeOfSupply,
    required this.items,
    required this.taxableSubtotal,
    required this.cgst,
    required this.sgst,
    required this.igst,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
    this.paymentStatus = 'unpaid',
    this.pdfUrl,
    this.whatsappSent = false,
    this.createdAt,
    this.updatedAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory InvoiceModel.fromMap(Map<String, dynamic> data, String documentId) {
    return InvoiceModel(
      invoiceId: data['invoiceId'] ?? data['invoice_id'] ?? documentId,
      invoiceNumber: data['invoiceNumber'] ?? data['invoice_number'] ?? '',
      orderId: data['orderId'] ?? data['order_id'] ?? '',
      shopId: data['shopId'] ?? data['shop_id'] ?? '',
      invoiceType: data['invoiceType'] ?? data['invoice_type'] ?? 'NON_GST',
      invoiceDate: _parseDateTime(data['invoiceDate'] ?? data['invoice_date']) ?? DateTime.now(),
      seller: Map<String, dynamic>.from(data['seller'] ?? data['seller_details'] ?? {}),
      buyer: Map<String, dynamic>.from(data['buyer'] ?? data['buyer_details'] ?? {}),
      placeOfSupply: data['placeOfSupply'] ?? data['place_of_supply'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => TransactionItemSnapshot.fromMap(item as Map<String, dynamic>))
              .toList() ?? [],
      taxableSubtotal: ((data['taxableSubtotal'] ?? data['taxableAmount'] ?? data['taxable_amount']) as num?)?.toDouble() ?? 0.0,
      cgst: (data['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (data['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (data['igst'] as num?)?.toDouble() ?? 0.0,
      grandTotal: ((data['grandTotal'] ?? data['grand_total']) as num?)?.toDouble() ?? 0.0,
      paidAmount: ((data['paidAmount'] ?? data['amountPaid'] ?? data['amount_paid']) as num?)?.toDouble() ?? 0.0,
      dueAmount: ((data['dueAmount'] ?? data['amountDue'] ?? data['amount_due']) as num?)?.toDouble() ?? 0.0,
      paymentStatus: data['paymentStatus'] ?? data['payment_status'] ?? 'unpaid',
      pdfUrl: data['pdfUrl'] ?? data['pdf_url'],
      whatsappSent: data['whatsappSent'] ?? data['whatsapp_sent'] ?? false,
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['updated_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'invoiceId': invoiceId,
      'invoiceNumber': invoiceNumber,
      'orderId': orderId,
      'shopId': shopId,
      'invoiceType': invoiceType,
      'invoiceDate': invoiceDate.toIso8601String(),
      'seller': seller,
      'buyer': buyer,
      'placeOfSupply': placeOfSupply,
      'items': items.map((item) => item.toMap()).toList(),
      'taxableSubtotal': taxableSubtotal,
      'taxableAmount': taxableSubtotal,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'totalGst': totalGst,
      'grandTotal': grandTotal,
      'paidAmount': paidAmount,
      'amountPaid': paidAmount,
      'dueAmount': dueAmount,
      'amountDue': dueAmount,
      'paymentStatus': paymentStatus,
      'pdfUrl': pdfUrl,
      'whatsappSent': whatsappSent,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }

  InvoiceModel copyWith({
    String? invoiceId,
    String? invoiceNumber,
    String? orderId,
    String? shopId,
    String? invoiceType,
    DateTime? invoiceDate,
    Map<String, dynamic>? seller,
    Map<String, dynamic>? buyer,
    String? placeOfSupply,
    List<TransactionItemSnapshot>? items,
    double? taxableSubtotal,
    double? cgst,
    double? sgst,
    double? igst,
    double? grandTotal,
    double? paidAmount,
    double? dueAmount,
    String? paymentStatus,
    String? pdfUrl,
    bool? whatsappSent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InvoiceModel(
      invoiceId: invoiceId ?? this.invoiceId,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      orderId: orderId ?? this.orderId,
      shopId: shopId ?? this.shopId,
      invoiceType: invoiceType ?? this.invoiceType,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      seller: seller ?? this.seller,
      buyer: buyer ?? this.buyer,
      placeOfSupply: placeOfSupply ?? this.placeOfSupply,
      items: items ?? this.items,
      taxableSubtotal: taxableSubtotal ?? this.taxableSubtotal,
      cgst: cgst ?? this.cgst,
      sgst: sgst ?? this.sgst,
      igst: igst ?? this.igst,
      grandTotal: grandTotal ?? this.grandTotal,
      paidAmount: paidAmount ?? this.paidAmount,
      dueAmount: dueAmount ?? this.dueAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      pdfUrl: pdfUrl ?? this.pdfUrl,
      whatsappSent: whatsappSent ?? this.whatsappSent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
