/// Minimal representation of a Bluetooth printer discovered on the device.
/// Only name + MAC are kept — RSSI, pairing status and fake "Available" labels
/// were dropped because they were simulated in the previous iteration.
class PrinterDevice {
  final String name;
  final String address; // MAC address

  const PrinterDevice({
    required this.name,
    required this.address,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
      };

  factory PrinterDevice.fromMap(Map<String, dynamic> map) {
    return PrinterDevice(
      name: (map['name'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
    );
  }
}

/// Persisted printer configuration. Only fields the UI + the real ESC/POS
/// pipeline actually consume survive. Everything that existed solely to
/// decorate the old mock settings screen (battery level, RSSI signal, print
/// darkness, command protocol, WiFi IP/port, USB device name, auto-cut toggle,
/// FSSAI toggle) has been removed.
class PrinterSettingsModel {
  final bool isEnabled;
  final String printerName;
  final String printerMac;
  final String paperSize; // '58mm' or '80mm'
  final bool autoPrintOnBill;
  final String printCopies; // '1 Copy', '2 Copies', '3 Copies'
  final bool printDynamicQrOnReceipt;
  final bool printAgencyAddress;
  final bool printGstin;
  final bool beepBuzzer;
  final String receiptHeaderNote;
  final String receiptFooterNote;
  final int feedLinesBeforeCut;
  final bool isConnected;
  final String upiVpa;

  const PrinterSettingsModel({
    this.isEnabled = false,
    this.printerName = '',
    this.printerMac = '',
    this.paperSize = '58mm',
    this.autoPrintOnBill = false,
    this.printCopies = '1 Copy',
    this.printDynamicQrOnReceipt = true,
    this.printAgencyAddress = true,
    this.printGstin = true,
    this.beepBuzzer = false,
    this.receiptHeaderNote = 'TAX INVOICE / CASH MEMO',
    this.receiptFooterNote = 'Thank you for your business.',
    this.feedLinesBeforeCut = 3,
    this.isConnected = false,
    this.upiVpa = '',
  });

  /// Character columns per line for the chosen roll width. 32 on 58 mm,
  /// 48 on 80 mm — these match standard ESC/POS CP437 glyph widths.
  int get columnsCount => paperSize == '80mm' ? 48 : 32;

  int get copiesCount {
    if (printCopies.startsWith('2')) return 2;
    if (printCopies.startsWith('3')) return 3;
    return 1;
  }

  PrinterSettingsModel copyWith({
    bool? isEnabled,
    String? printerName,
    String? printerMac,
    String? paperSize,
    bool? autoPrintOnBill,
    String? printCopies,
    bool? printDynamicQrOnReceipt,
    bool? printAgencyAddress,
    bool? printGstin,
    bool? beepBuzzer,
    String? receiptHeaderNote,
    String? receiptFooterNote,
    int? feedLinesBeforeCut,
    bool? isConnected,
    String? upiVpa,
  }) {
    return PrinterSettingsModel(
      isEnabled: isEnabled ?? this.isEnabled,
      printerName: printerName ?? this.printerName,
      printerMac: printerMac ?? this.printerMac,
      paperSize: paperSize ?? this.paperSize,
      autoPrintOnBill: autoPrintOnBill ?? this.autoPrintOnBill,
      printCopies: printCopies ?? this.printCopies,
      printDynamicQrOnReceipt: printDynamicQrOnReceipt ?? this.printDynamicQrOnReceipt,
      printAgencyAddress: printAgencyAddress ?? this.printAgencyAddress,
      printGstin: printGstin ?? this.printGstin,
      beepBuzzer: beepBuzzer ?? this.beepBuzzer,
      receiptHeaderNote: receiptHeaderNote ?? this.receiptHeaderNote,
      receiptFooterNote: receiptFooterNote ?? this.receiptFooterNote,
      feedLinesBeforeCut: feedLinesBeforeCut ?? this.feedLinesBeforeCut,
      isConnected: isConnected ?? this.isConnected,
      upiVpa: upiVpa ?? this.upiVpa,
    );
  }

  Map<String, dynamic> toMap() => {
        'isEnabled': isEnabled,
        'printerName': printerName,
        'printerMac': printerMac,
        'paperSize': paperSize,
        'autoPrintOnBill': autoPrintOnBill,
        'printCopies': printCopies,
        'printDynamicQrOnReceipt': printDynamicQrOnReceipt,
        'printAgencyAddress': printAgencyAddress,
        'printGstin': printGstin,
        'beepBuzzer': beepBuzzer,
        'receiptHeaderNote': receiptHeaderNote,
        'receiptFooterNote': receiptFooterNote,
        'feedLinesBeforeCut': feedLinesBeforeCut,
        'isConnected': isConnected,
        'upiVpa': upiVpa,
      };

  factory PrinterSettingsModel.fromMap(Map<String, dynamic> map) {
    return PrinterSettingsModel(
      isEnabled: map['isEnabled'] as bool? ?? false,
      printerName: map['printerName'] as String? ?? '',
      printerMac: map['printerMac'] as String? ?? '',
      paperSize: map['paperSize'] as String? ?? '58mm',
      autoPrintOnBill: map['autoPrintOnBill'] as bool? ?? false,
      printCopies: map['printCopies'] as String? ?? '1 Copy',
      printDynamicQrOnReceipt: map['printDynamicQrOnReceipt'] as bool? ?? true,
      printAgencyAddress: map['printAgencyAddress'] as bool? ?? true,
      printGstin: map['printGstin'] as bool? ?? true,
      beepBuzzer: map['beepBuzzer'] as bool? ?? false,
      receiptHeaderNote: map['receiptHeaderNote'] as String? ?? 'TAX INVOICE / CASH MEMO',
      receiptFooterNote: map['receiptFooterNote'] as String? ?? 'Thank you for your business.',
      feedLinesBeforeCut: (map['feedLinesBeforeCut'] as num?)?.toInt() ?? 3,
      isConnected: map['isConnected'] as bool? ?? false,
      upiVpa: map['upiVpa'] as String? ?? '',
    );
  }
}
