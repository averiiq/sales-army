import 'dart:async';
import 'dart:convert';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/features/settings/data/models/printer_settings_model.dart';
import 'package:salesarmy/features/settings/presentation/screens/printer_settings_screen.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/core/utils/formatters.dart';

/// Thermal receipt printer service backed by [BlueThermalPrinter].
///
/// This replaced an earlier simulation that hardcoded five fake Bluetooth
/// printers and faked RSSI, battery level and print latency. Everything here
/// now talks to a real paired printer over SPP Bluetooth classic.
class PrinterService extends ChangeNotifier {
  static final PrinterService _instance = PrinterService._internal();
  static PrinterService get instance => _instance;

  PrinterService._internal() {
    _loadFromPreferences();
    _wireConnectionStream();
  }

  final BlueThermalPrinter _bt = BlueThermalPrinter.instance;
  StreamSubscription? _stateSubscription;

  PrinterSettingsModel _settings = const PrinterSettingsModel();
  PrinterSettingsModel get settings => _settings;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isPrinting = false;
  bool get isPrinting => _isPrinting;

  final List<PrinterDevice> _pairedDevices = [];
  List<PrinterDevice> get nearbyPrinters => List.unmodifiable(_pairedDevices);

  static const String _prefKey = 'salesarmy_printer_settings_v2';

  // ---------------------------------------------------------------------------
  // Preferences
  // ---------------------------------------------------------------------------

  Future<void> _loadFromPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_prefKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        _settings = PrinterSettingsModel.fromMap(jsonDecode(jsonStr));
      }
      // Reflect the actual plugin connection state, not the last-persisted bit.
      final live = await _bt.isConnected ?? false;
      _settings = _settings.copyWith(isConnected: live);
      notifyListeners();
    } catch (e) {
      debugPrint('PrinterService preferences load note: $e');
    }
  }

  Future<void> saveSettings(PrinterSettingsModel newSettings) async {
    _settings = newSettings;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, jsonEncode(_settings.toMap()));
    } catch (e) {
      debugPrint('PrinterService save settings: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Connection lifecycle
  // ---------------------------------------------------------------------------

  void _wireConnectionStream() {
    try {
      _stateSubscription = _bt.onStateChanged().listen((state) {
        final nowConnected = state == BlueThermalPrinter.CONNECTED;
        if (nowConnected != _settings.isConnected) {
          _settings = _settings.copyWith(isConnected: nowConnected);
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('PrinterService state stream note: $e');
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }

  /// Requests runtime permissions needed on Android 12+ for Bluetooth scan +
  /// connect. Returns true if everything we need is granted.
  Future<bool> ensurePermissions() async {
    try {
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        // Only needed on < Android 12 but harmless when auto-granted.
        Permission.locationWhenInUse,
      ].request();
      return results.values.every((s) => s.isGranted || s.isLimited);
    } catch (e) {
      debugPrint('PrinterService permission check note: $e');
      return false;
    }
  }

  /// Lists paired Bluetooth devices (the plugin cannot discover unpaired ones).
  /// On Android, pair the printer in system Settings → Bluetooth once; from
  /// then on it appears here.
  Future<List<PrinterDevice>> scanBluetoothDevices() async {
    _isScanning = true;
    notifyListeners();
    HapticFeedback.selectionClick();

    try {
      final hasPerm = await ensurePermissions();
      if (!hasPerm) {
        _isScanning = false;
        notifyListeners();
        return [];
      }
      final devices = await _bt.getBondedDevices();
      _pairedDevices
        ..clear()
        ..addAll(devices
            .where((d) => (d.name ?? '').isNotEmpty && (d.address ?? '').isNotEmpty)
            .map((d) => PrinterDevice(name: d.name!, address: d.address!)));
    } catch (e) {
      debugPrint('PrinterService scan error: $e');
      _pairedDevices.clear();
    } finally {
      _isScanning = false;
      notifyListeners();
    }
    return _pairedDevices;
  }

  /// Connects to the specified paired printer. Updates saved settings on
  /// success so the next launch auto-restores the selection.
  Future<bool> selectPrinterDevice(PrinterDevice device) async {
    try {
      final already = await _bt.isConnected ?? false;
      if (already) {
        try {
          await _bt.disconnect();
        } catch (e) {
          debugPrint('PrinterService pre-disconnect: $e');
        }
      }
      final target = BluetoothDevice(device.name, device.address);
      await _bt.connect(target);
      _settings = _settings.copyWith(
        printerName: device.name,
        printerMac: device.address,
        isConnected: true,
        isEnabled: true,
      );
      notifyListeners();
      await saveSettings(_settings);
      return true;
    } catch (e) {
      debugPrint('PrinterService connect error: $e');
      _settings = _settings.copyWith(isConnected: false);
      notifyListeners();
      return false;
    }
  }

  /// Disconnects the active printer without forgetting the saved device MAC.
  Future<void> disconnect() async {
    try {
      await _bt.disconnect();
    } catch (e) {
      debugPrint('PrinterService disconnect: $e');
    }
    _settings = _settings.copyWith(isConnected: false);
    notifyListeners();
    await saveSettings(_settings);
  }

  Future<bool> _ensureConnected(BuildContext? context) async {
    final connected = await _bt.isConnected ?? false;
    if (connected) return true;
    if (_settings.printerMac.isEmpty) {
      if (context != null) _showNotConnectedSnackBar(context);
      return false;
    }
    // Try to reconnect to the last-known printer silently.
    try {
      await _bt.connect(BluetoothDevice(_settings.printerName, _settings.printerMac));
      _settings = _settings.copyWith(isConnected: true);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('PrinterService auto-reconnect failed: $e');
      if (context != null) _showNotConnectedSnackBar(context);
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // ESC/POS string formatters (reused by all receipt types)
  // ---------------------------------------------------------------------------

  String _center(String text, int width) {
    if (text.length >= width) return text.substring(0, width);
    final leftPadding = (width - text.length) ~/ 2;
    return ' ' * leftPadding + text;
  }

  String _twoColumns(String left, String right, int width) {
    final available = width - right.length;
    if (left.length > available) {
      left = left.substring(0, available > 0 ? available : 0);
    }
    final spaces = width - (left.length + right.length);
    return left + (' ' * (spaces > 0 ? spaces : 1)) + right;
  }

  String _separator(int width, [String char = '-']) => char * width;

  String formatInvoiceReceipt(
    InvoiceModel invoice, {
    String? tenantFirm,
    String? tenantGstin,
    String? tenantAddress,
    String? tenantPhone,
    String? upiId,
  }) {
    final w = _settings.columnsCount;
    final sb = StringBuffer();

    final firm = tenantFirm ?? invoice.seller['firmName'] ?? '';
    final gstin = tenantGstin ?? invoice.seller['gstin'] ?? '';
    final address = tenantAddress ?? invoice.seller['address'] ?? '';
    final phone = tenantPhone ?? invoice.seller['phone'] ?? '';

    sb.writeln(_center('*** ${_settings.receiptHeaderNote} ***', w));
    if (firm.isNotEmpty) sb.writeln(_center(firm.toUpperCase(), w));

    if (_settings.printAgencyAddress) {
      if (address.isNotEmpty) sb.writeln(_center(address, w));
      if (phone.isNotEmpty) sb.writeln(_center('Phone: $phone', w));
    }
    if (_settings.printGstin && gstin.isNotEmpty) {
      sb.writeln(_center('GSTIN: $gstin', w));
    }
    sb.writeln(_separator(w, '='));

    sb.writeln(_twoColumns('Bill No: ${invoice.invoiceNumber}',
        AppFormatters.date(invoice.invoiceDate), w));
    final buyerShop = invoice.buyer['shopName'] ?? 'Retail Customer';
    sb.writeln('Buyer  : $buyerShop');
    final buyerGstin = invoice.buyer['gstin'];
    if (buyerGstin != null && buyerGstin.toString().isNotEmpty && buyerGstin != 'Unregistered / B2C') {
      sb.writeln('B-GSTIN: $buyerGstin');
    }
    sb.writeln(_separator(w, '-'));

    sb.writeln(w >= 48
        ? _twoColumns('ITEM DETAILS (HSN)', 'QTY   RATE   TOTAL', w)
        : _twoColumns('ITEM', 'QTY  RATE  TOTAL', w));
    sb.writeln(_separator(w, '-'));

    for (final item in invoice.items) {
      final name = item.productName;
      final qtyStr = '${item.quantity}';
      final rateStr = item.rate.toStringAsFixed(1);
      final totalStr = item.total.toStringAsFixed(1);
      final right = '$qtyStr x $rateStr = $totalStr';
      sb.writeln(_twoColumns(name, right, w));
      if (w >= 48 && item.hsnSacCode != null && item.hsnSacCode!.isNotEmpty) {
        sb.writeln('  [HSN: ${item.hsnSacCode} • GST ${item.gstRate.toStringAsFixed(0)}%]');
      }
    }
    sb.writeln(_separator(w, '-'));

    sb.writeln(_twoColumns('Subtotal (Taxable):', 'Rs. ${invoice.taxableSubtotal.toStringAsFixed(2)}', w));
    if (invoice.cgst > 0) {
      sb.writeln(_twoColumns('CGST Tax:', 'Rs. ${invoice.cgst.toStringAsFixed(2)}', w));
      sb.writeln(_twoColumns('SGST Tax:', 'Rs. ${invoice.sgst.toStringAsFixed(2)}', w));
    }
    if (invoice.igst > 0) {
      sb.writeln(_twoColumns('IGST Tax:', 'Rs. ${invoice.igst.toStringAsFixed(2)}', w));
    }
    sb.writeln(_separator(w, '='));
    sb.writeln(_twoColumns('GRAND TOTAL:', 'Rs. ${invoice.grandTotal.toStringAsFixed(2)}', w));
    sb.writeln(_separator(w, '='));

    if (invoice.paidAmount > 0) {
      sb.writeln(_twoColumns('Paid via ${invoice.paymentStatus.toUpperCase()}:',
          'Rs. ${invoice.paidAmount.toStringAsFixed(2)}', w));
    }
    if (invoice.dueAmount > 0) {
      sb.writeln(_twoColumns('Balance Outstanding:', 'Rs. ${invoice.dueAmount.toStringAsFixed(2)}', w));
    }

    if (_settings.printDynamicQrOnReceipt) {
      final effectiveUpi = (upiId != null && upiId.isNotEmpty)
          ? upiId
          : (_settings.upiVpa.isNotEmpty ? _settings.upiVpa : '');
      if (effectiveUpi.isNotEmpty) {
        sb.writeln();
        sb.writeln(_center('[ SCAN & PAY VIA UPI QR ]', w));
        sb.writeln(_center(effectiveUpi, w));
        sb.writeln(_center('Amount: Rs. ${invoice.grandTotal.toStringAsFixed(2)}', w));
      }
    }

    sb.writeln();
    if (_settings.receiptFooterNote.isNotEmpty) {
      sb.writeln(_center(_settings.receiptFooterNote, w));
    }
    for (int i = 0; i < _settings.feedLinesBeforeCut; i++) {
      sb.writeln();
    }
    return sb.toString();
  }

  String formatOrderReceipt(OrderModel order, {ShopModel? shop, String? tenantFirm}) {
    final w = _settings.columnsCount;
    final sb = StringBuffer();
    final firm = tenantFirm ?? '';

    sb.writeln(_center('*** ORDER BOOKING SLIP ***', w));
    if (firm.isNotEmpty) sb.writeln(_center(firm.toUpperCase(), w));
    sb.writeln(_separator(w, '='));

    sb.writeln(_twoColumns('Order: ${order.orderId}', AppFormatters.date(order.placedAt), w));
    if (shop != null) {
      sb.writeln('Shop : ${shop.shopName}');
      sb.writeln('Owner: ${shop.ownerName} (${shop.phone})');
    }
    sb.writeln(_separator(w, '-'));

    for (final item in order.items) {
      final line = '${item.quantity}x ${item.productName}';
      final total = 'Rs. ${item.total.toStringAsFixed(1)}';
      sb.writeln(_twoColumns(line, total, w));
    }
    sb.writeln(_separator(w, '='));
    sb.writeln(_twoColumns('TOTAL ORDER VALUE:', 'Rs. ${order.grandTotal.toStringAsFixed(2)}', w));
    sb.writeln(_separator(w, '='));

    if (order.deliveryNote != null && order.deliveryNote!.isNotEmpty) {
      sb.writeln('Note: ${order.deliveryNote}');
    }
    for (int i = 0; i < _settings.feedLinesBeforeCut; i++) {
      sb.writeln();
    }
    return sb.toString();
  }

  String formatTestReceipt() {
    final w = _settings.columnsCount;
    final sb = StringBuffer();
    sb.writeln(_center('================================', w));
    sb.writeln(_center('*** PRINTER TEST ***', w));
    sb.writeln(_center('================================', w));
    sb.writeln(_twoColumns('Printer:', _settings.printerName.isNotEmpty ? _settings.printerName : 'Unnamed', w));
    sb.writeln(_twoColumns('Paper   :', _settings.paperSize, w));
    sb.writeln(_twoColumns('Timestamp:', AppFormatters.dateTime(DateTime.now()), w));
    sb.writeln(_separator(w, '-'));
    sb.writeln(_center('0123456789 ABCDEFGHIJKLMNOPQRSTUVWXYZ', w));
    sb.writeln(_separator(w, '='));
    for (int i = 0; i < _settings.feedLinesBeforeCut; i++) {
      sb.writeln();
    }
    return sb.toString();
  }

  String formatEstimateReceipt({
    required String quotationNumber,
    required String buyerName,
    required String buyerPhone,
    required List<Map<String, dynamic>> items,
    required double grandTotal,
    double discount = 0.0,
    String? notes,
  }) {
    final w = _settings.columnsCount;
    final sb = StringBuffer();

    if (_settings.receiptHeaderNote.isNotEmpty) {
      sb.writeln(_center(_settings.receiptHeaderNote, w));
    }
    sb.writeln(_center('*** ESTIMATED BILL ***', w));
    sb.writeln(_center('(ROUGH QUOTATION - NO TAX)', w));
    sb.writeln(_separator(w, '='));
    sb.writeln(_twoColumns('Est No:', quotationNumber, w));
    sb.writeln(_twoColumns('Date  :', AppFormatters.date(DateTime.now()), w));
    sb.writeln(_twoColumns('Buyer :', buyerName, w));
    if (buyerPhone.isNotEmpty) {
      sb.writeln(_twoColumns('Phone :', buyerPhone, w));
    }
    sb.writeln(_separator(w, '-'));

    sb.writeln(_twoColumns('ITEM x QTY @ RATE', 'AMOUNT', w));
    sb.writeln(_separator(w, '-'));

    for (final it in items) {
      final name = it['name']?.toString() ?? 'Item';
      final qty = it['quantity'] ?? 1;
      final rate = (it['rate'] is num) ? (it['rate'] as num).toDouble() : 0.0;
      final total = (it['total'] is num) ? (it['total'] as num).toDouble() : 0.0;
      sb.writeln(name);
      sb.writeln(_twoColumns('  ${qty}x @ Rs.${rate.toStringAsFixed(0)}', 'Rs.${total.toStringAsFixed(2)}', w));
    }

    sb.writeln(_separator(w, '-'));
    if (discount > 0) {
      sb.writeln(_twoColumns('Discount:', '-Rs.${discount.toStringAsFixed(2)}', w));
    }
    sb.writeln(_twoColumns('EST. TOTAL:', 'Rs.${grandTotal.toStringAsFixed(2)}', w));
    sb.writeln(_separator(w, '='));

    if (notes != null && notes.isNotEmpty) {
      sb.writeln('Remarks: $notes');
      sb.writeln(_separator(w, '-'));
    }
    if (_settings.receiptFooterNote.isNotEmpty) {
      sb.writeln(_center(_settings.receiptFooterNote, w));
    }
    for (int i = 0; i < _settings.feedLinesBeforeCut; i++) {
      sb.writeln();
    }
    return sb.toString();
  }

  // ---------------------------------------------------------------------------
  // Real print execution
  // ---------------------------------------------------------------------------

  /// Sends the given text buffer to the connected printer the configured
  /// number of times (`copiesCount`). Returns true if every copy succeeded.
  Future<bool> _sendToPrinter(String body, {int? copiesOverride}) async {
    final copies = copiesOverride ?? _settings.copiesCount;
    try {
      for (int i = 0; i < copies; i++) {
        // `printCustom` renders the body on the printer. Size 1 = normal.
        await _bt.printCustom(body, 1, 0);
        await _bt.printNewLine();
        await _bt.printNewLine();
        await _bt.printNewLine();
      }
      return true;
    } catch (e) {
      debugPrint('PrinterService send error: $e');
      return false;
    }
  }

  BuildContext? _activePrintingDialogContext;
  Timer? _dialogSafetyTimer;

  void _dismissActivePrintingDialog() {
    _dialogSafetyTimer?.cancel();
    _dialogSafetyTimer = null;
    final ctx = _activePrintingDialogContext;
    _activePrintingDialogContext = null;
    if (ctx != null && ctx.mounted && Navigator.canPop(ctx)) {
      Navigator.pop(ctx);
    }
  }

  Future<bool> printInvoice(
    InvoiceModel invoice, {
    BuildContext? context,
    int? copiesOverride,
    bool showFeedback = true,
    String? tenantFirm,
    String? tenantGstin,
    String? tenantAddress,
    String? tenantPhone,
    String? upiId,
  }) async {
    if (!_settings.isEnabled) {
      if (context != null && showFeedback) _showNotConnectedSnackBar(context);
      return false;
    }
    if (!await _ensureConnected(context)) return false;

    final copies = copiesOverride ?? _settings.copiesCount;
    if (context != null && showFeedback) {
      _showPrintingDialog(context, 'Printing Invoice ${invoice.invoiceNumber}', copies);
    }

    _isPrinting = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    final body = formatInvoiceReceipt(
      invoice,
      tenantFirm: tenantFirm,
      tenantGstin: tenantGstin,
      tenantAddress: tenantAddress,
      tenantPhone: tenantPhone,
      upiId: upiId,
    );
    final ok = await _sendToPrinter(body, copiesOverride: copies);

    _isPrinting = false;
    notifyListeners();
    _dismissActivePrintingDialog();

    if (ok && _settings.beepBuzzer) SystemSound.play(SystemSoundType.click);
    if (context != null && context.mounted && showFeedback) {
      _showResultSnack(context, ok,
          'Printed $copies copy(s) of ${invoice.invoiceNumber}.');
    }
    return ok;
  }

  Future<bool> printOrder(
    OrderModel order, {
    ShopModel? shop,
    BuildContext? context,
    int? copiesOverride,
    String? tenantFirm,
  }) async {
    if (!_settings.isEnabled) {
      if (context != null) _showNotConnectedSnackBar(context);
      return false;
    }
    if (!await _ensureConnected(context)) return false;

    final copies = copiesOverride ?? _settings.copiesCount;
    if (context != null) {
      _showPrintingDialog(context, 'Printing Order ${order.orderId}', copies);
    }

    _isPrinting = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    final body = formatOrderReceipt(order, shop: shop, tenantFirm: tenantFirm);
    final ok = await _sendToPrinter(body, copiesOverride: copies);

    _isPrinting = false;
    notifyListeners();
    _dismissActivePrintingDialog();

    if (ok && _settings.beepBuzzer) SystemSound.play(SystemSoundType.click);
    if (context != null && context.mounted) {
      _showResultSnack(context, ok, 'Order ${order.orderId} sent to printer.');
    }
    return ok;
  }

  Future<bool> printEstimateReceipt({
    required String quotationNumber,
    required String buyerName,
    required String buyerPhone,
    required List<Map<String, dynamic>> items,
    required double grandTotal,
    double discount = 0.0,
    String? notes,
    BuildContext? context,
  }) async {
    if (!_settings.isEnabled) {
      if (context != null) _showNotConnectedSnackBar(context);
      return false;
    }
    if (!await _ensureConnected(context)) return false;

    final copies = _settings.copiesCount;
    if (context != null) {
      _showPrintingDialog(context, 'Printing Estimate $quotationNumber', copies);
    }

    _isPrinting = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    final body = formatEstimateReceipt(
      quotationNumber: quotationNumber,
      buyerName: buyerName,
      buyerPhone: buyerPhone,
      items: items,
      grandTotal: grandTotal,
      discount: discount,
      notes: notes,
    );
    final ok = await _sendToPrinter(body, copiesOverride: copies);

    _isPrinting = false;
    notifyListeners();
    _dismissActivePrintingDialog();

    if (ok && _settings.beepBuzzer) SystemSound.play(SystemSoundType.click);
    if (context != null && context.mounted) {
      _showResultSnack(context, ok, 'Estimate $quotationNumber sent to printer.');
    }
    return ok;
  }

  /// Prints a payment (collection) receipt on the connected thermal printer.
  Future<bool> printPaymentReceipt({
    required String firmName,
    required String paymentId,
    required String shopName,
    required DateTime date,
    required String paymentMode,
    String? reference,
    required double amount,
    required double remainingBalance,
    BuildContext? context,
  }) async {
    if (!_settings.isEnabled) {
      if (context != null) _showNotConnectedSnackBar(context);
      return false;
    }
    if (!await _ensureConnected(context)) return false;

    final w = _settings.columnsCount;
    final sb = StringBuffer();
    if (_settings.receiptHeaderNote.isNotEmpty) sb.writeln(_center(_settings.receiptHeaderNote, w));
    sb.writeln(_center(firmName.toUpperCase(), w));
    sb.writeln(_center('*** PAYMENT RECEIPT ***', w));
    sb.writeln(_separator(w, '='));
    sb.writeln(_twoColumns('Receipt:', paymentId, w));
    sb.writeln(_twoColumns('Date   :', AppFormatters.dateTime(date), w));
    sb.writeln(_twoColumns('Party  :', shopName, w));
    sb.writeln(_twoColumns('Mode   :', paymentMode, w));
    if (reference != null && reference.isNotEmpty) sb.writeln(_twoColumns('Ref    :', reference, w));
    sb.writeln(_separator(w, '-'));
    sb.writeln(_twoColumns('RECEIVED', 'Rs.${amount.toStringAsFixed(2)}', w));
    sb.writeln(_twoColumns('Balance due', 'Rs.${remainingBalance.toStringAsFixed(2)}', w));
    sb.writeln(_separator(w, '='));
    sb.writeln(_center('Thank you!', w));

    _isPrinting = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    final ok = await _sendToPrinter(sb.toString(), copiesOverride: 1);
    _isPrinting = false;
    notifyListeners();

    if (ok && _settings.beepBuzzer) SystemSound.play(SystemSoundType.click);
    if (context != null && context.mounted) {
      _showResultSnack(context, ok, 'Receipt $paymentId sent to printer.');
    }
    return ok;
  }

  Future<bool> printTestReceipt({BuildContext? context}) async {
    if (!_settings.isEnabled) {
      if (context != null) _showNotConnectedSnackBar(context);
      return false;
    }
    if (!await _ensureConnected(context)) return false;

    if (context != null) _showPrintingDialog(context, 'Printing test slip', 1);

    _isPrinting = true;
    notifyListeners();
    HapticFeedback.mediumImpact();
    final ok = await _sendToPrinter(formatTestReceipt(), copiesOverride: 1);

    _isPrinting = false;
    notifyListeners();
    _dismissActivePrintingDialog();

    if (ok && _settings.beepBuzzer) SystemSound.play(SystemSoundType.click);
    if (context != null && context.mounted) {
      _showResultSnack(context, ok,
          'Test slip ${ok ? "printed" : "failed"} on ${_settings.printerName.isNotEmpty ? _settings.printerName : "printer"}.');
    }
    return ok;
  }

  // ---------------------------------------------------------------------------
  // UI feedback helpers
  // ---------------------------------------------------------------------------

  void _showResultSnack(BuildContext context, bool success, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(success ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(success ? message : 'Could not print — $message')),
          ],
        ),
        backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showNotConnectedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.print_disabled_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Expanded(child: Text('No printer connected.')),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'SETTINGS',
          textColor: Colors.white,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
          ),
        ),
      ),
    );
  }

  void _showPrintingDialog(BuildContext context, String title, int copies) {
    _dismissActivePrintingDialog();
    _dialogSafetyTimer = Timer(const Duration(seconds: 15), _dismissActivePrintingDialog);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        _activePrintingDialogContext = ctx;
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E3A8A),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF60A5FA)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sending $copies cop${copies == 1 ? "y" : "ies"} to ${_settings.printerName.isNotEmpty ? _settings.printerName : "printer"}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      _activePrintingDialogContext = null;
      _dialogSafetyTimer?.cancel();
      _dialogSafetyTimer = null;
    });
  }
}
