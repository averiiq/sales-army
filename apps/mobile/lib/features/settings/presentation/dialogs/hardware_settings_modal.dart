import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/settings/presentation/screens/payment_preferences_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/printer_settings_screen.dart';

/// Hardware & payment configuration launcher.
///
/// The previous 2,400-line implementation of this dialog embedded a mock
/// dashboard — fake printer battery levels, "ESC/POS 203 DPI Head Active"
/// headlines, pretend WiFi scans, hardcoded soundbox devices. All of that was
/// decoration layered over the two settings surfaces that actually matter:
/// Payment Preferences (UPI VPA / QR / gateway credentials) and Thermal
/// Printer. This wrapper simply routes to those two real screens.
///
/// Public API kept intact so existing callers still work:
///  - `HardwareSettingsModal(isPrinterOnly: true)` → PrinterSettingsScreen
///  - `HardwareSettingsModal(isPaymentPreferencesOnly: true)` → PaymentPreferencesScreen
///  - Default: a tiny landing card with two buttons.
class HardwareSettingsModal extends StatelessWidget {
  final int initialTab; // kept for API compatibility, no longer used
  final bool isPrinterOnly;
  final bool isPaymentPreferencesOnly;

  const HardwareSettingsModal({
    super.key,
    this.initialTab = 0,
    this.isPrinterOnly = false,
    this.isPaymentPreferencesOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrinterOnly) return const PrinterSettingsScreen();
    if (isPaymentPreferencesOnly) return const PaymentPreferencesScreen();
    return const _HardwareSettingsLanding();
  }
}

class _HardwareSettingsLanding extends StatelessWidget {
  const _HardwareSettingsLanding();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderCol = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.settings_input_component_rounded,
                      color: Color(0xFF1E56E2)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hardware & Payment',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: textMain)),
                      const SizedBox(height: 2),
                      Text('Pick the surface you want to configure',
                          style: TextStyle(fontSize: 12, color: textSub)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: textSub),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _choiceTile(
              context: context,
              icon: Icons.payments_rounded,
              iconColor: const Color(0xFF059669),
              title: 'Payment preferences',
              subtitle: 'UPI VPA, QR source, gateway credentials',
              cardBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              textMain: textMain,
              textSub: textSub,
              borderCol: borderCol,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentPreferencesScreen()),
                );
              },
            ),
            const SizedBox(height: 10),
            _choiceTile(
              context: context,
              icon: Icons.print_rounded,
              iconColor: const Color(0xFF1E56E2),
              title: 'Thermal printer',
              subtitle: 'Pair device, paper width, auto-print, test slip',
              cardBg: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              textMain: textMain,
              textSub: textSub,
              borderCol: borderCol,
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color cardBg,
    required Color textMain,
    required Color textSub,
    required Color borderCol,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderCol),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: textMain)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 11.5, color: textSub)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textSub),
            ],
          ),
        ),
      ),
    );
  }
}
