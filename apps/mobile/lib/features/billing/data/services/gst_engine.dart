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
    
    if (isIntraState) {
      cgst = totalGst / 2.0;
      sgst = totalGst / 2.0;
    } else {
      igst = totalGst;
    }
    
    double grandTotal = taxableAmount + totalGst;
    
    return {
      'taxableAmount': _roundToTwoDecimals(taxableAmount),
      'gstRate': gstRate,
      'cgst': _roundToTwoDecimals(cgst),
      'sgst': _roundToTwoDecimals(sgst),
      'igst': _roundToTwoDecimals(igst),
      'totalGst': _roundToTwoDecimals(totalGst),
      'grandTotal': _roundToTwoDecimals(grandTotal),
    };
  }

  static double _roundToTwoDecimals(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
