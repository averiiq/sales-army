import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/settings/presentation/dialogs/hardware_settings_modal.dart';
import 'package:salesarmy/features/settings/presentation/screens/printer_settings_screen.dart';

class HardwareSettingsScreen extends StatelessWidget {
  final int initialTab;
  final bool isPrinterOnly;

  const HardwareSettingsScreen({
    super.key,
    this.initialTab = 0,
    this.isPrinterOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrinterOnly) {
      return const PrinterSettingsScreen();
    }
    final isDark = context.watch<AppState>().isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Hardware & POS Printers',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: HardwareSettingsModal(
            initialTab: initialTab,
            isPrinterOnly: isPrinterOnly,
          ),
        ),
      ),
    );
  }
}
