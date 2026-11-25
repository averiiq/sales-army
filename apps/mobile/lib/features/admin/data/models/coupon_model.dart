enum CouponType {
  trial,       // Free trial on membership (e.g. 14 days, 30 days)
  flat,        // Flat rupee discount (e.g. ₹100 off, ₹200 off)
  percentage,  // Percentage discount (e.g. 25% off)
}

class CouponModel {
  final String code;
  final CouponType type;
  final double value; // e.g. 30 (days), 100 (rupees), 25 (percent)
  final String title;
  final String description;
  final double minAmount;
  final DateTime? expiryDate;
  final bool isActive;
  final int maxUses;
  final int usedCount;

  const CouponModel({
    required this.code,
    required this.type,
    required this.value,
    required this.title,
    required this.description,
    this.minAmount = 0.0,
    this.expiryDate,
    this.isActive = true,
    this.maxUses = 1000,
    this.usedCount = 0,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  bool get isValid => isActive && !isExpired && usedCount < maxUses;

  int get trialDays => type == CouponType.trial ? value.toInt() : 0;

  double calculateDiscount(double price) {
    if (!isValid || price < minAmount) return 0.0;
    switch (type) {
      case CouponType.trial:
        return price; // 100% off for trial period
      case CouponType.flat:
        return value > price ? price : value;
      case CouponType.percentage:
        return (price * (value.clamp(0, 100) / 100.0));
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'type': type.name,
      'value': value,
      'title': title,
      'description': description,
      'minAmount': minAmount,
      'expiryDate': expiryDate?.toIso8601String(),
      'isActive': isActive,
      'maxUses': maxUses,
      'usedCount': usedCount,
    };
  }

  factory CouponModel.fromMap(Map<String, dynamic> map) {
    CouponType cType;
    final tStr = map['type']?.toString().toLowerCase() ?? '';
    if (tStr.contains('trial')) {
      cType = CouponType.trial;
    } else if (tStr.contains('flat')) {
      cType = CouponType.flat;
    } else {
      cType = CouponType.percentage;
    }

    return CouponModel(
      code: map['code']?.toString().toUpperCase() ?? '',
      type: cType,
      value: (map['value'] as num?)?.toDouble() ?? 0.0,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      minAmount: (map['minAmount'] as num?)?.toDouble() ?? ((map['minOrderValue'] as num?)?.toDouble() ?? 0.0),
      expiryDate: map['expiryDate'] != null
          ? DateTime.tryParse(map['expiryDate'].toString())
          : (map['validUntil'] != null ? DateTime.tryParse(map['validUntil'].toString()) : null),
      isActive: map['isActive'] as bool? ?? true,
      maxUses: (map['maxUses'] as num?)?.toInt() ?? 1000,
      usedCount: (map['usedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
