class GstEngine {
  /// Calculates the GST components based on standard rules.
  /// 
  /// For intra-state (same state) transactions: CGST + SGST
  /// For inter-state (different state) transactions: IGST
  static Map<String, double> calculateGst({
    required double taxableAmount,
    required double gstRate,
    required String sellerState,
    required String buyerState,
  }) {
    double totalGst = (taxableAmount * gstRate) / 100.0;
    
    double cgst = 0.0;
    double sgst = 0.0;
    double igst = 0.0;
    
    // Normalize states for comparison
    bool isIntraState = sellerState.trim().toLowerCase() == buyerState.trim().toLowerCase();
    
    // Round totalGst first, then split to ensure CGST + SGST == totalGst exactly.
    totalGst = roundToTwoDecimals(totalGst);

    if (isIntraState) {
      cgst = roundToTwoDecimals(totalGst / 2.0);
      sgst = roundToTwoDecimals(totalGst - cgst); // derive sgst to prevent rounding drift
    } else {
      igst = totalGst;
    }

    final roundedTaxable = roundToTwoDecimals(taxableAmount);
    double grandTotal = roundToTwoDecimals(roundedTaxable + totalGst);

    return {
      'taxableAmount': roundedTaxable,
      'gstRate': gstRate,
      'cgst': cgst,
      'sgst': sgst,
      'igst': igst,
      'totalGst': totalGst,
      'grandTotal': grandTotal,
    };
  }

  static double roundToTwoDecimals(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
