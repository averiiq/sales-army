import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';

class NotificationCenterModal extends StatefulWidget {
  const NotificationCenterModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const NotificationCenterModal(),
    );
  }

  @override
  State<NotificationCenterModal> createState() => _NotificationCenterModalState();
}

class _NotificationCenterModalState extends State<NotificationCenterModal> {
  NotificationModel? _selectedDetail;
  String _selectedFilter = 'All'; // 'All', 'Orders', 'Payments', 'Inventory', 'Broadcasts'

  String _formatRelativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  List<NotificationModel> _getFilteredNotifications(List<NotificationModel> notifications) {
    if (_selectedFilter == 'All') return notifications;
    if (_selectedFilter == 'Orders') {
      return notifications.where((n) => n.type.toLowerCase() == 'order').toList();
    }
    if (_selectedFilter == 'Payments') {
      return notifications.where((n) => n.type.toLowerCase() == 'payment' || n.type.toLowerCase() == 'payment_due').toList();
    }
    if (_selectedFilter == 'Inventory') {
      return notifications.where((n) => n.type.toLowerCase() == 'inventory').toList();
    }
    if (_selectedFilter == 'Broadcasts') {
      return notifications.where((n) => n.type.toLowerCase() == 'broadcast' || n.type.toLowerCase() == 'system').toList();
    }
    return notifications;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    return Container(
      constraints: BoxConstraints(
        maxWidth: 620,
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: _selectedDetail != null
          ? _buildDetailView(_selectedDetail!, isDark, appState)
          : _buildListView(isDark, appState),
    );
  }

  Widget _buildListView(bool isDark, AppState appState) {
    final allNotifications = appState.notifications;
    final filteredNotifications = _getFilteredNotifications(allNotifications);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top handle
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
        const SizedBox(height: 14),

        // Header Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.notifications_active_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A), size: 20),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Notifications & Alerts',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (appState.unreadNotificationsCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${appState.unreadNotificationsCount}',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Row(
              children: [
                if (appState.unreadNotificationsCount > 0)
                  TextButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      appState.markAllNotificationsAsRead();
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: Text(
                      'Mark All Read',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2)),
                    ),
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildFilterChip('All', allNotifications.length, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Orders', allNotifications.where((n) => n.type.toLowerCase() == 'order').length, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Payments', allNotifications.where((n) => n.type.toLowerCase() == 'payment' || n.type.toLowerCase() == 'payment_due').length, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Inventory', allNotifications.where((n) => n.type.toLowerCase() == 'inventory').length, isDark),
              const SizedBox(width: 8),
              _buildFilterChip('Broadcasts', allNotifications.where((n) => n.type.toLowerCase() == 'broadcast' || n.type.toLowerCase() == 'system').length, isDark),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Notifications List
        Flexible(
          child: filteredNotifications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.notifications_off_outlined, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 26),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No Notifications in $_selectedFilter',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Real-time order dispatches, payments, and admin broadcasts will appear here.',
                          style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: filteredNotifications.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, idx) {
                    final alert = filteredNotifications[idx];
                    final isRead = alert.isRead;

                    return Dismissible(
                      key: ValueKey('notif_item_${alert.id}'),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                      ),
                      onDismissed: (_) {
                        HapticFeedback.lightImpact();
                        appState.deleteNotification(alert.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Notification removed'), duration: Duration(seconds: 1)),
                        );
                      },
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          appState.markNotificationAsRead(alert.id);
                          setState(() {
                            _selectedDetail = alert.copyWith(isRead: true);
                          });
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? (isRead ? const Color(0xFF0F172A) : const Color(0xFF1E293B))
                                : (isRead ? const Color(0xFFF8FAFC) : Colors.white),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? (isRead ? const Color(0xFF334155) : const Color(0xFF3B82F6))
                                  : (isRead ? const Color(0xFFE2E8F0) : AppTheme.primary),
                              width: isRead ? 0.8 : 1.3,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7.5),
                                decoration: BoxDecoration(
                                  color: _getTypeBg(alert.type, isDark),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(_getTypeIcon(alert.type), color: _getTypeColor(alert.type, isDark), size: 17),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            alert.title,
                                            style: TextStyle(
                                              fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                                              fontSize: 12.5,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          _formatRelativeTime(alert.createdAt),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      alert.message,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B),
                                        height: 1.25,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Tap to view full details',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                icon: Icon(Icons.close_rounded, size: 14, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  appState.deleteNotification(alert.id);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),

        // Footer Actions: Clear All
        if (allNotifications.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  appState.clearAllNotifications();
                },
                icon: const Icon(Icons.clear_all_rounded, size: 15, color: Color(0xFFDC2626)),
                label: const Text('Clear All', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildFilterChip(String label, int count, bool isDark) {
    final isSelected = _selectedFilter == label;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilter = label);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E56E2) : const Color(0xFF1E56E2))
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1E56E2)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.25) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailView(NotificationModel alert, bool isDark, AppState appState) {
    return Column(
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
            IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              onPressed: () => setState(() => _selectedDetail = null),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'Notification Detail',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
              tooltip: 'Delete Notification',
              onPressed: () {
                HapticFeedback.lightImpact();
                appState.deleteNotification(alert.id);
                setState(() => _selectedDetail = null);
              },
            ),
            IconButton(
              icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getTypeBg(alert.type, isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_getTypeIcon(alert.type), color: _getTypeColor(alert.type, isDark), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${alert.type.toUpperCase()} • ${_formatRelativeTime(alert.createdAt)}',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              Text(
                'FULL NOTIFICATION TEXT',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), letterSpacing: 0.6),
              ),
              const SizedBox(height: 8),
              Text(
                alert.message,
                style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => setState(() => _selectedDetail = null),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Back to Notifications', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
        ),
      ],
    );
  }

  Color _getTypeColor(String type, [bool isDark = false]) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'payment_due':
        return isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
      case 'inventory':
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case 'order':
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8);
      case 'broadcast':
      case 'announcement':
        return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      default:
        return isDark ? Colors.white : const Color(0xFF0F172A);
    }
  }

  Color _getTypeBg(String type, [bool isDark = false]) {
    switch (type.toLowerCase()) {
      case 'payment':
      case 'payment_due':
        return isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFF0FDF4);
      case 'inventory':
        return isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB);
      case 'order':
        return isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF);
      case 'broadcast':
      case 'announcement':
        return isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF5F3FF);
      default:
        return isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'payment':
        return Icons.currency_rupee_rounded;
      case 'payment_due':
        return Icons.warning_amber_rounded;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'order':
        return Icons.receipt_long_rounded;
      case 'broadcast':
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
