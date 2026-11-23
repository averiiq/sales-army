import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/settings/data/models/printer_settings_model.dart';

/// Minimal thermal-printer configuration screen. Only options that drive the
/// real print pipeline survive here — the earlier mock dashboard (fake
/// battery, RSSI, protocol selector, WiFi/USB tabs, print darkness, auto-cut
/// paper toggle, FSSAI toggle, 5 hardcoded "Nearby Printers") has been
/// deleted. Pair the printer in Android Settings → Bluetooth once, then come
/// back here to connect & test.
class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  late TextEditingController _headerCtrl;
  late TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final s = PrinterService.instance.settings;
    _headerCtrl = TextEditingController(text: s.receiptHeaderNote);
    _footerCtrl = TextEditingController(text: s.receiptFooterNote);
    // Refresh paired devices list once when the screen opens. Wrapped in a
    // try/catch because the Bluetooth plugin may raise a MissingPluginException
    // on first launch after the dependency was added — we don't want that
    // crashing the whole settings page.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await PrinterService.instance.scanBluetoothDevices();
      } catch (_) {
        // Scan failed — status card will show "No paired devices". User can
        // tap Scan to retry once Bluetooth is ready / permissions granted.
      }
    });
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(PrinterSettingsModel next) async {
    await PrinterService.instance.saveSettings(next);
  }

  Future<void> _onScan() async {
    HapticFeedback.selectionClick();
    final devices = await PrinterService.instance.scanBluetoothDevices();
    if (!mounted) return;
    if (devices.isEmpty) {
      showAppError(context, 'No paired Bluetooth printers found. Pair the printer in Android Settings → Bluetooth first, then try again.');
    }
  }

  Future<void> _onConnect(PrinterDevice device) async {
    HapticFeedback.mediumImpact();
    final ok = await PrinterService.instance.selectPrinterDevice(device);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Connected to ${device.name}.'
            : 'Could not connect to ${device.name}. Make sure the printer is powered on.'),
        backgroundColor: ok ? const Color(0xFF059669) : const Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _onDisconnect() async {
    await PrinterService.instance.disconnect();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Disconnected.')),
    );
  }

  Future<void> _onTestPrint() async {
    await PrinterService.instance.printTestReceipt(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    // PrinterService is a singleton ChangeNotifier that is NOT registered in
    // the top-level MultiProvider — using `context.watch<PrinterService>()`
    // would throw `ProviderNotFoundException` and render a grey screen.
    // Subscribing to the raw Listenable keeps the rebuild wiring without
    // forcing an app-wide provider refactor.
    return ListenableBuilder(
      listenable: PrinterService.instance,
      builder: (context, _) {
        final service = PrinterService.instance;
        final s = service.settings;
        return _buildBody(context, isDark, service, s);
      },
    );
  }

  Widget _buildBody(BuildContext context, bool isDark, PrinterService service, PrinterSettingsModel s) {
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: cardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text('Thermal Printer',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: textMain)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: textMain),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderCol),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Status card
          _statusCard(s, cardBg, textMain, textSub, borderCol),
          const SizedBox(height: 16),

          // Paired devices
          _sectionLabel('Paired Bluetooth printers', textMain),
          const SizedBox(height: 8),
          _pairedDevicesCard(service, s, cardBg, textMain, textSub, borderCol),
          const SizedBox(height: 20),

          // Receipt options
          _sectionLabel('Receipt options', textMain),
          const SizedBox(height: 8),
          _optionsCard(s, cardBg, textMain, textSub, borderCol),
          const SizedBox(height: 20),

          // Header / footer notes
          _sectionLabel('Receipt text', textMain),
          const SizedBox(height: 8),
          _textNotesCard(s, cardBg, textMain, textSub, borderCol),
          const SizedBox(height: 24),

          // Test print button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: s.isEnabled && s.isConnected ? _onTestPrint : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E56E2),
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                disabledForegroundColor: textSub,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.print_rounded, size: 20),
              label: const Text('Print test slip',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, Color color) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(text,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color, letterSpacing: 0.3)),
      );

  Widget _statusCard(PrinterSettingsModel s, Color cardBg, Color textMain, Color textSub, Color borderCol) {
    final connected = s.isConnected;
    final hasPrinter = s.printerName.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: connected ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              connected ? Icons.print_rounded : Icons.print_disabled_rounded,
              color: connected ? const Color(0xFF059669) : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  connected ? 'Connected' : (hasPrinter ? 'Not connected' : 'No printer selected'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: textMain),
                ),
                const SizedBox(height: 2),
                Text(
                  hasPrinter ? s.printerName : 'Tap a paired device below to connect',
                  style: TextStyle(fontSize: 12, color: textSub),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: s.isEnabled,
            activeThumbColor: const Color(0xFF1E56E2),
            onChanged: (val) {
              _save(s.copyWith(isEnabled: val));
            },
          ),
        ],
      ),
    );
  }

  Widget _pairedDevicesCard(
      PrinterService service, PrinterSettingsModel s, Color cardBg, Color textMain, Color textSub, Color borderCol) {
    final devices = service.nearbyPrinters;
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    service.isScanning
                        ? 'Scanning…'
                        : (devices.isEmpty ? 'No paired devices' : '${devices.length} device${devices.length == 1 ? "" : "s"} paired'),
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: textSub),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: service.isScanning ? null : _onScan,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E56E2),
                    side: const BorderSide(color: Color(0xFF1E56E2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: service.isScanning
                      ? const SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Scan',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: borderCol),
          if (devices.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.bluetooth_disabled_rounded, color: textSub, size: 32),
                  const SizedBox(height: 8),
                  Text(
                    'Pair your thermal printer in Android Settings → Bluetooth,\nthen tap Scan.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: textSub),
                  ),
                ],
              ),
            )
          else
            ...devices.map((d) {
              final selected = d.address == s.printerMac;
              final activelyConnected = selected && s.isConnected;
              return Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderCol)),
                ),
                child: ListTile(
                  leading: Icon(Icons.print_rounded,
                      color: activelyConnected ? const Color(0xFF059669) : textSub),
                  title: Text(d.name,
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textMain)),
                  subtitle: Text(d.address,
                      style: TextStyle(fontSize: 11, color: textSub, letterSpacing: 0.3)),
                  trailing: activelyConnected
                      ? TextButton(
                          onPressed: _onDisconnect,
                          child: const Text('Disconnect',
                              style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.w800)),
                        )
                      : ElevatedButton(
                          onPressed: () => _onConnect(d),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E56E2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Connect',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                        ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _optionsCard(
      PrinterSettingsModel s, Color cardBg, Color textMain, Color textSub, Color borderCol) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        children: [
          _dropdownRow(
            label: 'Paper width',
            value: s.paperSize,
            options: const ['58mm', '80mm'],
            onChanged: (v) => _save(s.copyWith(paperSize: v)),
            textMain: textMain,
            textSub: textSub,
          ),
          Divider(height: 1, color: borderCol, indent: 16, endIndent: 16),
          _dropdownRow(
            label: 'Copies per receipt',
            value: s.printCopies,
            options: const ['1 Copy', '2 Copies', '3 Copies'],
            onChanged: (v) => _save(s.copyWith(printCopies: v)),
            textMain: textMain,
            textSub: textSub,
          ),
          Divider(height: 1, color: borderCol, indent: 16, endIndent: 16),
          _switchRow(
            label: 'Print agency address + phone',
            value: s.printAgencyAddress,
            onChanged: (v) => _save(s.copyWith(printAgencyAddress: v)),
            textMain: textMain,
          ),
          Divider(height: 1, color: borderCol, indent: 16, endIndent: 16),
          _switchRow(
            label: 'Print GSTIN on receipt',
            value: s.printGstin,
            onChanged: (v) => _save(s.copyWith(printGstin: v)),
            textMain: textMain,
          ),
          Divider(height: 1, color: borderCol, indent: 16, endIndent: 16),
          _switchRow(
            label: 'Include UPI VPA for Scan & Pay',
            value: s.printDynamicQrOnReceipt,
            onChanged: (v) => _save(s.copyWith(printDynamicQrOnReceipt: v)),
            textMain: textMain,
          ),
          Divider(height: 1, color: borderCol, indent: 16, endIndent: 16),
          _switchRow(
            label: 'Auto-print after billing an order',
            value: s.autoPrintOnBill,
            onChanged: (v) => _save(s.copyWith(autoPrintOnBill: v)),
            textMain: textMain,
          ),
          Divider(height: 1, color: borderCol, indent: 16, endIndent: 16),
          _switchRow(
            label: 'Sound buzzer on success',
            value: s.beepBuzzer,
            onChanged: (v) => _save(s.copyWith(beepBuzzer: v)),
            textMain: textMain,
          ),
        ],
      ),
    );
  }

  Widget _textNotesCard(
      PrinterSettingsModel s, Color cardBg, Color textMain, Color textSub, Color borderCol) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderCol),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Receipt header', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSub)),
          const SizedBox(height: 6),
          TextField(
            controller: _headerCtrl,
            style: TextStyle(fontSize: 13, color: textMain),
            decoration: const InputDecoration(
              hintText: 'TAX INVOICE / CASH MEMO',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            maxLength: 40,
            onChanged: (val) => _save(s.copyWith(receiptHeaderNote: val)),
          ),
          const SizedBox(height: 10),
          Text('Receipt footer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSub)),
          const SizedBox(height: 6),
          TextField(
            controller: _footerCtrl,
            style: TextStyle(fontSize: 13, color: textMain),
            decoration: const InputDecoration(
              hintText: 'Thank you for your business.',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
            maxLength: 80,
            onChanged: (val) => _save(s.copyWith(receiptFooterNote: val)),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow({
    required String label,
    required String value,
    required List<String> options,
    required ValueChanged<String> onChanged,
    required Color textMain,
    required Color textSub,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
          ),
          DropdownButton<String>(
            value: options.contains(value) ? value : options.first,
            underline: const SizedBox(),
            items: options
                .map((o) => DropdownMenuItem(value: o, child: Text(o, style: TextStyle(color: textMain))))
                .toList(),
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ],
      ),
    );
  }

  Widget _switchRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color textMain,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: textMain)),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: const Color(0xFF1E56E2),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
