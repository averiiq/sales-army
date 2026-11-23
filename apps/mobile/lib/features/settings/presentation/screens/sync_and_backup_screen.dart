import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/formatters.dart';

class SyncAndBackupScreen extends StatefulWidget {
  const SyncAndBackupScreen({super.key});

  @override
  State<SyncAndBackupScreen> createState() => _SyncAndBackupScreenState();
}

class _SyncAndBackupScreenState extends State<SyncAndBackupScreen> {
  bool _isSyncing = false;

  void _triggerManualBatchSync(AppState appState) async {
    setState(() => _isSyncing = true);
    HapticFeedback.mediumImpact();

    try {
      final count = await appState.executeBatchSync();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Batch Sync Completed! Synced $count pending records to cloud database.'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showAppError(context, e, action: 'sync your data');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _confirmClearSyncedLocalCache(BuildContext context, AppState appState) {
    if (appState.outboxManager.pendingCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot clear storage: You have unsynced pending offline records. Sync to cloud first!'),
          backgroundColor: Color(0xFFD97706),
        ),
      );
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: Color(0xFFD97706), size: 22),
            const SizedBox(width: 8),
            Text(
              'Clear Synced Mobile Cache',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'All your latest records are completely synced and backed up on the cloud database.\n\nBy confirming, the local synced cache on this mobile device will be pruned to free up memory storage. Data in the server will remain untouched.\n\nDo you give permission to proceed?',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.clearSyncedMobileStorage();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Local synced cache successfully cleared with user permission!'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              }
            },
            child: const Text('Confirm & Free Storage', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final pendingCount = appState.outboxManager.pendingCount;
    final isFullySynced = pendingCount == 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final lastSyncStr = appState.lastBatchSyncTime != null
        ? AppFormatters.dateTime(appState.lastBatchSyncTime!)
        : 'Automated 12:00 PM Batch Synced';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Offline Storage & Cloud Sync',
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Sync Health Status Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isFullySynced
                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5))
                              : (isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB)),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isFullySynced ? Icons.cloud_done_rounded : Icons.cloud_sync_rounded,
                          color: isFullySynced ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isFullySynced ? 'Database 100% Synced' : '$pendingCount Records Stored Locally',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              isFullySynced
                                  ? 'All mobile orders, invoices & bills are in sync.'
                                  : 'Pending upload when connected to the internet.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Last Server Sync',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      Text(
                        lastSyncStr,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isSyncing ? null : () => _triggerManualBatchSync(appState),
                      icon: _isSyncing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        _isSyncing ? 'Syncing In Batches...' : 'Force Batch Sync Now',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Scheduled Batch Sync Windows (12:00 PM & 10:00 PM)
            const Text(
              'AUTOMATED BATCH SYNC SCHEDULE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _batchTimeRow(
                    time: '12:00 PM (Mid-day Sync)',
                    desc: 'Uploads morning route orders, shop visits & sales returns in batch.',
                    icon: Icons.wb_sunny_rounded,
                    color: const Color(0xFFD97706),
                    isDark: isDark,
                  ),
                  Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  _batchTimeRow(
                    time: '10:00 PM (Night Beat Closing)',
                    desc: 'Final end-of-day batch upload for cash collections, expenses & ledger totals.',
                    icon: Icons.nights_stay_rounded,
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 3. Mobile Data Vault & User Permission Deletion Policy
            const Text(
              'LOCAL STORAGE RETENTION POLICY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.8),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Data Cannot Be Deleted Automatically',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'When offline in remote market areas, all bills and orders are saved securely in mobile storage. Even after synchronization to the database, mobile data is never deleted automatically—it stays safely on your phone until you give explicit permission.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isDark ? const Color(0xFFBBF7D0) : const Color(0xFF15803D),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD97706),
                      side: BorderSide(color: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A)),
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _confirmClearSyncedLocalCache(context, appState),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: const Text(
                      'Clear Synced Storage from Mobile (Requires Permission)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _batchTimeRow({
    required String time,
    required String desc,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.2 : 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 11.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
