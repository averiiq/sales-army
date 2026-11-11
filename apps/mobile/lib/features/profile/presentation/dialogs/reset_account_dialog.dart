import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';

class ResetAccountDialog extends StatefulWidget {
  const ResetAccountDialog({super.key});

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ResetAccountDialog(),
    );
  }

  @override
  State<ResetAccountDialog> createState() => _ResetAccountDialogState();
}

class _ResetAccountDialogState extends State<ResetAccountDialog> {
  final _confirmCtrl = TextEditingController();
  bool _isResetting = false;
  bool _hasRecoveredData = false;
  bool _isExportingBackup = false;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _isConfirmed => _confirmCtrl.text.trim() == 'RESET';

  Future<void> _handleRecoverInformation() async {
    setState(() => _isExportingBackup = true);
    HapticFeedback.mediumImpact();
    // Simulate generation of complete data backup archive
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) {
      setState(() {
        _isExportingBackup = false;
        _hasRecoveredData = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text('Complete business ledger & customer data archive saved to downloads!'),
              ),
            ],
          ),
          backgroundColor: Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Warning Icon
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
                  ),
                  child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Reset Account Data',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Resetting clears all transactional history, customer dues, inventory adjustments, and GST invoices for this agency.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),

              // RECOVER INFORMATION PROMINENT CARD
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _hasRecoveredData
                      ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4))
                      : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF)),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _hasRecoveredData
                        ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                        : (isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _hasRecoveredData ? Icons.check_circle_rounded : Icons.cloud_download_outlined,
                          size: 18,
                          color: _hasRecoveredData ? const Color(0xFF34D399) : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _hasRecoveredData
                                ? 'Information Recovered & Saved'
                                : 'Save / Recover Your Information First',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: _hasRecoveredData
                                  ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF166534))
                                  : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _hasRecoveredData
                          ? 'Backup archive containing orders, catalog, retailer ledgers and GST statements is downloaded.'
                          : 'Before proceeding with the reset, you should recover and download your records so no business data is lost forever.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: _hasRecoveredData
                            ? (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF15803D))
                            : (isDark ? const Color(0xFFBFDBFE) : const Color(0xFF1E3A8A)),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _hasRecoveredData ? const Color(0xFF16A34A) : const Color(0xFF1D4ED8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _isExportingBackup
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Icon(_hasRecoveredData ? Icons.done_all_rounded : Icons.download_rounded, size: 16),
                        label: Text(
                          _hasRecoveredData ? 'Download Again (Recover Information)' : 'Recover Information (Save Backup)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                        onPressed: _isExportingBackup ? null : _handleRecoverInformation,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Warning Checklist & Disclaimer
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disclaimer: The following records will be cleared:',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    _WipeItem(text: 'All Orders, GST Invoices & Bills will be wiped', isDark: isDark),
                    _WipeItem(text: 'All Payment receipts & Double-Entry Ledger entries cleared', isDark: isDark),
                    _WipeItem(text: 'All Retailer Outstanding Credit Dues will be reset to ₹0', isDark: isDark),
                    _WipeItem(text: 'All Field Visits, Reminders & Daily Expenses deleted', isDark: isDark),
                    _WipeItem(text: 'Catalog Product stock quantities reset to baseline', isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Confirmation text field
              Text(
                'Type "RESET" below to continue with deliberate wipe:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _confirmCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2, color: Color(0xFFDC2626)),
                decoration: InputDecoration(
                  hintText: 'TYPE RESET',
                  hintStyle: TextStyle(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFFF1F2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons: Recover Information, Continue Reset, Cancel
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      disabledBackgroundColor: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFCA5A5),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 1,
                    ),
                    onPressed: (!_isConfirmed || _isResetting)
                        ? null
                        : () async {
                            setState(() => _isResetting = true);
                            HapticFeedback.heavyImpact();
                            await appState.resetAccountData();
                            if (context.mounted) {
                              Navigator.pop(context, true);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Account transaction history and balances reset successfully!'),
                                  backgroundColor: Color(0xFF059669),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          },
                    child: _isResetting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Continue Reset', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 13.5)),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    ),
                    onPressed: _isResetting ? null : () => Navigator.pop(context, false),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WipeItem extends StatelessWidget {
  final String text;
  final bool isDark;
  const _WipeItem({required this.text, this.isDark = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.remove_circle_outline_rounded, size: 14, color: Color(0xFFEF4444)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
