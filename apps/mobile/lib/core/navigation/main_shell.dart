import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';
import 'package:salesarmy/features/shops/presentation/screens/shops_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';
import 'package:salesarmy/features/visits/presentation/screens/visits_tab.dart';
import 'package:salesarmy/features/inventory/presentation/screens/inventory_tab.dart';

import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_screen.dart';
import 'package:salesarmy/features/settings/presentation/screens/settings_screen.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/core/utils/responsive_helper.dart';
import 'package:salesarmy/features/dashboard/presentation/dialogs/notification_center_modal.dart';

class _ShellTabItem {
  final String id;
  final IconData icon;
  final String label;
  final Widget widget;

  const _ShellTabItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.widget,
  });
}

class MainShell extends StatefulWidget {
  final VoidCallback onSignOut;
  final bool isSuperAdmin;
  const MainShell({super.key, required this.onSignOut, this.isSuperAdmin = false});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'SA';
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.length >= 2) {
      final first = words[0].isNotEmpty ? words[0][0] : '';
      final second = words[1].isNotEmpty ? words[1][0] : '';
      return '$first$second'.toUpperCase();
    }
    return name.trim().substring(0, name.trim().length >= 2 ? 2 : 1).toUpperCase();
  }

  Widget _buildFallbackInitials(String name) {
    return Center(
      child: Text(
        _getInitials(name),
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Cheap id-only computation used by navigation lookups so we don't
  /// rebuild every tab's heavy child widget just to resolve an index.
  List<String> _availableTabIds(AppState appState) {
    final ids = <String>['home'];
    if (appState.canAccessModule('shops')) ids.add('shops');
    if ((appState.canAccessModule('billing') || appState.isFieldSalesRole) &&
        !appState.isDeliveryRole &&
        !appState.isStoreManagerRole) {
      ids.add('billing');
    }
    if ((appState.canAccessModule('orders') || appState.isStoreManagerRole) &&
        !appState.isAccountantRole) {
      ids.add('orders');
    }
    if ((appState.canAccessModule('accounts') ||
            appState.canAccessModule('collections') ||
            appState.isOwnerRole ||
            appState.isAccountantRole) &&
        !appState.isDeliveryRole &&
        !appState.isFieldSalesRole &&
        !appState.isStoreManagerRole) {
      ids.add('collections');
    }
    return ids;
  }

  List<_ShellTabItem> _buildAvailableTabs(AppState appState) {
    final tabs = <_ShellTabItem>[];

    // 1. Home (Always accessible for all roles)
    tabs.add(_ShellTabItem(
      id: 'home',
      icon: Icons.home_rounded,
      label: 'Home',
      widget: DistributorDashboard(
        onNavigateTab: (targetIndex) => _navigateToLegacyTab(targetIndex, appState),
        onNavigateRoute: (routeName) => _navigateToTabId(routeName, appState),
        onOpenOrderTaker: () => _openOrderTaker(),
        onSignOut: widget.onSignOut,
      ),
    ));

    // 2. Parties / Retailers (If role has 'shops' permission)
    if (appState.canAccessModule('shops')) {
      tabs.add(_ShellTabItem(
        id: 'shops',
        icon: Icons.storefront_rounded,
        label: 'Parties',
        widget: ShopsTab(
          onBack: () => _navigateToTabId('home', appState),
          onStartOrderForShop: (shop) => _openOrderTaker(shop: shop),
        ),
      ));
    }

    // 3. Bill / POS Invoicing (Accessible for roles with 'billing' permission or Field Sales)
    if ((appState.canAccessModule('billing') || appState.isFieldSalesRole) && !appState.isDeliveryRole && !appState.isStoreManagerRole) {
      tabs.add(_ShellTabItem(
        id: 'billing',
        icon: Icons.receipt_long_rounded,
        label: 'Bill',
        widget: OrderTakerFlow(
          isEmbedded: true,
          onBack: () => _navigateToTabId('home', appState),
          onOrderCompleted: () {
            _navigateToTabId('orders', appState);
          },
        ),
      ));
    }

    // 4. Orders / Dispatches (Owner, Field Sales, Delivery Staff, Store Manager)
    if ((appState.canAccessModule('orders') || appState.isStoreManagerRole) && !appState.isAccountantRole) {
      tabs.add(_ShellTabItem(
        id: 'orders',
        icon: Icons.local_shipping_outlined,
        label: 'Orders',
        widget: OrdersTab(
          initialTabIndex: 0,
          onBack: () => _navigateToTabId('home', appState),
          onTakeNewOrder: () => _openOrderTaker(),
        ),
      ));
    }

    // 5. Collection / Khata (ONLY for roles with 'accounts' or 'collections': Owner, Accountant)
    if ((appState.canAccessModule('accounts') || appState.canAccessModule('collections') || appState.isOwnerRole || appState.isAccountantRole) &&
        !appState.isDeliveryRole && !appState.isFieldSalesRole && !appState.isStoreManagerRole) {
      tabs.add(_ShellTabItem(
        id: 'collections',
        icon: Icons.account_balance_wallet_rounded,
        label: 'Collection',
        widget: CollectionsTab(onBack: () => _navigateToTabId('home', appState)),
      ));
    }

    return tabs;
  }

  void _navigateToTabId(String tabId, AppState appState) {
    HapticFeedback.selectionClick();
    final tabIds = _availableTabIds(appState);
    final foundIndex = tabIds.indexOf(tabId);
    if (foundIndex != -1) {
      setState(() => _currentIndex = foundIndex);
      return;
    }

    // Role-safe fallback: If current role's bottom navigation bar does not include this tab,
    // open it in a push route so tapping tiles always opens the intended destination.
    switch (tabId) {
      case 'orders':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OrdersTab(
              initialTabIndex: 0,
              onTakeNewOrder: () => _openOrderTaker(),
            ),
          ),
        );
        break;
      case 'collections':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CollectionsTab(onBack: () => Navigator.pop(context)),
          ),
        );
        break;
      case 'shops':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ShopsTab(
              onStartOrderForShop: (shop) => _openOrderTaker(shop: shop),
            ),
          ),
        );
        break;
      case 'billing':
        _openOrderTaker();
        break;
      case 'inventory':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const InventoryTab(isStandalone: true),
          ),
        );
        break;
      case 'visits':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitsTab(onBack: () => Navigator.pop(context)),
          ),
        );
        break;
      default:
        setState(() => _currentIndex = 0);
    }
  }

  void _navigateToLegacyTab(int legacyIndex, AppState appState) {
    switch (legacyIndex) {
      case 0:
        _navigateToTabId('home', appState);
        break;
      case 1:
        _navigateToTabId('shops', appState);
        break;
      case 2:
        _navigateToTabId('orders', appState);
        break;
      case 3:
        _navigateToTabId('inventory', appState);
        break;
      case 4:
        _navigateToTabId('collections', appState);
        break;
      case 5:
        _navigateToTabId('visits', appState);
        break;
      case 6:
        _navigateToTabId('billing', appState);
        break;
      default:
        _navigateToTabId('home', appState);
    }
  }

  void _navigateToTab(int index) {
    final appState = Provider.of<AppState>(context, listen: false);
    final tabIds = _availableTabIds(appState);
    if (index >= 0 && index < tabIds.length) {
      HapticFeedback.selectionClick();
      setState(() => _currentIndex = index);
    } else {
      _navigateToLegacyTab(index, appState);
    }
  }

  void _openOrderTaker({ShopModel? shop}) {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.isAccountPausedOrCancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account Suspended: Cannot create new orders while account is ${appState.subscriptionBadgeText}.'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (appState.isModuleRemotelyDisabled('billing') || appState.isModuleRemotelyDisabled('orders')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order Taker is temporarily unavailable.'),
          backgroundColor: Color(0xFFD97706),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    if (!appState.canAccessModule('billing') && !appState.isFieldSalesRole) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Access Restricted: Role (${appState.activeRole}) cannot create Bills.'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (shop == null && _availableTabIds(appState).contains('billing')) {
      _navigateToTabId('billing', appState);
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTakerFlow(
          initialShop: shop,
          onOrderCompleted: () {
            Navigator.pop(context);
            _navigateToTabId('orders', appState);
          },
        ),
      ),
    );
  }





  PreferredSizeWidget _buildHomeAppBar(BuildContext context, AppState appState, bool isDark, String displayFirmName) {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      toolbarHeight: 64,
      titleSpacing: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      ),
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getNavbarGradient(isDark),
          border: Border(
            bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFEAB308).withValues(alpha: 0.3), width: 1.0),
          ),
        ),
      ),
      title: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.isCompact ? 10 : 16,
          vertical: 6,
        ),
        child: Row(
          children: [
            // Top-Left: Circular company avatar and monogram (navigates to Profile & Settings)
            Expanded(
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileAndSettingsScreen(
                        initialTab: 0,
                        onNavigateToTab: (tabIdx) => _navigateToTab(tabIdx),
                        onSignOut: widget.onSignOut,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1E56E2), Color(0xFF173BBF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFFDE68A), width: 2.0),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E56E2).withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: ClipOval(
                          child: ((appState.tenant.profileImageUrl?.trim().isNotEmpty == true)
                              ? AppImageHelper.buildImage(
                                  appState.tenant.profileImageUrl!,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => (appState.tenant.logoUrl?.trim().isNotEmpty == true)
                                      ? AppImageHelper.buildImage(
                                          appState.tenant.logoUrl!,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _buildFallbackInitials(displayFirmName),
                                        )
                                      : _buildFallbackInitials(displayFirmName),
                                )
                              : (appState.tenant.logoUrl?.trim().isNotEmpty == true)
                                  ? AppImageHelper.buildImage(
                                      appState.tenant.logoUrl!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _buildFallbackInitials(displayFirmName),
                                    )
                                  : _buildFallbackInitials(displayFirmName)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              displayFirmName,
                              style: TextStyle(
                                fontSize: context.isCompact ? 13 : 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                                height: 1.15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: appState.isSubscriptionExpired || appState.isAccountPausedOrCancelled
                                        ? const Color(0xFFEF4444)
                                        : const Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    appState.subscriptionBadgeText,
                                    style: TextStyle(
                                      fontSize: context.isCompact ? 9 : 10,
                                      fontWeight: FontWeight.w700,
                                      height: 1.1,
                                      color: appState.isSubscriptionExpired || appState.isAccountPausedOrCancelled
                                          ? const Color(0xFFDC2626)
                                          : const Color(0xFF16A34A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.5) : const Color(0xFFBFDBFE),
                                        width: 0.8,
                                      ),
                                    ),
                                    child: Text(
                                      appState.activeRole,
                                      style: TextStyle(
                                        fontSize: context.isCompact ? 8.5 : 9,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                        height: 1.1,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
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
            ),

            const SizedBox(width: 8),

            // Top-Right: Dark / Light Mode Toggle
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  key: const ValueKey('theme_mode_toggle_btn'),
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    appState.toggleTheme();
                  },
                  child: Center(
                    child: Icon(
                      isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
                      color: isDark ? const Color(0xFFFBBF24) : const Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Top-Right: Notification Bell with unread badge
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A)),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFFD97706).withValues(alpha: 0.10),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        NotificationCenterModal.show(context);
                      },
                      child: Center(
                        child: Icon(Icons.notifications_none_rounded, color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155), size: 21),
                      ),
                    ),
                  ),
                ),
                if (appState.unreadNotificationsCount > 0)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDC2626),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                      child: Text(
                        '${appState.unreadNotificationsCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final tenant = appState.tenant;
    final displayFirmName = tenant.firmName != null && tenant.firmName!.trim().isNotEmpty
        ? tenant.firmName!
        : (tenant.representativeName != null && tenant.representativeName!.trim().isNotEmpty
            ? tenant.representativeName!
            : 'SalesArmy Agency');

    final availableTabs = _buildAvailableTabs(appState);
    if (_currentIndex >= availableTabs.length) {
      _currentIndex = 0;
    }

    final isDark = appState.isDarkMode;
    final isHome = _currentIndex == 0;

    return PopScope(
      canPop: isHome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isHome) {
          setState(() => _currentIndex = 0);
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        child: Scaffold(
          backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
          appBar: isHome ? _buildHomeAppBar(context, appState, isDark, displayFirmName) : null,
          body: Container(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            child: Column(
              children: [
                if (appState.isSubscriptionExpired || appState.isAccountPausedOrCancelled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEF2F2),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Account status: ${appState.subscriptionBadgeText}. New order creation and live operations are restricted.',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (appState.emergencyBroadcast != null &&
                    appState.emergencyBroadcast!['active'] == true &&
                    !appState.isAnnouncementDismissed)
                  _buildEmergencyBroadcastBanner(context, appState, isDark),
                if (appState.isMaintenanceMode)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
                    child: Row(
                      children: [
                        const Icon(Icons.engineering_rounded, color: Color(0xFFD97706), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Maintenance Notice: ${appState.maintenanceMessage}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                          ),
                        ),
                        if (appState.maintenanceEta != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              appState.maintenanceEta!,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                            ),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: availableTabs.map((t) => t.widget).toList(),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topCenter,
              heightFactor: isHome ? 1.0 : 0.0,
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                offset: isHome ? Offset.zero : const Offset(0, 1.0),
                child: IgnorePointer(
                  ignoring: !isHome,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: Border(
                        top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9), width: 1.0),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: ResponsiveContainer(
                        maxWidth: 680,
                        padding: EdgeInsets.symmetric(
                          horizontal: context.isCompact ? 4 : 8,
                          vertical: 4,
                        ),
                        child: SizedBox(
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: List.generate(availableTabs.length, (idx) {
                              final tab = availableTabs[idx];
                              return _buildNavItem(
                                context,
                                idx,
                                tab.icon,
                                tab.label,
                                isDark,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _currentIndex = idx);
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    int index,
    IconData icon,
    String label,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final isSelected = _currentIndex == index;
    final activeColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2);
    final inactiveColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF)) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: isSelected ? Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFDBEAFE), width: 1.0) : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap ?? () => _navigateToTab(index),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedScale(
                    scale: isSelected ? 1.08 : 1.0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      icon,
                      size: context.isCompact ? 19 : 21,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  const SizedBox(height: 2.5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: context.isCompact ? 9.5 : 10.5,
                      fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                      color: isSelected ? activeColor : inactiveColor,
                      letterSpacing: isSelected ? -0.2 : 0.0,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyBroadcastBanner(BuildContext context, AppState appState, bool isDark) {
    final bcast = appState.emergencyBroadcast!;
    final type = (bcast['type'] ?? 'info').toString().toLowerCase();
    final title = bcast['title']?.toString() ?? 'Platform Announcement';
    final message = bcast['message']?.toString() ?? '';
    final dismissible = bcast['dismissible'] != false;
    final actionText = bcast['actionText']?.toString();

    Color bgColor;
    Color borderColor;
    Color textColor;
    IconData iconData;

    switch (type) {
      case 'critical':
        bgColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEF2F2);
        borderColor = const Color(0xFFEF4444);
        textColor = isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B);
        iconData = Icons.crisis_alert_rounded;
        break;
      case 'warning':
        bgColor = isDark ? const Color(0xFF78350F) : const Color(0xFFFFFBEB);
        borderColor = const Color(0xFFF59E0B);
        textColor = isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E);
        iconData = Icons.warning_amber_rounded;
        break;
      case 'festive':
        bgColor = isDark ? const Color(0xFF4C1D95) : const Color(0xFFF5F3FF);
        borderColor = const Color(0xFF8B5CF6);
        textColor = isDark ? const Color(0xFFDDD6FE) : const Color(0xFF5B21B6);
        iconData = Icons.celebration_rounded;
        break;
      default:
        bgColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF);
        borderColor = const Color(0xFF3B82F6);
        textColor = isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF);
        iconData = Icons.campaign_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: borderColor, width: 1.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(iconData, color: borderColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: -0.2,
                  ),
                ),
                if (message.isNotEmpty)
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: textColor.withValues(alpha: 0.9),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (actionText != null && actionText.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: borderColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: borderColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                actionText,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                ),
              ),
            ),
          ],
          if (dismissible) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => appState.dismissAnnouncement(),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: textColor),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
