import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';

class AdminSettingsTab extends StatefulWidget {
  final bool maintenanceMode;
  final ValueChanged<bool> onToggleMaintenance;
  final bool autoBackupEnabled;
  final ValueChanged<bool> onToggleAutoBackup;
  final String backupFrequency;
  final TextEditingController adminPasscodeCtrl;
  final TextEditingController minAppVersionCtrl;
  final VoidCallback onOpenDownloadReports;
  final VoidCallback? onSignOut;

  const AdminSettingsTab({
    super.key,
    required this.maintenanceMode,
    required this.onToggleMaintenance,
    required this.autoBackupEnabled,
    required this.onToggleAutoBackup,
    required this.backupFrequency,
    required this.adminPasscodeCtrl,
    required this.minAppVersionCtrl,
    required this.onOpenDownloadReports,
    this.onSignOut,
  });

  @override
  State<AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<AdminSettingsTab> {
  bool _isBackingUp = false;

  void _triggerInstantBackup() async {
    setState(() => _isBackingUp = true);
    try {
      await context.read<AppState>().triggerInstantBackup();
    } catch (error) {
      if (mounted) {
        setState(() => _isBackingUp = false);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $error')));
      }
      return;
    }
    if (mounted) {
      setState(() => _isBackingUp = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database snapshot saved and verified on the platform server.'),
          backgroundColor: Color(0xFF059669),
        ),
      );
    }
  }

  void _saveSecuritySettings() async {
    try {
      await context.read<AppState>().updateAdminSecuritySettings(
        passcode: widget.adminPasscodeCtrl.text.trim(),
        minAppVersion: widget.minAppVersionCtrl.text.trim(),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $error')));
      return;
    }
    if (!mounted) return;
    widget.adminPasscodeCtrl.clear();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Administrator security settings saved.'),
        backgroundColor: Color(0xFF1D4ED8),
      ),
    );
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Confirm Logout', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ],
        ),
        content: const Text(
          'Are you sure you want to log out of the Super Admin Console? Your current session will be closed.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      widget.onSignOut?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'SaaS Platform & Security Settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure super admin credentials, scheduled backups, and app maintenance mode.',
                style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Card 1: Maintenance Mode
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.maintenanceMode ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        widget.maintenanceMode ? Icons.engineering_rounded : Icons.check_circle_outline_rounded,
                        color: widget.maintenanceMode ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Platform Maintenance Mode',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.maintenanceMode
                                ? 'Active: All distributors see scheduled maintenance screen'
                                : 'Disabled: All cloud microservices and gateways fully operational',
                            style: TextStyle(
                              fontSize: 12,
                              color: widget.maintenanceMode ? const Color(0xFFDC2626) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: widget.maintenanceMode,
                      activeThumbColor: const Color(0xFFDC2626),
                      activeTrackColor: const Color(0xFFDC2626).withValues(alpha: 0.38),
                      onChanged: (val) {
                        widget.onToggleMaintenance(val);
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Maintenance mode ${val ? 'ENABLED.' : 'DISABLED.'}'),
                            backgroundColor: val ? const Color(0xFFDC2626) : const Color(0xFF059669),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Card 2: Security Passcode & Minimum App Version
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.security_rounded, color: Color(0xFF1D4ED8), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Super Admin Security & Passcode',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: widget.adminPasscodeCtrl,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: 'Master Super Admin Passcode',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: widget.minAppVersionCtrl,
                      decoration: InputDecoration(
                        labelText: 'Minimum Enforced App Version',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _saveSecuritySettings,
                      icon: const Icon(Icons.lock_reset_rounded, size: 16, color: Colors.white),
                      label: const Text('Save Security Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Card 3: Automated Database Backup
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.cloud_sync_rounded, color: Color(0xFF059669), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Cloud Database Backup Schedule',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Switch(
                          value: widget.autoBackupEnabled,
                          activeThumbColor: const Color(0xFF059669),
                          activeTrackColor: const Color(0xFF059669).withValues(alpha: 0.38),
                          onChanged: widget.onToggleAutoBackup,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Automated encrypted snapshots: ${widget.backupFrequency}',
                      style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: _isBackingUp ? null : _triggerInstantBackup,
                      icon: const Icon(Icons.backup_rounded, size: 16, color: Colors.white),
                      label: Text(
                        _isBackingUp ? 'Creating Backup Snapshot...' : 'Trigger Instant Backup Now',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Card 4: Super Admin Session & Logout
              // ---------------------------------------------------------------
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.logout_rounded,
                            color: Color(0xFFDC2626),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Super Admin Session & Logout',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'End administrative session and securely sign out to the login screen.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _handleLogout,
                        icon: const Icon(Icons.logout_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Logout from Super Admin Console',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
