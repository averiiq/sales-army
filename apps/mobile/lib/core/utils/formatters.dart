class AppFormatters {
  static String currency(double? amount, {bool showSymbol = true, bool trimZeroDecimals = true}) {
    if (amount == null) return showSymbol ? '₹0' : '0';
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    
    // Check if integer amount or has fractional part
    final hasFractions = (absAmount - absAmount.truncateToDouble()).abs() > 0.001;
    final String formattedNumber;
    
    if (trimZeroDecimals && !hasFractions) {
      String integerPart = absAmount.toInt().toString();
      if (integerPart.length > 3) {
        final lastThree = integerPart.substring(integerPart.length - 3);
        final remaining = integerPart.substring(0, integerPart.length - 3);
        final regExp = RegExp(r'(\d+?)(?=(\d{2})+$)');
        final formattedRemaining = remaining.replaceAllMapped(regExp, (m) => '${m[1]},');
        integerPart = '$formattedRemaining,$lastThree';
      }
      formattedNumber = '$sign$integerPart';
    } else {
      final parts = absAmount.toStringAsFixed(2).split('.');
      String integerPart = parts[0];
      final decimalPart = parts[1];

      if (integerPart.length > 3) {
        final lastThree = integerPart.substring(integerPart.length - 3);
        final remaining = integerPart.substring(0, integerPart.length - 3);
        final regExp = RegExp(r'(\d+?)(?=(\d{2})+$)');
        final formattedRemaining = remaining.replaceAllMapped(regExp, (m) => '${m[1]},');
        integerPart = '$formattedRemaining,$lastThree';
      }
      formattedNumber = '$sign$integerPart.$decimalPart';
    }

    return showSymbol ? '₹$formattedNumber' : formattedNumber;
  }

  static String compactCurrency(double? amount) {
    if (amount == null) return '₹0';
    if (amount.abs() >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(1)}Cr';
    } else if (amount.abs() >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(1)}L';
    } else if (amount.abs() >= 1000) {
      return '₹${(amount / 1000).toStringAsFixed(1)}K';
    }
    return '₹${amount.toStringAsFixed(0)}';
  }

  static String date(DateTime? dt) {
    if (dt == null) return '-';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    return '$day $month ${dt.year}';
  }

  static String dateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = date(dt);
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$d, $hour:$minute $amPm';
  }

  static String numberToWords(double amount) {
    final intVal = amount.round();
    if (intVal == 0) return 'Zero Rupees Only';

    final units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine',
      'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen',
      'Seventeen', 'Eighteen', 'Nineteen'
    ];
    final tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'
    ];

    String convertLessThanOneThousand(int n) {
      if (n == 0) return '';
      if (n < 20) return '${units[n]} ';
      if (n < 100) return '${tens[n ~/ 10]} ${units[n % 10]} ';
      return '${units[n ~/ 100]} Hundred ${convertLessThanOneThousand(n % 100)}';
    }

    int num = intVal;
    String words = '';

    if (num >= 10000000) {
      words += '${convertLessThanOneThousand(num ~/ 10000000)}Crore ';
      num %= 10000000;
    }
    if (num >= 100000) {
      words += '${convertLessThanOneThousand(num ~/ 100000)}Lakh ';
      num %= 100000;
    }
    if (num >= 1000) {
      words += '${convertLessThanOneThousand(num ~/ 1000)}Thousand ';
      num %= 1000;
    }
    if (num > 0) {
      words += convertLessThanOneThousand(num);
    }

    return '${words.trim()} Rupees Only';
  }
}

typedef Formatters = AppFormatters;
