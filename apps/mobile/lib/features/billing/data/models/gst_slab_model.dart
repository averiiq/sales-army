class GstSlabModel {
  final String id;
  final double rate; // e.g. 0.0, 5.0, 12.0, 18.0, 28.0, 3.0, 7.5
  final String name; // e.g. "Standard FMCG", "Concessional Food Products"
  final String category; // "Standard Goods", "Concessional", "Nil / Exempt", "Luxury & Demerit", "Special Goods", "Services", "Custom Slab"
  final String details; // Detailed description of applicability
  final String? note; // Circular reference, legal note, or dealer remark
  final String? hsnCodes; // e.g. "1905, 2106"
  final bool isDefault; // true for standard slabs
  final bool isActive;
  final DateTime createdAt;

  const GstSlabModel({
    required this.id,
    required this.rate,
    required this.name,
    required this.category,
    required this.details,
    this.note,
    this.hsnCodes,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
  });

  double get cgstRate => rate / 2.0;
  double get sgstRate => rate / 2.0;
  double get igstRate => rate;

  String get formattedRate => rate % 1 == 0 ? '${rate.toInt()}%' : '${rate.toStringAsFixed(1)}%';
  String get displayName => '$formattedRate - $name';

  GstSlabModel copyWith({
    String? id,
    double? rate,
    String? name,
    String? category,
    String? details,
    String? note,
    String? hsnCodes,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return GstSlabModel(
      id: id ?? this.id,
      rate: rate ?? this.rate,
      name: name ?? this.name,
      category: category ?? this.category,
      details: details ?? this.details,
      note: note ?? this.note,
      hsnCodes: hsnCodes ?? this.hsnCodes,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'rate': rate,
      'name': name,
      'category': category,
      'details': details,
      'note': note,
      'hsnCodes': hsnCodes,
      'isDefault': isDefault,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GstSlabModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime created;
    final rawDate = map['createdAt'];
    if (rawDate is String) {
      created = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      created = rawDate;
    } else {
      created = DateTime.now();
    }

    return GstSlabModel(
      id: docId ?? map['id'] ?? 'gst_${(map['rate'] ?? 0).toString().replaceAll('.', '_')}',
      rate: (map['rate'] as num?)?.toDouble() ?? 0.0,
      name: map['name'] ?? 'Custom GST Slab',
      category: map['category'] ?? 'Custom Slab',
      details: map['details'] ?? '',
      note: map['note'],
      hsnCodes: map['hsnCodes'],
      isDefault: map['isDefault'] ?? false,
      isActive: map['isActive'] ?? true,
      createdAt: created,
    );
  }

  static List<GstSlabModel> get defaultSlabs => [
        GstSlabModel(
          id: 'gst_0',
          rate: 0.0,
          name: 'Nil / Exempted FMCG Goods',
          category: 'Nil / Exempt',
          details: 'Fresh milk, fresh vegetables, unbranded grains, fresh eggs, salt, organic flour',
          note: 'Exempt under GST Notification No. 2/2017-Central Tax',
          hsnCodes: '0401, 0701, 1001',
          isDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        GstSlabModel(
          id: 'gst_5',
          rate: 5.0,
          name: 'FMCG Essentials & Staples',
          category: 'Concessional',
          details: 'Edible cooking oils, branded packaged tea, spices, sugar, branded packaged pulses',
          note: 'Schedule I of Central GST (CGST 2.5% + SGST 2.5%)',
          hsnCodes: '1507, 0902, 1701',
          isDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        GstSlabModel(
          id: 'gst_12',
          rate: 12.0,
          name: 'Processed & Dairy Foods',
          category: 'Concessional',
          details: 'Butter, ghee, cheese, packaged fruit juices, instant noodles, roasted snacks, namkeen',
          note: 'Schedule II of Central GST (CGST 6.0% + SGST 6.0%)',
          hsnCodes: '0405, 2009, 1902',
          isDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        GstSlabModel(
          id: 'gst_18',
          rate: 18.0,
          name: 'Standard Goods & Services Tax',
          category: 'Standard Goods',
          details: 'Biscuits, cakes, chocolates, confectionery, soaps, shampoos, toothpastes, detergents',
          note: 'Schedule III of Central GST (CGST 9.0% + SGST 9.0%)',
          hsnCodes: '1905, 1806, 3401, 3306',
          isDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
        GstSlabModel(
          id: 'gst_28',
          rate: 28.0,
          name: 'Luxury & Aerated Beverages',
          category: 'Luxury & Demerit',
          details: 'Aerated carbonated drinks, caffeinated energy drinks, demerit products',
          note: 'Schedule IV of Central GST (CGST 14.0% + SGST 14.0%)',
          hsnCodes: '2202, 2402',
          isDefault: true,
          isActive: true,
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
}
