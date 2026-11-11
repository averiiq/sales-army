import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _selectedCategory = 'All';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Notification Preferences toggles
  bool _prefOrderAlerts = true;
  bool _prefInventoryAlerts = true;
  bool _prefPaymentAlerts = true;
  bool _prefCloudSyncAlerts = true;
  bool _prefSoundVibration = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _prefOrderAlerts = prefs.getBool('salesarmy_pref_notif_order') ?? true;
          _prefInventoryAlerts = prefs.getBool('salesarmy_pref_notif_inventory') ?? true;
          _prefPaymentAlerts = prefs.getBool('salesarmy_pref_notif_payment') ?? true;
          _prefCloudSyncAlerts = prefs.getBool('salesarmy_pref_notif_cloud_sync') ?? true;
          _prefSoundVibration = prefs.getBool('salesarmy_pref_notif_sound_vibration') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('salesarmy_pref_notif_order', _prefOrderAlerts);
      await prefs.setBool('salesarmy_pref_notif_inventory', _prefInventoryAlerts);
      await prefs.setBool('salesarmy_pref_notif_payment', _prefPaymentAlerts);
      await prefs.setBool('salesarmy_pref_notif_cloud_sync', _prefCloudSyncAlerts);
      await prefs.setBool('salesarmy_pref_notif_sound_vibration', _prefSoundVibration);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return AppFormatters.date(dt);
  }

  void _triggerTestNotification(AppState appState) {
    HapticFeedback.mediumImpact();
    final testPresets = [
      NotificationModel(
        id: 'notif_test_${DateTime.now().millisecondsSinceEpoch}',
        type: 'order',
        title: 'New Order Received',
        message: 'Order #ORD-8924 placed by Balaji Traders for ₹14,850. Ready for dispatch.',
        createdAt: DateTime.now(),
        isRead: false,
      ),
      NotificationModel(
        id: 'notif_test_${DateTime.now().millisecondsSinceEpoch + 1}',
        type: 'inventory',
        title: 'Low Stock Alert',
        message: 'Parle-G 250g is critically low (only 4 units left in warehouse). Reorder recommended.',
        createdAt: DateTime.now(),
        isRead: false,
      ),
      NotificationModel(
        id: 'notif_test_${DateTime.now().millisecondsSinceEpoch + 2}',
        type: 'payment',
        title: 'Payment Received',
        message: '₹22,000 received via UPI from Laxmi General Store. Bank balance updated.',
        createdAt: DateTime.now(),
        isRead: false,
      ),
      NotificationModel(
        id: 'notif_test_${DateTime.now().millisecondsSinceEpoch + 3}',
        type: 'payment_due',
        title: 'Payment Due Overdue',
        message: 'Invoice #INV-4412 for Sharma Kirana Store (₹8,400) is past due by 5 days.',
        createdAt: DateTime.now(),
        isRead: false,
      ),
    ];

    // Pick one sequentially or based on time
    final nextPreset = testPresets[DateTime.now().second % testPresets.length];
    appState.addNotification(nextPreset);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Test alert generated: "${nextPreset.title}"'),
        backgroundColor: const Color(0xFF1E56E2),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _confirmClearAll(BuildContext context, AppState appState) {
    final isDark = appState.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(
              'Clear All Notifications?',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently remove all notifications from your notification center.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              appState.clearAllNotifications();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('All notifications cleared'),
                  backgroundColor: Color(0xFFEF4444),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Clear All', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showNotificationPreferencesModal(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.settings_outlined, color: Color(0xFF1E56E2), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Notification Preferences',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                Text(
                  'Select which automated alerts you receive on this device',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                _buildPrefSwitch(
                  title: 'Orders & Dispatch Alerts',
                  subtitle: 'New orders booked, status changes, and dispatch invoices',
                  icon: Icons.receipt_long_rounded,
                  value: _prefOrderAlerts,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _prefOrderAlerts = val);
                    setModalState(() {});
                  },
                ),
                _buildPrefSwitch(
                  title: 'Low Stock & Inventory Alerts',
                  subtitle: 'Warnings when products drop below minimum reorder thresholds',
                  icon: Icons.warning_amber_rounded,
                  value: _prefInventoryAlerts,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _prefInventoryAlerts = val);
                    setModalState(() {});
                  },
                ),
                _buildPrefSwitch(
                  title: 'Customer Payments & Dues',
                  subtitle: 'Payment collections, ledger updates, and overdue credit balances',
                  icon: Icons.payments_outlined,
                  value: _prefPaymentAlerts,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _prefPaymentAlerts = val);
                    setModalState(() {});
                  },
                ),
                _buildPrefSwitch(
                  title: 'Cloud Sync & Outbox Status',
                  subtitle: 'Daily 12 PM & 10 PM automatic cloud backup sync reports',
                  icon: Icons.cloud_sync_outlined,
                  value: _prefCloudSyncAlerts,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _prefCloudSyncAlerts = val);
                    setModalState(() {});
                  },
                ),
                _buildPrefSwitch(
                  title: 'Sound & Haptic Feedback',
                  subtitle: 'Play subtle beep and vibrate when critical alerts arrive',
                  icon: Icons.volume_up_outlined,
                  value: _prefSoundVibration,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() => _prefSoundVibration = val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await _savePreferences();
                    if (modalCtx.mounted) Navigator.pop(modalCtx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notification preferences saved successfully'),
                          backgroundColor: Color(0xFF059669),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save Preferences', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPrefSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF1E56E2)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : const Color(0xFF0F172A),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
        ),
      ),
      value: value,
      activeThumbColor: const Color(0xFF1E56E2),
      onChanged: onChanged,
    );
  }

  void _openDetailDialog(BuildContext context, AppState appState, NotificationModel alert) {
    final isDark = appState.isDarkMode;
    // Mark as read immediately when opening
    if (!alert.isRead) {
      appState.markNotificationAsRead(alert.id);
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _getTypeBg(alert.type, isDark),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTypeIcon(alert.type), color: _getTypeColor(alert.type, isDark), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Text(
                    '${_getTypeLabel(alert.type)} • ${_formatRelativeTime(alert.createdAt)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Text(
                alert.message,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                const SizedBox(width: 6),
                Text(
                  'Received: ${AppFormatters.date(alert.createdAt)}',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              appState.deleteNotification(alert.id);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Notification removed'),
                  backgroundColor: Color(0xFFEF4444),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
            label: const Text('Delete', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E56E2),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final allNotifications = appState.notifications;
    final unreadCount = appState.unreadNotificationsCount;

    // Filter logic
    final filtered = allNotifications.where((n) {
      if (_selectedCategory == 'Unread' && n.isRead) return false;
      if (_selectedCategory == 'Orders' && n.type != 'order') return false;
      if (_selectedCategory == 'Inventory' && n.type != 'inventory') return false;
      if (_selectedCategory == 'Payments' && n.type != 'payment' && n.type != 'payment_due') return false;
      if (_selectedCategory == 'System' && n.type != 'sync' && n.type != 'system') return false;

      final query = _searchQuery.toLowerCase().trim();
      if (query.isNotEmpty) {
        return n.title.toLowerCase().contains(query) || n.message.toLowerCase().contains(query);
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            Text(
              unreadCount > 0 ? '$unreadCount unread alerts' : 'All alerts caught up',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: unreadCount > 0 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ],
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 21),
            tooltip: 'Notification Preferences',
            onPressed: () => _showNotificationPreferencesModal(context, isDark),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 22),
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            onSelected: (val) {
              if (val == 'mark_all_read') {
                HapticFeedback.lightImpact();
                appState.markAllNotificationsAsRead();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All notifications marked as read'),
                    backgroundColor: Color(0xFF059669),
                    duration: Duration(seconds: 1),
                  ),
                );
              } else if (val == 'clear_all') {
                _confirmClearAll(context, appState);
              } else if (val == 'test_notification') {
                _triggerTestNotification(appState);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'mark_all_read',
                enabled: unreadCount > 0,
                child: Row(
                  children: [
                    const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF1E56E2)),
                    const SizedBox(width: 10),
                    Text('Mark All as Read', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'test_notification',
                child: Row(
                  children: [
                    const Icon(Icons.add_alert_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 10),
                    Text('Send Test Alert', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'clear_all',
                enabled: allNotifications.isNotEmpty,
                child: const Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded, size: 18, color: Color(0xFFEF4444)),
                    SizedBox(width: 10),
                    Text('Clear All Notifications', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ),
      ),
      body: Column(
        children: [
          // 1. Search Bar & Metric Banner
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              children: [
                // Quick Search Bar
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      hintText: 'Search alerts, orders, invoices, products...',
                      hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Category Filter Tabs
          Container(
            height: 48,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _buildCategoryChip('All', allNotifications.length, isDark),
                const SizedBox(width: 8),
                _buildCategoryChip('Unread', unreadCount, isDark, highlightIfCount: true),
                const SizedBox(width: 8),
                _buildCategoryChip('Orders', allNotifications.where((n) => n.type == 'order').length, isDark),
                const SizedBox(width: 8),
                _buildCategoryChip('Inventory', allNotifications.where((n) => n.type == 'inventory').length, isDark),
                const SizedBox(width: 8),
                _buildCategoryChip('Payments', allNotifications.where((n) => n.type == 'payment' || n.type == 'payment_due').length, isDark),
                const SizedBox(width: 8),
                _buildCategoryChip('System', allNotifications.where((n) => n.type == 'sync' || n.type == 'system').length, isDark),
              ],
            ),
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

          // 3. Mark All Read banner if unread exist
          if (unreadCount > 0 && _selectedCategory == 'All')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.2) : const Color(0xFFEFF6FF),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1E56E2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have $unreadCount unread notifications',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E56E2)),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      appState.markAllNotificationsAsRead();
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        'Mark all read',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E56E2)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 4. Notifications List View
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 32,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'No Alerts Matching "$_searchQuery"'
                                : (_selectedCategory == 'Unread'
                                    ? 'No Unread Alerts'
                                    : 'No Notifications in $_selectedCategory'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try searching with a different keyword or invoice #'
                                : 'All new orders, low stock warnings, and payment collections appear here in real-time.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: () => _triggerTestNotification(appState),
                            icon: const Icon(Icons.add_alert_rounded, size: 16, color: Colors.white),
                            label: const Text('Send Test Alert', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E56E2),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, idx) {
                      final notif = filtered[idx];
                      final isRead = notif.isRead;

                      return Dismissible(
                        key: ValueKey(notif.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                              SizedBox(height: 2),
                              Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        onDismissed: (direction) {
                          final deletedNotif = notif;
                          appState.deleteNotification(deletedNotif.id);
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Removed "${deletedNotif.title}"'),
                              backgroundColor: const Color(0xFF0F172A),
                              duration: const Duration(seconds: 3),
                              showCloseIcon: true,
                              closeIconColor: Colors.white70,
                              dismissDirection: DismissDirection.horizontal,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              behavior: SnackBarBehavior.floating,
                              action: SnackBarAction(
                                label: 'Undo',
                                textColor: AppTheme.yellowPrimary,
                                onPressed: () {
                                  messenger.clearSnackBars();
                                  appState.addNotification(deletedNotif);
                                },
                              ),
                            ),
                          );
                        },
                        child: InkWell(
                          onTap: () => _openDetailDialog(context, appState, notif),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? (isRead ? const Color(0xFF1E293B) : const Color(0xFF1E293B))
                                  : (isRead ? Colors.white : const Color(0xFFFFFFFF)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isRead
                                    ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                                    : (isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E56E2)),
                                width: isRead ? 1.0 : 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.15)
                                      : (isRead ? const Color(0xFF0F172A).withValues(alpha: 0.02) : const Color(0xFF1E56E2).withValues(alpha: 0.08)),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Icon with Badge
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: _getTypeBg(notif.type, isDark),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(_getTypeIcon(notif.type), color: _getTypeColor(notif.type, isDark), size: 20),
                                    ),
                                    if (!isRead)
                                      Positioned(
                                        top: -2,
                                        right: -2,
                                        child: Container(
                                          width: 10,
                                          height: 10,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: isDark ? const Color(0xFF1E293B) : Colors.white, width: 1.5),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(width: 12),

                                // Text Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              notif.title,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _formatRelativeTime(notif.createdAt),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        notif.message,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.35,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),

                                      // Bottom Card Status & Action Badges
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _getTypeLabel(notif.type),
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              if (!isRead)
                                                InkWell(
                                                  onTap: () {
                                                    HapticFeedback.selectionClick();
                                                    appState.markNotificationAsRead(notif.id);
                                                  },
                                                  borderRadius: BorderRadius.circular(6),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    child: const Row(
                                                      children: [
                                                        Icon(Icons.check_rounded, size: 13, color: Color(0xFF1E56E2)),
                                                        SizedBox(width: 3),
                                                        Text('Mark read', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF1E56E2))),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  appState.deleteNotification(notif.id);
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(2),
                                                  child: Icon(Icons.delete_outline_rounded, size: 15, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _triggerTestNotification(appState),
                  icon: const Icon(Icons.add_alert_rounded, size: 16),
                  label: const Text('Send Test Alert', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E56E2),
                    side: const BorderSide(color: Color(0xFF1E56E2)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: unreadCount > 0 ? () => appState.markAllNotificationsAsRead() : null,
                  icon: const Icon(Icons.done_all_rounded, size: 16, color: Colors.white),
                  label: const Text('Mark All Read', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String category, int count, bool isDark, {bool highlightIfCount = false}) {
    final isSel = _selectedCategory == category;
    final showBadge = count > 0;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedCategory = category);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSel ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSel ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              category,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                color: isSel ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: highlightIfCount
                      ? const Color(0xFFEF4444)
                      : (isSel ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return 'Order & Dispatch';
      case 'inventory':
        return 'Inventory Alert';
      case 'payment':
        return 'Payment Received';
      case 'payment_due':
        return 'Payment Due';
      case 'sync':
        return 'Cloud Sync';
      default:
        return 'System Alert';
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'order':
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      case 'inventory':
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case 'payment':
        return isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A);
      case 'payment_due':
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case 'sync':
        return isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7);
      default:
        return isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    }
  }

  Color _getTypeBg(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'order':
        return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF);
      case 'inventory':
        return isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB);
      case 'payment':
        return isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4);
      case 'payment_due':
        return isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2);
      case 'sync':
        return isDark ? const Color(0xFF082F49).withValues(alpha: 0.3) : const Color(0xFFF0F9FF);
      default:
        return isDark ? const Color(0xFF334155).withValues(alpha: 0.4) : const Color(0xFFF1F5F9);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.local_shipping_outlined;
      case 'inventory':
        return Icons.warning_amber_rounded;
      case 'payment':
        return Icons.check_circle_outline_rounded;
      case 'payment_due':
        return Icons.error_outline_rounded;
      case 'sync':
        return Icons.cloud_done_outlined;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
