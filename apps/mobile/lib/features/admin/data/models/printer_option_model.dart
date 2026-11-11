class PrinterOptionModel {
  final String id;
  final String name;
  final double price;
  final double gstRate;
  final String paperWidth;
  final String connectivity;
  final String description;
  final List<String> features;
  final bool isAvailable;
  final bool isDefault;

  const PrinterOptionModel({
    required this.id,
    required this.name,
    required this.price,
    this.gstRate = 18.0,
    this.paperWidth = '58mm (2-inch)',
    this.connectivity = 'Bluetooth 4.0 / Android ESC/POS',
    this.description = '',
    this.features = const [],
    this.isAvailable = true,
    this.isDefault = false,
  });

  double get gstAmount => price * (gstRate / 100);
  double get totalPriceWithGst => price + gstAmount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'gstRate': gstRate,
      'paperWidth': paperWidth,
      'connectivity': connectivity,
      'description': description,
      'features': features,
      'isAvailable': isAvailable,
      'isDefault': isDefault,
    };
  }

  factory PrinterOptionModel.fromMap(Map<String, dynamic> map, [String? documentId]) {
    final rawPrice = map['price'] ?? map['amount'] ?? map['rate'] ?? 2499.0;
    final price = (rawPrice is num) ? rawPrice.toDouble() : double.tryParse(rawPrice.toString()) ?? 2499.0;
    final rawGst = map['gstRate'] ?? map['gst'] ?? 18.0;
    final gstRate = (rawGst is num) ? rawGst.toDouble() : double.tryParse(rawGst.toString()) ?? 18.0;
    final featList = (map['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    return PrinterOptionModel(
      id: map['id'] ?? documentId ?? 'printer_58mm_standard',
      name: map['name'] ?? map['title'] ?? '58mm Standard Bluetooth Thermal POS Printer',
      price: price,
      gstRate: gstRate,
      paperWidth: map['paperWidth'] ?? map['size'] ?? '58mm (2-inch)',
      connectivity: map['connectivity'] ?? 'Bluetooth 4.0 / Android ESC/POS',
      description: map['description'] ?? '',
      features: featList,
      isAvailable: map['isAvailable'] ?? map['isActive'] ?? map['inStock'] ?? true,
      isDefault: map['isDefault'] ?? false,
    );
  }

  PrinterOptionModel copyWith({
    String? name,
    double? price,
    double? gstRate,
    String? paperWidth,
    String? connectivity,
    String? description,
    List<String>? features,
    bool? isAvailable,
    bool? isDefault,
  }) {
    return PrinterOptionModel(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      gstRate: gstRate ?? this.gstRate,
      paperWidth: paperWidth ?? this.paperWidth,
      connectivity: connectivity ?? this.connectivity,
      description: description ?? this.description,
      features: features ?? this.features,
      isAvailable: isAvailable ?? this.isAvailable,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static List<PrinterOptionModel> get defaultOptions => const [
    PrinterOptionModel(
      id: 'printer_58mm_standard',
      name: '58mm Standard Bluetooth Thermal POS Printer',
      price: 2499.0,
      gstRate: 18.0,
      paperWidth: '58mm (2-inch)',
      connectivity: 'Bluetooth 4.0 / Android ESC/POS',
      description: 'Ultra-portable field billing printer for sales executives & delivery vans',
      features: [
        '58mm (2-inch) Receipt Roll',
        '2000mAh Li-ion Rechargeable Battery',
        'Instant Bluetooth Pairing with SalesArmy App',
        'Drop-in Easy Paper Loading',
      ],
      isAvailable: true,
      isDefault: true,
    ),
    PrinterOptionModel(
      id: 'printer_80mm_pro',
      name: '80mm Heavy-Duty Bluetooth & USB POS Printer',
      price: 3999.0,
      gstRate: 18.0,
      paperWidth: '80mm (3-inch)',
      connectivity: 'Bluetooth + USB + RJ11 Cash Drawer',
      description: 'High-speed commercial counter-top billing printer with auto-cutter for wholesale godowns',
      features: [
        '80mm (3-inch) Full Tax Invoice Format',
        'Heavy-Duty Automatic Cutter (1.5M cuts)',
        'Dual USB & Bluetooth Connectivity',
        'High Speed 260mm/sec Thermal Printing',
      ],
      isAvailable: true,
      isDefault: false,
    ),
    PrinterOptionModel(
      id: 'printer_58mm_pocket',
      name: '58mm Pocket Mini Mobile Thermal Printer',
      price: 1899.0,
      gstRate: 18.0,
      paperWidth: '58mm (2-inch)',
      connectivity: 'Bluetooth LE (Low Energy)',
      description: 'Ultra-compact lightweight belt-clip printer for rapid on-foot beat delivery',
      features: [
        'Ultra-Lightweight 180g Belt-Clip Body',
        '1500mAh Power-Efficient Battery',
        'Direct ESC/POS Wireless Command Protocol',
        'Tough Rubberized Drop-Resistant Frame',
      ],
      isAvailable: true,
      isDefault: false,
    ),
  ];
}
