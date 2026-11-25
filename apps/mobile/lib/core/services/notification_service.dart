import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';
import 'package:salesarmy/features/dashboard/presentation/dialogs/notification_center_modal.dart';

/// Global navigator key allowing overlays and dialogs without BuildContext
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Enterprise Notification Service for SalesArmy
/// Handles:
/// 1. Realtime Push Notifications via Supabase & WebSocket
/// 2. Interactive In-App Notification Popup Banners
/// 3. Admin Controllable Broadcasts
/// 4. Automated Business Triggers (Orders, Collections, Low Stock, Khata Dues)
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance =>
      _instance ??= NotificationService._();

  NotificationService._();

  AppState? _appState;
  OverlayEntry? _currentBannerEntry;
  Timer? _dismissTimer;
  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Agency the realtime subscription currently listens for.
  String? _subscribedTenantId;

  /// Initialize notification listeners and tie to AppState. Called at app
  /// start, usually before anyone has signed in — [connectForTenant] then
  /// subscribes once the agency is known.
  void initialize(AppState appState) {
    if (_initialized) return;
    _initialized = true;
    _appState = appState;
    _setupSupabaseRealtime(appState);
    requestPermissions();
  }

  /// Request runtime push notification permissions on supported platforms (Android 13+)
  Future<void> requestPermissions() async {
    try {
      final status = await Permission.notification.status;
      if (status.isDenied) {
        await Permission.notification.request();
      }
    } catch (e) {
      debugPrint('NotificationService permission request note: $e');
    }
  }

  /// Determines whether a notification type is allowed based on user preferences.
  Future<bool> _shouldShowForType(String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      switch (type.toLowerCase()) {
        case 'order':
          return prefs.getBool('salesarmy_pref_notif_order') ?? true;
        case 'inventory':
          return prefs.getBool('salesarmy_pref_notif_inventory') ?? true;
        case 'payment':
        case 'payment_due':
          return prefs.getBool('salesarmy_pref_notif_payment') ?? true;
        case 'sync':
        case 'cloud_sync':
          return prefs.getBool('salesarmy_pref_notif_cloud_sync') ?? true;
        case 'broadcast':
        case 'announcement':
        case 'system':
        default:
          return true; // Critical broadcasts are always delivered
      }
    } catch (_) {
      return true;
    }
  }

  /// Checks if sound & vibration alerts are enabled in preferences.
  Future<bool> _isSoundVibrationEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('salesarmy_pref_notif_sound_vibration') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// (Re)subscribes to admin messages for the signed-in agency. Safe to call
  /// repeatedly; does nothing if already listening for this agency.
  void connectForTenant(AppState appState) {
    _appState = appState;
    _initialized = true;
    final tenantId = appState.currentTenantId ?? appState.tenant.tenantId;
    if (tenantId.isEmpty || tenantId == _subscribedTenantId) return;
    _setupSupabaseRealtime(appState);
  }

  /// Dispose all resources to prevent leaks.
  void dispose() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    _currentBannerEntry?.remove();
    _currentBannerEntry = null;
    _appState = null;
    _initialized = false;
    _subscribedTenantId = null;
  }

  void _setupSupabaseRealtime(AppState appState) {
    final tenantId = appState.currentTenantId ?? appState.tenant.tenantId;
    if (tenantId.isEmpty) return;
    _subscribedTenantId = tenantId;

    try {
      SupabaseService.instance.subscribeToNotifications(
        tenantId: tenantId,
        onNotificationReceived: (data) {
          final notif = NotificationModel.fromMap(
            data,
            data['notification_id']?.toString() ??
                data['id']?.toString() ??
                'notif_${DateTime.now().millisecondsSinceEpoch}',
          );

          // Only messages for this agency / user / role / plan.
          if (!appState.isTargetedToMe(data)) return;

          // Add to local state & show popup
          appState.receiveRemoteNotification(notif);
        },
      );
    } catch (e) {
      debugPrint('NotificationService: Supabase realtime note: $e');
    }
  }

  /// Displays an interactive In-App Notification Popup Banner sliding from top
  Future<void> showInAppPopup(NotificationModel notification) async {
    try {
      final allowed = await _shouldShowForType(notification.type);
      if (!allowed) return;

      final navState = rootNavigatorKey.currentState;
      final overlay = navState?.overlay;
      if (overlay == null) return;

      // Remove existing banner if any
      _dismissCurrentBanner();

      final soundVibration = await _isSoundVibrationEnabled();
      if (soundVibration) {
        try {
          HapticFeedback.mediumImpact();
          SystemSound.play(SystemSoundType.alert);
        } catch (_) {}
      }

      _currentBannerEntry = OverlayEntry(
        builder: (context) {
          final isDark = _appState?.isDarkMode ?? false;
          return _InAppBannerWidget(
            notification: notification,
            isDark: isDark,
            onDismiss: () => _dismissCurrentBanner(),
            onTap: () {
              _dismissCurrentBanner();
              final currentContext = rootNavigatorKey.currentContext;
              if (currentContext != null) {
                NotificationCenterModal.show(
                  currentContext,
                  initialNotificationId: notification.id,
                );
              }
            },
          );
        },
      );

      overlay.insert(_currentBannerEntry!);

      // Auto-dismiss after 4.5 seconds
      _dismissTimer?.cancel();
      _dismissTimer = Timer(const Duration(milliseconds: 4500), () {
        _dismissCurrentBanner();
      });
    } catch (e) {
      debugPrint(
        'NotificationService showInAppPopup skipped in headless/test mode: $e',
      );
    }
  }

  void _dismissCurrentBanner() {
    _dismissTimer?.cancel();
    _dismissTimer = null;
    if (_currentBannerEntry != null) {
      try {
        _currentBannerEntry?.remove();
      } catch (e) {
        debugPrint('NotificationService banner remove: $e');
      }
      _currentBannerEntry = null;
    }
  }
}

class _InAppBannerWidget extends StatefulWidget {
  final NotificationModel notification;
  final bool isDark;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const _InAppBannerWidget({
    required this.notification,
    required this.isDark,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  State<_InAppBannerWidget> createState() => _InAppBannerWidgetState();
}

class _InAppBannerWidgetState extends State<_InAppBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnim = Tween<Offset>(begin: const Offset(0, -1.0), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutBack),
        );

    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleDismiss() async {
    await _animController.reverse();
    widget.onDismiss();
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'order':
        return Icons.shopping_bag_outlined;
      case 'payment':
        return Icons.currency_rupee_rounded;
      case 'payment_due':
        return Icons.warning_amber_rounded;
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'broadcast':
      case 'announcement':
        return Icons.campaign_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }

  Color _getTypeColor(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'order':
        return isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
      case 'payment':
        return isDark ? const Color(0xFF34D399) : const Color(0xFF059669);
      case 'payment_due':
        return isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
      case 'inventory':
        return isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
      case 'broadcast':
      case 'announcement':
        return isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED);
      default:
        return isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2);
    }
  }

  Color _getTypeBg(String type, bool isDark) {
    switch (type.toLowerCase()) {
      case 'order':
        return isDark
            ? const Color(0xFF1E3A8A).withValues(alpha: 0.4)
            : const Color(0xFFEFF6FF);
      case 'payment':
        return isDark
            ? const Color(0xFF064E3B).withValues(alpha: 0.4)
            : const Color(0xFFECFDF5);
      case 'payment_due':
        return isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.4)
            : const Color(0xFFFEF2F2);
      case 'inventory':
        return isDark
            ? const Color(0xFF78350F).withValues(alpha: 0.4)
            : const Color(0xFFFFFBEB);
      case 'broadcast':
      case 'announcement':
        return isDark
            ? const Color(0xFF581C87).withValues(alpha: 0.4)
            : const Color(0xFFF5F3FF);
      default:
        return isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final notif = widget.notification;
    final topPadding = MediaQuery.of(context).padding.top;
    final typeColor = _getTypeColor(notif.type, isDark);
    final typeBg = _getTypeBg(notif.type, isDark);

    return Positioned(
      top: topPadding + 10,
      left: 14,
      right: 14,
      child: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _offsetAnim,
          child: Dismissible(
            key: ValueKey('banner_${notif.id}'),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: typeColor.withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.5)
                            : const Color(0xFF0F172A).withValues(alpha: 0.12),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Type Icon Badge
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: typeBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: typeColor.withValues(alpha: 0.3),
                            width: 0.8,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _getTypeIcon(notif.type),
                          color: typeColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    notif.title,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Just now',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? const Color(0xFF94A3B8)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              notif.message,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark
                                    ? const Color(0xFFCBD5E1)
                                    : const Color(0xFF475569),
                                height: 1.25,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // View Pill Action
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(
                            alpha: isDark ? 0.25 : 0.12,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: typeColor.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          'View',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: typeColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Close button
                      InkWell(
                        onTap: _handleDismiss,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
