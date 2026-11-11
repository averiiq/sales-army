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

  static List<CouponModel> get defaultCoupons => [
    const CouponModel(
      code: 'TRIAL30',
      type: CouponType.trial,
      value: 30,
      title: '30-Day Free Membership Trial',
      description: 'Unlock 30 days of full Enterprise distributor access for ₹0 today.',
    ),
    const CouponModel(
      code: 'TRIAL14',
      type: CouponType.trial,
      value: 14,
      title: '14-Day Free Membership Trial',
      description: 'Get 2 weeks of full features with zero upfront payment.',
    ),
    const CouponModel(
      code: 'FLAT100',
      type: CouponType.flat,
      value: 100,
      title: '₹100 Flat Membership Discount',
      description: 'Instant ₹100 flat reduction on any monthly or yearly subscription.',
      minAmount: 300,
    ),
    const CouponModel(
      code: 'SAVE200',
      type: CouponType.flat,
      value: 200,
      title: '₹200 Flat Mega Savings',
      description: 'Flat ₹200 off on Grow & Enterprise plans.',
      minAmount: 500,
    ),
    const CouponModel(
      code: 'WELCOME50',
      type: CouponType.percentage,
      value: 50,
      title: '50% First Month Welcome Off',
      description: 'Get half off on your initial distributor plan activation.',
    ),
    const CouponModel(
      code: 'FESTIVE25',
      type: CouponType.percentage,
      value: 25,
      title: '25% Annual Celebration Discount',
      description: 'Seasonal promotion for Platinum Annual memberships.',
      minAmount: 3999,
    ),
    const CouponModel(
      code: 'FREE100',
      type: CouponType.percentage,
      value: 100,
      title: '100% Off Lifetime Fee Waiver',
      description: 'Executive waiver for strategic wholesale accounts.',
    ),
    const CouponModel(
      code: 'DEMO1MONTH',
      type: CouponType.trial,
      value: 30,
      title: '1 Month Free Full App Demo',
      description: '30-Day demo trial pass matching in-app super admin defaults.',
    ),
    const CouponModel(
      code: 'FREE1WEEK',
      type: CouponType.trial,
      value: 7,
      title: '1 Week (7 Days) Free Access Pass',
      description: '7-day full access demo pass for quick trials.',
    ),
    const CouponModel(
      code: 'DEMO1DAY',
      type: CouponType.trial,
      value: 1,
      title: '1 Day Free Full App Demo',
      description: '1-day instant full feature evaluation pass.',
    ),
    const CouponModel(
      code: 'SAVE50',
      type: CouponType.percentage,
      value: 50,
      title: '50% Off Subscription',
      description: 'Half-price activation for new distributor onboarding.',
    ),
  ];
}
