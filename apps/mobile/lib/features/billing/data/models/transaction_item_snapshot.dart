class TransactionItemSnapshot {
  final String productId;
  final String productName;
  final String? sku;
  final String? hsnSacCode;
  
  final int quantity;
  final double rate; // price per unit
  final double taxableAmount; // rate * quantity
  
  final double gstRate;
  final double cgst;
  final double sgst;
  final double igst;
  final double totalGst;
  
  final double total; // taxableAmount + totalGst

  // Backward-compatibility aliases
  double get unitPrice => rate;
  double get itemSubtotal => taxableAmount;
  double get itemGst => totalGst;
  double get itemGrandTotal => total;

  TransactionItemSnapshot({
    required this.productId,
    required this.productName,
    this.sku,
    this.hsnSacCode,
    required this.quantity,
    double? rate,
    double? unitPrice,
    double? taxableAmount,
    double? itemSubtotal,
    this.gstRate = 0.0,
    this.cgst = 0.0,
    this.sgst = 0.0,
    this.igst = 0.0,
    double? totalGst,
    double? itemGst,
    double? total,
    double? itemGrandTotal,
  })  : rate = rate ?? unitPrice ?? 0.0,
        taxableAmount = taxableAmount ?? itemSubtotal ?? ((rate ?? unitPrice ?? 0.0) * quantity),
        totalGst = totalGst ?? itemGst ?? 0.0,
        total = total ?? itemGrandTotal ?? ((taxableAmount ?? itemSubtotal ?? ((rate ?? unitPrice ?? 0.0) * quantity)) + (totalGst ?? itemGst ?? 0.0));

  factory TransactionItemSnapshot.fromMap(Map<String, dynamic> data) {
    final qty = (data['quantity'] as num?)?.toInt() ?? 1;
    final r = (data['rate'] ?? data['unitPrice'] ?? data['unit_price'] as num?)?.toDouble() ?? 0.0;
    final taxable = (data['taxableAmount'] ?? data['itemSubtotal'] ?? data['taxable_amount'] as num?)?.toDouble() ?? (r * qty);
    final gst = (data['totalGst'] ?? data['itemGst'] ?? data['gstAmount'] ?? data['gst_amount'] as num?)?.toDouble() ?? 0.0;
    final tot = (data['total'] ?? data['itemGrandTotal'] as num?)?.toDouble() ?? (taxable + gst);

    return TransactionItemSnapshot(
      productId: (data['productId'] ?? data['product_id'] ?? '').toString(),
      productName: (data['productName'] ?? data['product_name'] ?? '').toString(),
      sku: data['sku']?.toString(),
      hsnSacCode: (data['hsnSacCode'] ?? data['hsnSac'] ?? data['hsn_sac'])?.toString(),
      quantity: qty,
      rate: r,
      taxableAmount: taxable,
      gstRate: (data['gstRate'] ?? data['gst_rate'] as num?)?.toDouble() ?? 0.0,
      cgst: (data['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (data['sgst'] as num?)?.toDouble() ?? 0.0,
      igst: (data['igst'] as num?)?.toDouble() ?? 0.0,
      totalGst: gst,
      total: tot,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'sku': sku,
      'hsnSacCode': hsnSacCode,
      'quantity': quantity,
      'rate': rate,
      'unitPrice': rate,
      'taxableAmount': taxableAmount,
      'itemSubtotal': taxableAmount,
      'gstRate': gstRate,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'totalGst': totalGst,
      'itemGst': totalGst,
      'total': total,
      'itemGrandTotal': total,
    };
  }
}
