// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:share_plus/share_plus.dart';

class BackupManagerModal extends StatefulWidget {
  const BackupManagerModal({super.key});

  @override
  State<BackupManagerModal> createState() => _BackupManagerModalState();
}

class _BackupManagerModalState extends State<BackupManagerModal> {
  bool _isExporting = false;
  String? _lastExportPreview;

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  void _downloadBackup(AppState appState) async {
    setState(() => _isExporting = true);
    HapticFeedback.mediumImpact();

    final jsonString = appState.triggerCompleteDataBackup();
    await Clipboard.setData(ClipboardData(text: jsonString));

    File? backupFile;
    final fileName = 'salesarmy_backup_${DateTime.now().millisecondsSinceEpoch}.json';
    try {
      final tempDir = await getTemporaryDirectory();
      backupFile = File('${tempDir.path}/$fileName');
      await backupFile.writeAsString(jsonString, flush: true);
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _isExporting = false;
      _lastExportPreview = jsonString.length > 300 ? '${jsonString.substring(0, 300)}...\n}' : jsonString;
    });

    if (backupFile != null) {
      try {
        await Share.shareXFiles(
          [XFile(backupFile.path, name: fileName, mimeType: 'application/json')],
          subject: 'SalesArmy Complete Data Backup',
          text: 'SalesArmy complete structured backup ($fileName)',
        );
      } catch (_) {
        await Share.share(jsonString, subject: 'SalesArmy Backup');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Backup file exported & copied to clipboard! Ready to save or share.',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDue = appState.isBackupDue;
    final lastBackupText = _formatDate(appState.lastBackupDate);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      backgroundColor: Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540, maxHeight: 760),
        child: Column(
          children: [
            // Header
            _buildHeader(context),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Status Alert Banner
                    _buildStatusBanner(isDue, lastBackupText, appState.backupFrequency),
                    const SizedBox(height: 16),

                    // Backup Scope Metrics
                    _buildScopeSection(appState),
                    const SizedBox(height: 20),

                    // Schedule Configuration
                    _buildScheduleSection(appState),
                    const SizedBox(height: 20),

                    // Auto-Save to Device Toggle
                    _buildDeviceAutoSaveCard(appState),
                    const SizedBox(height: 16),

                    // Data Preview (if exported)
                    if (_lastExportPreview != null) ...[
                      _buildPreviewCard(_lastExportPreview!),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),

            // Sticky Footer Action Bar
            _buildFooter(appState),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 16, 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Data Backup & Sync',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sell orders, bills, complete ledger & inventory',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(bool isDue, String lastBackupText, String frequency) {
    final freqTitle = frequency == 'weekly'
        ? 'Weekly'
        : frequency == 'monthly'
            ? 'Monthly'
            : 'Manual Only';

    if (isDue) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backup Download Due',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Your $freqTitle scheduled backup is ready. Last backup: $lastBackupText.',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFB45309)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Backup Up-to-Date',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF065F46),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Last backup created: $lastBackupText ($freqTitle Schedule)',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeSection(AppState appState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'BACKUP DATA COVERAGE',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF64748B),
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Full Enterprise JSON',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0284C7),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          children: [
            _buildStatCard('Sell Orders', appState.orders.length.toString(), Icons.receipt_long_rounded, const Color(0xFF3B82F6)),
            _buildStatCard('GST Bills', appState.invoices.length.toString(), Icons.request_quote_rounded, const Color(0xFF10B981)),
            _buildStatCard('Khata Ledger', appState.ledgerEntries.length.toString(), Icons.menu_book_rounded, const Color(0xFF8B5CF6)),
            _buildStatCard('Sell Accounts', appState.shops.length.toString(), Icons.storefront_rounded, const Color(0xFFF59E0B)),
            _buildStatCard('Inventory SKUs', appState.products.length.toString(), Icons.inventory_2_rounded, const Color(0xFF06B6D4)),
            _buildStatCard('Collections', appState.payments.length.toString(), Icons.payments_rounded, const Color(0xFFEC4899)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String count, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const Spacer(),
              Text(
                count,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.update_rounded, size: 18, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Text(
                'Auto-Backup & Reminder Frequency',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose how frequently the app should alert you to download or automatically update device backup files.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          _buildFrequencyOption(
            title: 'Weekly (Every 7 Days)',
            subtitle: 'Recommended for active distribution & daily billing',
            value: 'weekly',
            groupValue: appState.backupFrequency,
            onChanged: (val) => appState.setBackupFrequency(val!),
            badge: 'RECOMMENDED',
          ),
          const SizedBox(height: 8),
          _buildFrequencyOption(
            title: 'Monthly (Every 30 Days)',
            subtitle: 'Best for standard monthly reconciliation audits',
            value: 'monthly',
            groupValue: appState.backupFrequency,
            onChanged: (val) => appState.setBackupFrequency(val!),
          ),
          const SizedBox(height: 8),
          _buildFrequencyOption(
            title: 'Manual Only (Turn Off Reminders)',
            subtitle: 'Backup is only exported when manually triggered',
            value: 'off',
            groupValue: appState.backupFrequency,
            onChanged: (val) => appState.setBackupFrequency(val!),
          ),
        ],
      ),
    );
  }

  Widget _buildFrequencyOption({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
    String? badge,
  }) {
    final isSelected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF0F9FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF0284C7) : const Color(0xFFCBD5E1),
                  width: isSelected ? 6 : 2,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isSelected ? const Color(0xFF0369A1) : const Color(0xFF0F172A),
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceAutoSaveCard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.phone_android_rounded, color: Color(0xFF0284C7), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Auto-Save to Phone Storage',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 2),
                Text(
                  'Maintains an offline local copy automatically refreshed on schedule.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Switch(
            value: appState.autoSaveToDevice,
            activeThumbColor: const Color(0xFF0284C7),
            onChanged: (val) => appState.setAutoSaveToDevice(val),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(String previewText) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.terminal_rounded, color: Color(0xFF38BDF8), size: 16),
              SizedBox(width: 6),
              Text(
                'EXPORT PAYLOAD PREVIEW',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            previewText,
            style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 11, fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(AppState appState) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : () => _downloadBackup(appState),
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.download_rounded, size: 20),
              label: Text(
                _isExporting ? 'Generating Backup...' : 'Download Complete Backup Now',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
