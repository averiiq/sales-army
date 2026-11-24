import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/responsive_helper.dart';
import 'package:salesarmy/features/shops/presentation/dialogs/add_shop_dialog.dart';
import 'package:salesarmy/features/settings/presentation/dialogs/hardware_settings_modal.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';
import 'package:salesarmy/features/inventory/presentation/screens/inventory_tab.dart';
import 'package:salesarmy/features/orders/presentation/dialogs/sales_return_dialog.dart';
import 'package:salesarmy/features/billing/presentation/dialogs/estimated_bill_dialog.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/sales_data_screen.dart';
import 'package:salesarmy/features/collections/presentation/screens/expense_screen.dart';
import 'package:salesarmy/features/visits/presentation/screens/reminders_screen.dart';
import 'package:salesarmy/features/visits/presentation/screens/visits_tab.dart';
import 'package:salesarmy/features/shops/presentation/screens/shop_detail_screen.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/core/widgets/plan_crown_badge.dart';

class _DashboardReminderItem {
  final String key;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isWarning;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _DashboardReminderItem({
    required this.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isWarning,
    required this.onTap,
    required this.onDismiss,
  });
}

class _DashboardActionItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color bgColor;
  final Color iconColor;
  final String? badgeText;
  final Color? badgeColor;
  final VoidCallback onTap;
  /// Plan capability this tile uses (drives the crown badge colour).
  final String? planFeature;

  const _DashboardActionItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
    this.planFeature,
  });
}

class DistributorDashboard extends StatelessWidget {
  final Function(int tabIndex)? onNavigateTab;
  final Function(String routeName)? onNavigateRoute;
  final VoidCallback? onOpenOrderTaker;
  final VoidCallback? onSignOut;
  final bool showHeader;

  const DistributorDashboard({
    super.key,
    this.onNavigateTab,
    this.onNavigateRoute,
    this.onOpenOrderTaker,
    this.onSignOut,
    this.showHeader = false,
  });

  void _navigate(BuildContext context, {int? tabIndex, String? routeName, Widget? fallbackScreen}) {
    HapticFeedback.lightImpact();
    if (onNavigateRoute != null && routeName != null) {
      onNavigateRoute!(routeName);
      return;
    }
    if (onNavigateTab != null && tabIndex != null) {
      onNavigateTab!(tabIndex);
      return;
    }
    if (fallbackScreen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => fallbackScreen));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final todaySales = appState.todaySales;
    final todayCollections = appState.todayCollections;
    final visitsCompleted = appState.visits.where((v) => v.checkOutTime != null).length;
    final totalVisits = appState.visits.length;

    // Filter shops with dues
    final shopsWithDues = appState.shops.where((s) => s.currentOutstanding > 0).toList();
    final totalDues = shopsWithDues.fold<double>(0.0, (sum, s) => sum + s.currentOutstanding);

    // Filter pending orders awaiting delivery
    final pendingOrders = appState.orders.where((o) => o.status.toLowerCase() != 'delivered').toList();

    // Recent orders sorted by latest
    final sortedOrders = List<OrderModel>.from(appState.orders)
      ..sort((a, b) {
        final aTime = a.placedAt ?? a.createdAt ?? DateTime(2020);
        final bTime = b.placedAt ?? b.createdAt ?? DateTime(2020);
        return bTime.compareTo(aTime);
      });

    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getDashboardGradient(isDark),
        ),
        child: SafeArea(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => ScaffoldMessenger.of(context).clearSnackBars(),
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 400));
              },
              color: const Color(0xFF1D4ED8),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  context.horizontalPadding,
                  12,
                  context.horizontalPadding,
                  96,
                ),
                child: ResponsiveContainer(
                  maxWidth: 960,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (showHeader) ...[
                        _buildHeader(context, appState),
                        const SizedBox(height: 14),
                      ],

                    // Role-Tailored Top Bar (Cash & Bank for Owner/Accountant, Beat for Sales, Van Route for Delivery, Godown for Store Manager)
                    _buildRoleTopBar(context, appState, pendingOrders, isDark: isDark),
                    const SizedBox(height: 12),

                    // Top Priority Alerts Center (Dues, Low Stock, Pending Orders, Account Notices)
                    _buildTopAlertsSection(context, appState, shopsWithDues, totalDues, pendingOrders, isDark: isDark),

                    // Greeting (Section 18 of Client Meeting Spec - Time-based greeting without username)
                    _buildTimeBasedGreeting(context, isDark: isDark),

                    // 1. Blue Hero Card (Today's Sales, In-Hand Balance, Visits, Collections)
                    _buildExecutiveFinancialSlate(
                      context: context,
                      appState: appState,
                      todaySales: todaySales,
                      todayCollections: todayCollections,
                      visitsCompleted: visitsCompleted,
                      totalVisits: totalVisits,
                      totalDues: totalDues,
                    ),
                    const SizedBox(height: 14),

                    // 2. Sales Milestone Banner (20 Lakhs Sales Milestone Reached! - Only for Owner)
                    if (appState.isOwnerRole && !appState.isDailyNoticeDismissed('sales_milestone_20l')) ...[
                      _buildMilestoneBanner(context, appState, isDark: isDark),
                      const SizedBox(height: 14),
                    ],

                    // 3. 2x2 Quick Action Cards (New Shop, Create Bill, Collect Dues, Inventory)
                    _buildQuickActionCards(context, isDark: isDark),
                    const SizedBox(height: 18),

                    // 4. Pending Reminders Section (Swipeable & Dismissible for today)
                    if (!appState.isDailyNoticeDismissed('pending_reminders_section')) ...[
                      _buildPendingRemindersSection(context, appState, isDark: isDark),
                      const SizedBox(height: 18),
                    ],

                    // 5. Top Performing Retailers Section (View All)
                    _buildTopPerformingRetailersSection(context, appState, isDark: isDark),
                    const SizedBox(height: 18),

                    // 6. Recent Activity / Invoices Feed
                    _buildRecentInvoicesSection(context, appState, sortedOrders, isDark: isDark),
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

  void _showUndoSnackBar(BuildContext context, String message, VoidCallback onUndo) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.white),
        ),
        duration: const Duration(milliseconds: 2800),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCloseIcon: true,
        closeIconColor: Colors.white70,
        dismissDirection: DismissDirection.horizontal,
        action: SnackBarAction(
          label: 'Undo',
          textColor: const Color(0xFFFBBF24),
          onPressed: () {
            messenger.clearSnackBars();
            onUndo();
          },
        ),
      ),
    );

    // Guaranteed auto-dismiss fallback timer even if device has accessibility navigation active
    bool isTest = false;
    try {
      if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
        isTest = true;
      }
    } catch (_) {}

    if (!isTest) {
      Timer(const Duration(milliseconds: 3000), () {
        try {
          controller.close();
        } catch (_) {}
      });
    }
  }

  // Time-based greeting helper (Section 18 of Client Meeting Spec)
  Widget _buildTimeBasedGreeting(BuildContext context, {bool isDark = false}) {
    final hour = DateTime.now().hour;
    String greeting;
    IconData icon;
    Color iconColor;

    if (hour < 12) {
      greeting = 'Good Morning';
      icon = Icons.wb_sunny_rounded;
      iconColor = const Color(0xFFF59E0B);
    } else if (hour < 17) {
      greeting = 'Good Afternoon';
      icon = Icons.light_mode_rounded;
      iconColor = const Color(0xFFEAB308);
    } else {
      greeting = 'Good Evening';
      icon = Icons.nightlight_round;
      iconColor = const Color(0xFF6366F1);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.18),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Daily Operations Overview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  'Active',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 1. Blue Hero Card (Role-Tailored Executive Financial Slate)
  Widget _buildExecutiveFinancialSlate({
    required BuildContext context,
    required AppState appState,
    required double todaySales,
    required double todayCollections,
    required int visitsCompleted,
    required int totalVisits,
    required double totalDues,
  }) {
    final String heroTitle;
    final IconData heroIcon;
    final String actionPillText;
    final VoidCallback onActionPillTap;
    final String mainMetricValue;
    final String targetProgressText;
    final String targetSubText;
    final double progressFraction;

    final String subMetric1Title;
    final String subMetric1Value;
    final String subMetric2Title;
    final String subMetric2Value;
    final VoidCallback? onSubMetric1Tap;
    final VoidCallback? onSubMetric2Tap;

    if (appState.isAccountantRole) {
      heroTitle = "Today's Collections";
      heroIcon = Icons.account_balance_wallet_rounded;
      actionPillText = 'Khata Ledger';
      onActionPillTap = () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CollectionsTab(onBack: () => Navigator.pop(context))));
      };
      final coll = todayCollections;
      mainMetricValue = AppFormatters.currency(coll);
      progressFraction = (coll / 8000.0).clamp(0.0, 1.0);
      targetProgressText = '${(progressFraction * 100).toInt()}% of ₹8K Target';
      targetSubText = coll >= 8000 ? 'Target Reached! 🎯' : '₹${AppFormatters.compactCurrency((8000 - coll).clamp(0.0, double.infinity))} remaining';
      subMetric1Title = 'TOTAL DUES';
      subMetric1Value = AppFormatters.compactCurrency(totalDues);
      onSubMetric1Tap = () => _navigate(context, tabIndex: 4, routeName: 'collections', fallbackScreen: CollectionsTab(onBack: () => Navigator.pop(context)));
      subMetric2Title = 'IN-HAND CASH';
      subMetric2Value = AppFormatters.compactCurrency(appState.inHandCash);
      onSubMetric2Tap = () => _showUpdateInHandBalanceDialog(context, appState);
    } else if (appState.isFieldSalesRole) {
      heroTitle = "Today's Bookings";
      heroIcon = Icons.shopping_bag_outlined;
      actionPillText = 'My Route';
      onActionPillTap = () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => VisitsTab(onBack: () => Navigator.pop(context))));
      };
      final currentSales = todaySales;
      mainMetricValue = AppFormatters.currency(currentSales);
      final totalV = totalVisits == 0 ? 15 : totalVisits;
      progressFraction = (visitsCompleted / totalV).clamp(0.0, 1.0);
      targetProgressText = '${(progressFraction * 100).toInt()}% Beat Coverage';
      targetSubText = '$visitsCompleted of $totalV Outlets Visited';
      subMetric1Title = 'VISITS';
      subMetric1Value = '${visitsCompleted.toString().padLeft(2, '0')} / ${totalV.toString().padLeft(2, '0')}';
      onSubMetric1Tap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitsTab(onBack: () => Navigator.pop(context))));
      subMetric2Title = 'OUTLETS';
      subMetric2Value = '${appState.shops.length} Active';
      onSubMetric2Tap = () => _navigate(context, tabIndex: 1, routeName: 'shops');
    } else if (appState.isDeliveryRole) {
      heroTitle = "Today's Deliveries";
      heroIcon = Icons.local_shipping_outlined;
      actionPillText = 'Trip Route';
      onActionPillTap = () {
        _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
      };
      final deliveredCount = appState.orders.where((o) => o.status.toLowerCase() == 'delivered').length;
      mainMetricValue = '$deliveredCount Delivered';
      final totalOrders = appState.orders.isEmpty ? 1 : appState.orders.length;
      progressFraction = (deliveredCount / totalOrders).clamp(0.0, 1.0);
      targetProgressText = '${(progressFraction * 100).toInt()}% Route Drops Completed';
      final pendingCount = appState.orders.where((o) => o.status.toLowerCase() != 'delivered').length;
      targetSubText = '$pendingCount Pending Drops';
      subMetric1Title = 'PENDING DROPS';
      subMetric1Value = '$pendingCount Orders';
      onSubMetric1Tap = () => _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
      subMetric2Title = 'PARCELS TOTAL';
      subMetric2Value = '${appState.orders.length} Dispatches';
      onSubMetric2Tap = () => _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
    } else if (appState.isStoreManagerRole) {
      heroTitle = "Warehouse Stock Status";
      heroIcon = Icons.warehouse_rounded;
      actionPillText = 'Stock Catalog';
      onActionPillTap = () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)));
      };
      mainMetricValue = '${appState.products.length} Active SKUs';
      final lowStock = appState.lowStockCount;
      progressFraction = ((appState.products.length - lowStock) / (appState.products.isEmpty ? 1 : appState.products.length)).clamp(0.0, 1.0);
      targetProgressText = '${(progressFraction * 100).toInt()}% In-Stock Fulfillment';
      targetSubText = '$lowStock Low Stock Alerts';
      subMetric1Title = 'LOW STOCK';
      subMetric1Value = '$lowStock SKUs';
      onSubMetric1Tap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)));
      subMetric2Title = 'TOTAL PRODUCTS';
      subMetric2Value = '${appState.products.length} SKUs';
      onSubMetric2Tap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)));
    } else {
      // Owner
      heroTitle = "Today's Sales";
      heroIcon = Icons.point_of_sale_rounded;
      actionPillText = 'Sales Data';
      onActionPillTap = () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const SalesDataScreen()));
      };
      final currentSales = todaySales;
      const dailyTarget = 10000.0;
      progressFraction = (currentSales / dailyTarget).clamp(0.0, 1.0);
      targetProgressText = '${(progressFraction * 100).toInt()}% of ₹${AppFormatters.compactCurrency(dailyTarget)} Daily Target';
      targetSubText = currentSales >= dailyTarget ? 'Goal Reached! 🎯' : '₹${AppFormatters.compactCurrency((dailyTarget - currentSales).clamp(0.0, double.infinity))} to target';
      mainMetricValue = AppFormatters.currency(todaySales);
      subMetric1Title = 'VISITS';
      subMetric1Value = '${visitsCompleted.toString().padLeft(2, '0')} / ${totalVisits.toString().padLeft(2, '0')}';
      onSubMetric1Tap = () => Navigator.push(context, MaterialPageRoute(builder: (_) => VisitsTab(onBack: () => Navigator.pop(context))));
      subMetric2Title = 'COLLECTION';
      subMetric2Value = AppFormatters.currency(todayCollections);
      onSubMetric2Tap = () => _navigate(context, tabIndex: 4, routeName: 'collections', fallbackScreen: CollectionsTab(onBack: () => Navigator.pop(context)));
    }

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E56E2), Color(0xFF173BBF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E56E2).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(heroIcon, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        heroTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onActionPillTap();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionPillText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onActionPillTap();
            },
            child: Text(
              mainMetricValue,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Daily Target Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressFraction,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFD500)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  targetProgressText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  targetSubText,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onSubMetric1Tap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subMetric1Title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subMetric1Value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: onSubMetric2Tap,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subMetric2Title,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            subMetric2Value,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (appState.isOwnerRole || appState.isAccountantRole) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments_outlined, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                            const SizedBox(width: 4),
                            Text(
                              'IN-HAND CASH',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(appState.inHandCash),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_outlined, size: 13, color: Colors.white.withValues(alpha: 0.85)),
                            const SizedBox(width: 4),
                            Text(
                              'IN-ACCOUNT',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          AppFormatters.currency(appState.inAccountBalance),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () => _showUpdateInHandBalanceDialog(context, appState),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, size: 12, color: Color(0xFF1E56E2)),
                          SizedBox(width: 4),
                          Text(
                            'Update',
                            style: TextStyle(
                              color: Color(0xFF1E56E2),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showUpdateInHandBalanceDialog(BuildContext context, AppState appState) {
    final inHandCtrl = TextEditingController(text: appState.inHandCash.toStringAsFixed(0));
    final inAccountCtrl = TextEditingController(text: appState.inAccountBalance.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1E56E2), size: 22),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Update Balance', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  Text('In-Hand Cash & Account Funds', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: inHandCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Cash In-Hand (₹)',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: inAccountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'In-Account Balance (₹)',
                  prefixIcon: const Icon(Icons.account_balance_outlined, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E56E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                final newCash = double.tryParse(inHandCtrl.text.trim()) ?? appState.inHandCash;
                final newAccount = double.tryParse(inAccountCtrl.text.trim()) ?? appState.inAccountBalance;
                appState.updateInHandAndAccountBalances(
                  inHandCash: newCash,
                  inAccountBalance: newAccount,
                );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('In-Hand and Account balances updated successfully!'),
                    backgroundColor: Color(0xFF059669),
                  ),
                );
              },
              child: const Text('Save Balances', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }

  // 2. Sales Milestone Banner (Screenshot 1 - Swipeable & Dismissible for today)
  Widget _buildMilestoneBanner(BuildContext context, AppState appState, {bool isDark = false}) {
    if (appState.isDailyNoticeDismissed('sales_milestone_20l')) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: ValueKey('sales_milestone_20l_${appState.getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        appState.dismissDailyNotice('sales_milestone_20l');
        _showUndoSnackBar(context, 'Sales milestone banner dismissed for today', () => appState.restoreDailyNotice('sales_milestone_20l'));
      },
      child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFFFFFDF5), Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFFB45309).withValues(alpha: 0.5) : const Color(0xFFFDE68A),
          width: 1.2,
        ),
        boxShadow: AppTheme.softShadow(blur: 14, dy: 4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD97706).withValues(alpha: 0.28),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.celebration_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '20 Lakhs Sales Milestone Reached!',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD97706),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'UNLOCKED',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 16,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          tooltip: 'Dismiss for today',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            appState.dismissDailyNotice('sales_milestone_20l');
                            _showUndoSnackBar(context, 'Sales milestone banner dismissed for today', () => appState.restoreDailyNotice('sales_milestone_20l'));
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Annual Turnover: ₹20.50 Lakhs • 82% of Annual Target Achieved',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: 0.82,
                    minHeight: 6,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFFDE68A),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD97706)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '82% of ₹25L Target',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  }

  // 3. Quick Action Cards (Role-Tailored, Zero Locked Badges)
  Widget _buildQuickActionCards(BuildContext context, {bool isDark = false}) {
    final appState = context.watch<AppState>();
    final duesCount = appState.shops.where((s) => s.currentOutstanding > 0).length;
    final lowStock = appState.lowStockCount;
    final pendingOrdersCount = appState.orders.where((o) => o.status.toLowerCase() != 'delivered').length;

    final List<_DashboardActionItem> items = [];

    if (appState.isOwnerRole) {
      // 1. Owner: Full Access (6 cards). Order: New Order, New Party, Estimate,
      //    Collect Dues, Stock / Inventory, Sales Return.
      items.add(_DashboardActionItem(
        icon: Icons.receipt_long_rounded,
        label: 'New Order',
        planFeature: 'order_taking',
        subtitle: 'Order Invoicing',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        badgeText: 'Instant',
        badgeColor: const Color(0xFF10B981),
        onTap: () {
          _navigate(
            context,
            tabIndex: 6,
            routeName: 'billing',
            fallbackScreen: OrderTakerFlow(
              isEmbedded: true,
              onOrderCompleted: () {
                Navigator.pop(context);
                _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
              },
            ),
          );
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.storefront_rounded,
        label: 'New Party',
        subtitle: 'Register Party',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        badgeText: '+ Add',
        badgeColor: const Color(0xFF1E56E2),
        onTap: () {
          HapticFeedback.lightImpact();
          showAddShopDialog(context);
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.request_quote_rounded,
        label: 'Estimate',
        planFeature: 'estimate_bills',
        subtitle: 'Rough quotation',
        bgColor: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        onTap: () {
          HapticFeedback.lightImpact();
          EstimatedBillDialog.show(context);
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.payments_outlined,
        label: 'Collect Dues',
        planFeature: 'collections',
        subtitle: 'Pending accounts',
        bgColor: const Color(0xFFEFFBF4),
        iconColor: const Color(0xFF059669),
        badgeText: duesCount > 0 ? '$duesCount Pending' : null,
        badgeColor: const Color(0xFFE11D48),
        onTap: () {
          _navigate(context, tabIndex: 4, routeName: 'collections', fallbackScreen: CollectionsTab(onBack: () => Navigator.pop(context)));
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.inventory_2_outlined,
        label: 'Stock / Inventory',
        subtitle: 'Real-time SKUs',
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF1E56E2),
        badgeText: lowStock > 0 ? '$lowStock Low' : null,
        badgeColor: const Color(0xFFD97706),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)),
          );
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.assignment_return_rounded,
        label: 'Sales Return',
        planFeature: 'sales_returns',
        subtitle: 'Restock & credit',
        bgColor: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
        onTap: () {
          HapticFeedback.lightImpact();
          showSalesReturnDialog(context);
        },
      ));
    } else if (appState.isAccountantRole) {
      // 2. Accountant: Billing, Collections, Quotations, Expenses
      items.add(_DashboardActionItem(
        icon: Icons.receipt_long_rounded,
        label: 'New Order',
        planFeature: 'order_taking',
        subtitle: 'Order Invoicing',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        badgeText: 'Instant',
        badgeColor: const Color(0xFF10B981),
        onTap: () {
          _navigate(
            context,
            tabIndex: 6,
            routeName: 'billing',
            fallbackScreen: OrderTakerFlow(
              isEmbedded: true,
              onOrderCompleted: () {
                Navigator.pop(context);
                _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
              },
            ),
          );
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.payments_outlined,
        label: 'Collect Dues',
        planFeature: 'collections',
        subtitle: 'Khata & Receipts',
        bgColor: const Color(0xFFEFFBF4),
        iconColor: const Color(0xFF059669),
        badgeText: duesCount > 0 ? '$duesCount Pending' : null,
        badgeColor: const Color(0xFFE11D48),
        onTap: () {
          _navigate(context, tabIndex: 4, routeName: 'collections', fallbackScreen: CollectionsTab(onBack: () => Navigator.pop(context)));
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.request_quote_rounded,
        label: 'Estimate',
        planFeature: 'estimate_bills',
        subtitle: 'Rough quotation',
        bgColor: const Color(0xFFFFFBEB),
        iconColor: const Color(0xFFD97706),
        onTap: () {
          HapticFeedback.lightImpact();
          EstimatedBillDialog.show(context);
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.receipt_rounded,
        label: 'Expenses',
        planFeature: 'expenses',
        subtitle: 'Petty Cash & Logs',
        bgColor: const Color(0xFFF5F3FF),
        iconColor: const Color(0xFF7C3AED),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ExpenseScreen()),
          );
        },
      ));
    } else if (appState.isFieldSalesRole) {
      // 3. Field Sales: New Shop, Take Order, Visits, Stock
      items.add(_DashboardActionItem(
        icon: Icons.storefront_rounded,
        label: 'New Party',
        subtitle: 'Register Party',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        badgeText: '+ Add',
        badgeColor: const Color(0xFF1E56E2),
        onTap: () {
          HapticFeedback.lightImpact();
          showAddShopDialog(context);
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.shopping_bag_outlined,
        label: 'Take Order',
        planFeature: 'order_taking',
        subtitle: 'Book shop order',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        badgeText: 'Active',
        badgeColor: const Color(0xFF10B981),
        onTap: () {
          _navigate(
            context,
            tabIndex: 6,
            routeName: 'billing',
            fallbackScreen: OrderTakerFlow(
              isEmbedded: true,
              onOrderCompleted: () {
                Navigator.pop(context);
                _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
              },
            ),
          );
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.location_on_outlined,
        label: 'My Visits',
        planFeature: 'visits',
        subtitle: 'Route & Beat Outlets',
        bgColor: const Color(0xFFEFFBF4),
        iconColor: const Color(0xFF059669),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VisitsTab(onBack: () => Navigator.pop(context))),
          );
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.inventory_2_outlined,
        label: 'Stock / Inventory',
        subtitle: 'Real-time SKUs',
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF1E56E2),
        badgeText: lowStock > 0 ? '$lowStock Low' : null,
        badgeColor: const Color(0xFFD97706),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)),
          );
        },
      ));
    } else if (appState.isDeliveryRole) {
      // 4. Delivery Staff: Active Dispatches, Delivery Proof, Retailer Directory, Sales Return
      items.add(_DashboardActionItem(
        icon: Icons.local_shipping_outlined,
        label: 'Active Dispatches',
        subtitle: 'Van delivery list',
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF1E56E2),
        badgeText: pendingOrdersCount > 0 ? '$pendingOrdersCount Drops' : null,
        badgeColor: const Color(0xFF1E56E2),
        onTap: () {
          _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.check_circle_outline_rounded,
        label: 'Delivery Proof',
        subtitle: 'Sign & complete drop',
        bgColor: const Color(0xFFEFFBF4),
        iconColor: const Color(0xFF059669),
        onTap: () {
          _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.storefront_rounded,
        label: 'Retailers Directory',
        subtitle: 'Party phone & map',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        onTap: () {
          _navigate(context, tabIndex: 1, routeName: 'shops');
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.assignment_return_rounded,
        label: 'Sales Return',
        planFeature: 'sales_returns',
        subtitle: 'RTO & return parcel',
        bgColor: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
        onTap: () {
          HapticFeedback.lightImpact();
          showSalesReturnDialog(context);
        },
      ));
    } else {
      // 5. Store Manager / Warehouse
      items.add(_DashboardActionItem(
        icon: Icons.inventory_2_outlined,
        label: 'Stock / Inventory',
        subtitle: 'Manage warehouse SKUs',
        bgColor: const Color(0xFFEFF6FF),
        iconColor: const Color(0xFF1E56E2),
        badgeText: lowStock > 0 ? '$lowStock Low' : null,
        badgeColor: const Color(0xFFD97706),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)),
          );
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.local_shipping_outlined,
        label: 'Dispatch Queue',
        subtitle: 'Verify outgoing stock',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        badgeText: pendingOrdersCount > 0 ? '$pendingOrdersCount Pending' : null,
        badgeColor: const Color(0xFF1E56E2),
        onTap: () {
          _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.assignment_return_rounded,
        label: 'Sales Return',
        planFeature: 'sales_returns',
        subtitle: 'Restock returned items',
        bgColor: const Color(0xFFFEF2F2),
        iconColor: const Color(0xFFDC2626),
        onTap: () {
          HapticFeedback.lightImpact();
          showSalesReturnDialog(context);
        },
      ));
      items.add(_DashboardActionItem(
        icon: Icons.storefront_rounded,
        label: 'Retailers Directory',
        subtitle: 'Party contacts',
        bgColor: const Color(0xFFF1F5FD),
        iconColor: const Color(0xFF1E56E2),
        onTap: () {
          _navigate(context, tabIndex: 1, routeName: 'shops');
        },
      ));
    }

    final columns = context.screenWidth >= 800 ? 4 : (context.screenWidth >= 600 ? 3 : 2);
    final List<Widget> rowWidgets = [];
    for (int i = 0; i < items.length; i += columns) {
      final rowItems = items.sublist(i, (i + columns > items.length) ? items.length : i + columns);

      rowWidgets.add(
        Row(
          children: List.generate(columns, (colIdx) {
            if (colIdx < rowItems.length) {
              final it = rowItems[colIdx];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: colIdx < columns - 1 ? 14 : 0),
                  child: _buildActionCard(
                    icon: it.icon,
                    label: it.label,
                    subtitle: it.subtitle,
                    bgColor: it.bgColor,
                    iconColor: it.iconColor,
                    badgeText: it.badgeText,
                    badgeColor: it.badgeColor,
                    planFeature: it.planFeature,
                    onTap: it.onTap,
                    isDark: isDark,
                  ),
                ),
              );
            } else {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: colIdx < columns - 1 ? 14 : 0),
                  child: const SizedBox.shrink(),
                ),
              );
            }
          }),
        ),
      );
      if (i + columns < items.length) {
        rowWidgets.add(const SizedBox(height: 14));
      }
    }

    return Column(children: rowWidgets);
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
    String? badgeText,
    Color? badgeColor,
    String? planFeature,
    bool isDark = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : bgColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : iconColor.withValues(alpha: 0.16),
          width: 1.0,
        ),
        boxShadow: AppTheme.softShadow(blur: 12, dy: 3),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
            child: Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : iconColor.withValues(alpha: 0.15),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: iconColor.withValues(alpha: 0.12),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, size: 22, color: iconColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (planFeature != null)
                  Positioned(
                    top: -8,
                    left: 0,
                    child: PlanCrownBadge(feature: planFeature, size: 13),
                  ),
                if (badgeText != null)
                  Positioned(
                    top: -8,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor ?? iconColor,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: (badgeColor ?? iconColor).withValues(alpha: 0.28),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 4. Pending Reminders Section (Dynamic from AppState, Swipeable & Dismissible for today)
  String _formatReminderDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final diffDays = dueDay.difference(today).inDays;

    if (diffDays < 0) {
      return 'Overdue by ${diffDays.abs()}d';
    } else if (diffDays == 0) {
      final diffHours = dueDate.difference(now).inHours;
      if (diffHours > 0) {
        return 'Due in ${diffHours}h';
      } else if (diffHours == 0) {
        final diffMinutes = dueDate.difference(now).inMinutes;
        return diffMinutes > 0 ? 'Due in ${diffMinutes}m' : 'Due now';
      } else {
        return 'Overdue today';
      }
    } else if (diffDays == 1) {
      return 'Due tomorrow';
    } else {
      return 'Due in ${diffDays}d';
    }
  }

  Widget _buildPendingRemindersSection(BuildContext context, AppState appState, {bool isDark = false}) {
    if (appState.isDailyNoticeDismissed('pending_reminders_section')) {
      return const SizedBox.shrink();
    }

    final List<_DashboardReminderItem> items = [];

    // 1. Dynamic User Reminders from appState.reminders (uncompleted)
    final uncompletedReminders = appState.reminders.where((r) => !r.isCompleted).toList();
    uncompletedReminders.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    for (final rem in uncompletedReminders) {
      final itemKey = (rem.reminderId == 'rem_001' || rem.description.toLowerCase().contains('balaji') || (rem.shopName != null && rem.shopName!.toLowerCase().contains('balaji')))
          ? 'reminder_balaji'
          : 'reminder_${rem.reminderId}';
      if (appState.isDailyNoticeDismissed(itemKey)) continue;

      final title = (rem.title != null && rem.title!.trim().isNotEmpty)
          ? rem.title!
          : ((rem.shopName != null && rem.shopName!.trim().isNotEmpty)
              ? rem.shopName!
              : (rem.description.isNotEmpty
                  ? rem.description
                  : (rem.purpose.isNotEmpty ? '${rem.purpose[0].toUpperCase()}${rem.purpose.substring(1)} Reminder' : 'Pending Task')));

      final now = DateTime.now();
      final isOverdue = rem.dueDate.isBefore(now);
      final dueString = _formatReminderDueDate(rem.dueDate);
      final subtitle = (rem.description.isNotEmpty && title != rem.description)
          ? '$dueString • ${rem.description}'
          : dueString;

      IconData icon;
      switch (rem.purpose.toLowerCase()) {
        case 'payment':
        case 'dues':
        case 'collection':
          icon = Icons.payments_rounded;
          break;
        case 'visit':
        case 'store_visit':
          icon = Icons.storefront_rounded;
          break;
        case 'reorder':
        case 'stock':
          icon = Icons.inventory_2_rounded;
          break;
        case 'cheque':
          icon = Icons.receipt_long_rounded;
          break;
        default:
          icon = Icons.notifications_active_rounded;
      }

      items.add(
        _DashboardReminderItem(
          key: itemKey,
          icon: icon,
          title: title,
          subtitle: subtitle,
          isWarning: isOverdue || rem.priority.toLowerCase() == 'high',
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RemindersScreen()),
            );
          },
          onDismiss: () {
            HapticFeedback.lightImpact();
            appState.dismissDailyNotice(itemKey);
            _showUndoSnackBar(
              context,
              'Reminder dismissed for today',
              () => appState.restoreDailyNotice(itemKey),
            );
          },
        ),
      );

      if (items.length >= 3) break;
    }

    // 2. Dynamic Low Stock Products (if space permits)
    if (items.length < 3) {
      final lowStockProducts = appState.products
          .where((p) => p.stockQuantity <= (p.lowStockAlertQty > 0 ? p.lowStockAlertQty : 10))
          .toList();
      lowStockProducts.sort((a, b) => a.stockQuantity.compareTo(b.stockQuantity));

      for (final p in lowStockProducts) {
        final itemKey = 'reminder_lowstock_${p.productId}';
        if (appState.isDailyNoticeDismissed(itemKey)) continue;

        items.add(
          _DashboardReminderItem(
            key: itemKey,
            icon: Icons.inventory_2_rounded,
            title: 'Low Stock: ${p.name}',
            subtitle: p.stockQuantity <= 0
                ? 'Out of stock (0 units)'
                : 'Only ${p.stockQuantity} units remaining',
            isWarning: true,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryTab(isStandalone: true)),
              );
            },
            onDismiss: () {
              HapticFeedback.lightImpact();
              appState.dismissDailyNotice(itemKey);
              _showUndoSnackBar(
                context,
                'Low stock alert dismissed for today',
                () => appState.restoreDailyNotice(itemKey),
              );
            },
          ),
        );

        if (items.length >= 3) break;
      }
    }

    // 3. Dynamic Outstanding Payment Dues (if space permits)
    if (items.length < 3) {
      final overdueShops = appState.shops
          .where((s) => s.currentOutstanding > 0)
          .toList();
      overdueShops.sort((a, b) => b.currentOutstanding.compareTo(a.currentOutstanding));

      for (final s in overdueShops) {
        final itemKey = 'reminder_due_${s.shopId}';
        if (appState.isDailyNoticeDismissed(itemKey)) continue;

        items.add(
          _DashboardReminderItem(
            key: itemKey,
            icon: Icons.payments_rounded,
            title: 'Payment Due: ${s.shopName}',
            subtitle: '${Formatters.currency(s.currentOutstanding)} outstanding balance',
            isWarning: false,
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: s)),
              );
            },
            onDismiss: () {
              HapticFeedback.lightImpact();
              appState.dismissDailyNotice(itemKey);
              _showUndoSnackBar(
                context,
                'Payment reminder dismissed for today',
                () => appState.restoreDailyNotice(itemKey),
              );
            },
          ),
        );

        if (items.length >= 3) break;
      }
    }

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: ValueKey('pending_reminders_section_${appState.getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        appState.dismissDailyNotice('pending_reminders_section');
        _showUndoSnackBar(context, 'Pending Reminders section dismissed for today', () => appState.restoreDailyNotice('pending_reminders_section'));
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: AppTheme.softShadow(blur: 14, dy: 4),
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pending Reminders',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RemindersScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'SEE ALL',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E56E2),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      tooltip: 'Dismiss for today',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        appState.dismissDailyNotice('pending_reminders_section');
                        _showUndoSnackBar(context, 'Pending Reminders dismissed for today', () => appState.restoreDailyNotice('pending_reminders_section'));
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), height: 1),
                ),
              Dismissible(
                key: ValueKey('${items[i].key}_${appState.getTodayDateString()}'),
                direction: DismissDirection.horizontal,
                background: _buildDismissBackground(isDark: isDark, alignRight: false),
                secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
                onDismissed: (direction) => items[i].onDismiss(),
                child: _buildReminderRow(
                  icon: items[i].icon,
                  title: items[i].title,
                  subtitle: items[i].subtitle,
                  isWarning: items[i].isWarning,
                  onTap: items[i].onTap,
                  onDismiss: items[i].onDismiss,
                  isDark: isDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReminderRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isWarning,
    required VoidCallback onTap,
    VoidCallback? onDismiss,
    bool isDark = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFBFDBFE).withValues(alpha: 0.5),
                ),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2), size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isWarning ? FontWeight.w700 : FontWeight.w500,
                      color: isWarning ? const Color(0xFFDC2626) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null) ...[
              IconButton(
                icon: Icon(Icons.clear_rounded, size: 16, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                tooltip: 'Dismiss for today',
                onPressed: onDismiss,
              ),
            ] else ...[
              Icon(Icons.chevron_right_rounded, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), size: 20),
            ],
          ],
        ),
      ),
    );
  }

  // 5. Top Performing Retailers Section (Screenshot 2)
  Widget _buildTopPerformingRetailersSection(BuildContext context, AppState appState, {bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Top Performing Retailers',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => _navigate(context, tabIndex: 1, routeName: 'shops'),
              child: Text(
                'View All (${appState.shops.length})',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E56E2),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (appState.shops.isNotEmpty)
          ...appState.shops.take(3).map((shop) {
            final monogram = shop.shopName.isNotEmpty ? shop.shopName[0].toUpperCase() : 'S';
            final orderCount = appState.orders.where((o) => o.shopId == shop.shopId).length;
            final totalShopSales = appState.orders
                .where((o) => o.shopId == shop.shopId)
                .fold<double>(0.0, (sum, o) => sum + o.grandTotal);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildRetailerPerformanceCard(
                monogram: monogram,
                name: shop.shopName,
                categoryAndOrders: '${shop.businessType ?? 'Retail'} • $orderCount Orders',
                amount: AppFormatters.currency(totalShopSales),
                dueText: shop.currentOutstanding > 0 ? 'Due: ${AppFormatters.currency(shop.currentOutstanding)}' : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ShopDetailScreen(shop: shop)),
                  );
                },
                isDark: isDark,
              ),
            );
          })
        else
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_outlined, color: Color(0xFF94A3B8), size: 22),
                ),
                const SizedBox(height: 10),
                Text(
                  'No Retailers Registered Yet',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Onboard retail outlets to track performance and orders',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildRetailerPerformanceCard({
    required String monogram,
    required String name,
    required String categoryAndOrders,
    required String amount,
    required String? dueText,
    required VoidCallback onTap,
    bool isDark = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: AppTheme.softShadow(blur: 14, dy: 4),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE), width: 1.0),
              ),
              alignment: Alignment.center,
              child: Text(
                monogram,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    categoryAndOrders,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  amount,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF16A34A),
                  ),
                ),
                if (dueText != null) ...[
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dueText,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Top Priority Operational & Business Alerts Hub (Right after top navbar)
  Widget _buildTopAlertsSection(
    BuildContext context,
    AppState appState,
    List<ShopModel> shopsWithDues,
    double totalDues,
    List<OrderModel> pendingOrders, {
    bool isDark = false,
  }) {
    final List<Widget> alertWidgets = [];

    // 1. Subscription / Account Restriction Alert
    if (appState.isSubscriptionExpired || appState.isAccountPausedOrCancelled) {
      if (!appState.isDailyNoticeDismissed('sub_alert')) {
        alertWidgets.add(
          _buildAlertCard(
            context: context,
            alertId: 'sub_alert',
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFDC2626),
            iconBg: const Color(0xFFFEE2E2),
            cardBg: const Color(0xFFFEF2F2),
            borderColor: const Color(0xFFFECACA),
            title: 'Account Alert: ${appState.subscriptionBadgeText}',
            titleColor: const Color(0xFF991B1B),
            subtitle: appState.isAccountPausedOrCancelled
                ? 'Account paused — contact SalesArmy support'
                : 'Read-only: view data & collect dues. Renew to create orders and bills',
            subtitleColor: const Color(0xFFB91C1C),
            actionLabel: 'Renew',
            actionColor: const Color(0xFFDC2626),
            actionBorderColor: const Color(0xFFFECACA),
            onAction: () {
              HapticFeedback.lightImpact();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlanAndPricingScreen()),
              );
            },
            onDismiss: () {
              appState.dismissDailyNotice('sub_alert');
              _showUndoSnackBar(context, 'Account alert dismissed for today', () => appState.restoreDailyNotice('sub_alert'));
            },
          ),
        );
      }
    }

    // 1a. Trial ended but grace days remain (admin: Settings → grace period)
    else if (appState.isInTrialGracePeriod && !appState.isDailyNoticeDismissed('sub_grace')) {
      final left = appState.trialGraceDaysLeft;
      alertWidgets.add(
        _buildAlertCard(
          context: context,
          alertId: 'sub_grace',
          icon: Icons.hourglass_bottom_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          cardBg: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          title: 'Free trial ended — $left day${left == 1 ? '' : 's'} of grace left',
          titleColor: const Color(0xFF92400E),
          subtitle: 'Choose a plan now; after the grace period the app becomes read-only',
          subtitleColor: const Color(0xFFB45309),
          actionLabel: 'View plans',
          actionColor: const Color(0xFFD97706),
          actionBorderColor: const Color(0xFFFDE68A),
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanAndPricingScreen()));
          },
          onDismiss: () {
            appState.dismissDailyNotice('sub_grace');
            _showUndoSnackBar(context, 'Reminder dismissed for today', () => appState.restoreDailyNotice('sub_grace'));
          },
        ),
      );
    }

    // 1b. Subscription Expiring Soon Alert (≤5 days left on active plan or trial)
    else if (appState.isSubscriptionExpiringSoon && !appState.isDailyNoticeDismissed('sub_expiring_soon')) {
      final days = appState.daysUntilSubscriptionEnds ?? 0;
      final isTrial = appState.isTrial;
      alertWidgets.add(
        _buildAlertCard(
          context: context,
          alertId: 'sub_expiring_soon',
          icon: Icons.schedule_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          cardBg: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          title: isTrial
              ? 'Trial ends in $days ${days == 1 ? "day" : "days"}'
              : 'Plan renewal in $days ${days == 1 ? "day" : "days"}',
          titleColor: const Color(0xFF92400E),
          subtitle: isTrial
              ? 'Subscribe to keep every feature after the trial'
              : 'Renew now to avoid interruption of premium features',
          subtitleColor: const Color(0xFFB45309),
          actionLabel: isTrial ? 'Choose plan' : 'Renew',
          actionColor: const Color(0xFFB45309),
          actionBorderColor: const Color(0xFFFDE68A),
          onAction: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PlanAndPricingScreen()),
            );
          },
          onDismiss: () {
            appState.dismissDailyNotice('sub_expiring_soon');
            _showUndoSnackBar(
              context,
              'Expiry reminder dismissed for today',
              () => appState.restoreDailyNotice('sub_expiring_soon'),
            );
          },
        ),
      );
    }

    // 2. Market Dues Alert (High-priority financial alert - Owner & Accountant only)
    if ((appState.isOwnerRole || appState.isAccountantRole) && shopsWithDues.isNotEmpty && totalDues > 0 && !appState.isDailyNoticeDismissed('market_dues')) {
      alertWidgets.add(
        _buildAlertCard(
          context: context,
          alertId: 'market_dues',
          icon: Icons.account_balance_wallet_rounded,
          iconColor: const Color(0xFFE11D48),
          iconBg: const Color(0xFFFFE4E6),
          cardBg: const Color(0xFFFFF1F2),
          borderColor: const Color(0xFFFFE4E6),
          title: 'Market Dues: ${AppFormatters.currency(totalDues)}',
          titleColor: const Color(0xFF9F1239),
          subtitle: 'Pending across ${shopsWithDues.length} retail accounts',
          subtitleColor: const Color(0xFFBE123C),
          actionLabel: 'Collect',
          actionColor: const Color(0xFFBE123C),
          actionBorderColor: const Color(0xFFFECDD3),
          onAction: () {
            _navigate(context, tabIndex: 4, routeName: 'collections', fallbackScreen: CollectionsTab(onBack: () => Navigator.pop(context)));
          },
          onDismiss: () {
            appState.dismissDailyNotice('market_dues');
            _showUndoSnackBar(context, 'Market Dues alert dismissed for today', () => appState.restoreDailyNotice('market_dues'));
          },
        ),
      );
    }

    // 3. Low Stock Inventory Alert (Owner, Store Manager & Accountant only)
    if ((appState.isOwnerRole || appState.isStoreManagerRole || appState.isAccountantRole) && appState.lowStockCount > 0 && !appState.isDailyNoticeDismissed('low_stock')) {
      alertWidgets.add(
        _buildAlertCard(
          context: context,
          alertId: 'low_stock',
          icon: Icons.inventory_2_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFEF3C7),
          cardBg: const Color(0xFFFFFBEB),
          borderColor: const Color(0xFFFDE68A),
          title: 'Low Stock Alert: ${appState.lowStockCount} SKU${appState.lowStockCount > 1 ? 's' : ''}',
          titleColor: const Color(0xFF92400E),
          subtitle: 'Depleted below safety threshold (${appState.lowStockCount} items)',
          subtitleColor: const Color(0xFFB45309),
          actionLabel: 'Restock',
          actionColor: const Color(0xFFB45309),
          actionBorderColor: const Color(0xFFFDE68A),
          onAction: () {
            _navigate(context, tabIndex: 3, routeName: 'inventory', fallbackScreen: const InventoryTab(isStandalone: true));
          },
          onDismiss: () {
            appState.dismissDailyNotice('low_stock');
            _showUndoSnackBar(context, 'Low Stock alert dismissed for today', () => appState.restoreDailyNotice('low_stock'));
          },
        ),
      );
    }

    // 4. Pending Orders / Deliveries Alert (Owner, Delivery & Store Manager only)
    if ((appState.isOwnerRole || appState.isDeliveryRole || appState.isStoreManagerRole) && pendingOrders.isNotEmpty && !appState.isDailyNoticeDismissed('pending_orders')) {
      alertWidgets.add(
        _buildAlertCard(
          context: context,
          alertId: 'pending_orders',
          icon: Icons.local_shipping_rounded,
          iconColor: const Color(0xFF1D4ED8),
          iconBg: const Color(0xFFDBEAFE),
          cardBg: const Color(0xFFEFF6FF),
          borderColor: const Color(0xFFBFDBFE),
          title: 'Pending Orders: ${pendingOrders.length} order${pendingOrders.length > 1 ? 's' : ''}',
          titleColor: const Color(0xFF1E40AF),
          subtitle: 'Awaiting dispatch & delivery confirmation',
          subtitleColor: const Color(0xFF1D4ED8),
          actionLabel: 'View Orders',
          actionColor: const Color(0xFF1D4ED8),
          actionBorderColor: const Color(0xFFBFDBFE),
          onAction: () {
            _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
          },
          onDismiss: () {
            appState.dismissDailyNotice('pending_orders');
            _showUndoSnackBar(context, 'Pending Orders alert dismissed for today', () => appState.restoreDailyNotice('pending_orders'));
          },
        ),
      );
    }

    if (alertWidgets.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...alertWidgets.map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: w,
          )),
        ],
      ),
    );
  }

  // Dismissible background helper for swipe-to-dismiss gesture
  Widget _buildDismissBackground({bool alignRight = false, bool isDark = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignRight) ...[
            Icon(Icons.delete_sweep_rounded, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626), size: 20),
            const SizedBox(width: 8),
            Text(
              'Dismiss for today',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
              ),
            ),
          ] else ...[
            Text(
              'Dismiss for today',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_sweep_rounded, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626), size: 20),
          ],
        ],
      ),
    );
  }

  // Generic Reusable Modern Alert Card Component (Swipeable & Dismissible for today)
  Widget _buildAlertCard({
    required BuildContext context,
    required String alertId,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Color cardBg,
    required Color borderColor,
    required String title,
    required Color titleColor,
    required String subtitle,
    required Color subtitleColor,
    required String actionLabel,
    required Color actionColor,
    required Color actionBorderColor,
    required VoidCallback onAction,
    required VoidCallback onDismiss,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dismissible(
      key: ValueKey('alert_${alertId}_${context.read<AppState>().getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        onDismiss();
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: onAction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: titleColor,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: actionBorderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: actionColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 14, color: actionColor),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: titleColor.withValues(alpha: 0.7)),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
              tooltip: 'Dismiss alert for today',
              onPressed: () {
                HapticFeedback.lightImpact();
                onDismiss();
              },
            ),
          ],
        ),
      ),
    );
  }


  // 5. Recent Activity / Today's Invoices Feed
  Widget _buildRecentInvoicesSection(BuildContext context, AppState appState, List<OrderModel> orders, {bool isDark = false}) {
    final recentOrders = orders.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  "Recent Invoices",
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (orders.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${orders.length}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (orders.isNotEmpty)
              InkWell(
                onTap: () => _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0)),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  child: Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (recentOrders.isEmpty)
          InkWell(
            onTap: () => _navigate(
              context,
              tabIndex: 6,
              routeName: 'billing',
              fallbackScreen: OrderTakerFlow(
                isEmbedded: true,
                onOrderCompleted: () {
                  Navigator.pop(context);
                  _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
                },
              ),
            ),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  width: 1.2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: Color(0xFF94A3B8), size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No Bills Created Today',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Tap "New Bill" to generate your first invoice',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...recentOrders.map((order) {
            ShopModel? matchedShop;
            try {
              matchedShop = appState.shops.firstWhere((s) => s.shopId == order.shopId);
            } catch (_) {
              matchedShop = null;
            }

            final shopName = matchedShop?.shopName ?? 'Retail Outlet';
            final orderTime = order.placedAt ?? order.createdAt;
            final isDelivered = order.status.toLowerCase() == 'delivered';

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  final invoiceMatch = appState.invoices.where((inv) => inv.orderId == order.orderId);
                  if (invoiceMatch.isNotEmpty) {
                    GstTaxInvoiceViewer.show(context, invoiceMatch.first);
                  } else {
                    _navigate(context, tabIndex: 2, routeName: 'orders', fallbackScreen: const OrdersTab(initialTabIndex: 0));
                  }
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: AppTheme.softShadow(blur: 10, dy: 3),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          shopName.isNotEmpty ? shopName[0].toUpperCase() : 'S',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shopName,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${orderTime != null ? AppFormatters.dateTime(orderTime) : 'Today'} • ${order.items.length} items',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            AppFormatters.currency(order.grandTotal),
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDelivered ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDelivered ? const Color(0xFFBBF7D0) : const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Text(
                              isDelivered ? 'Delivered' : order.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isDelivered ? const Color(0xFF15803D) : const Color(0xFFB45309),
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
          }),
      ],
    );
  }

  // Header (if showHeader is explicitly passed)
  Widget _buildHeader(BuildContext context, AppState appState) {
    final firmName = appState.tenant.firmName ?? 'SalesArmy Agency';
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            firmName.isNotEmpty ? firmName[0].toUpperCase() : 'S',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                firmName.length > 10 ? '${firmName.substring(0, 10)}...' : firmName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.circle, size: 6, color: Color(0xFF10B981)),
                  const SizedBox(width: 5),
                  Text(
                    appState.subscriptionBadgeText,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () => _showSettingsSheet(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.settings_rounded, color: Color(0xFF334155), size: 18),
          ),
        ),
      ],
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Hardware & Payment Settings'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog(context: context, builder: (_) => const HardwareSettingsModal());
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Agency & Enterprise Profile'),
                  subtitle: const Text('Manage profile, GST, subscription & staff'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileAndSettingsScreen(
                          initialTab: 0,
                          onSignOut: onSignOut,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF1E56E2)),
                  title: const Text('Daily Expenses', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Log operational costs, petrol, chai/food & receipts'),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ExpenseScreen()));
                  },
                ),
                Consumer<AppState>(
                  builder: (context, state, _) => SwitchListTile(
                    secondary: Icon(
                      state.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: state.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFFD97706),
                    ),
                    title: const Text('Dark Mode Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      state.isDarkMode ? 'ON (Dark Slate Canvas)' : 'OFF (Clean Light Canvas)',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.isDarkMode ? const Color(0xFF60A5FA) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: state.isDarkMode,
                    activeThumbColor: const Color(0xFF60A5FA),
                    onChanged: (val) {
                      state.toggleTheme();
                    },
                  ),
                ),
                Consumer<AppState>(
                  builder: (context, state, _) => SwitchListTile(
                    secondary: const Icon(Icons.receipt_long_rounded, color: Color(0xFF1E3A8A)),
                    title: const Text('Enable GST Billing', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      state.isGstBillingEnabled
                          ? 'ON (GST bills & invoices active)'
                          : 'OFF (GST bills hidden)',
                      style: TextStyle(
                        fontSize: 12,
                        color: state.isGstBillingEnabled ? const Color(0xFF059669) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    value: state.isGstBillingEnabled,
                    activeThumbColor: const Color(0xFF059669),
                    onChanged: (val) {
                      state.setGstBillingEnabled(val);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Upper-Left In-Hand Cash Bar (Swipeable & Dismissible for today)
  Widget _buildUpperLeftInHandCashBar(BuildContext context, AppState appState, {bool isDark = false}) {
    if (appState.isDailyNoticeDismissed('in_hand_cash_bar')) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: ValueKey('in_hand_cash_bar_${appState.getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        appState.dismissDailyNotice('in_hand_cash_bar');
        _showUndoSnackBar(context, 'In-Hand Cash card dismissed for today', () => appState.restoreDailyNotice('in_hand_cash_bar'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Upper Left Cash Icon & In-Hand Balance
            Expanded(
              flex: 5,
              child: InkWell(
                onTap: () => _showUpdateInHandBalanceDialog(context, appState),
                borderRadius: BorderRadius.circular(12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.payments_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D), size: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'IN-HAND',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    letterSpacing: 0.4,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Icon(Icons.edit_outlined, size: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            AppFormatters.currency(appState.inHandCash),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              height: 26,
              width: 1,
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: InkWell(
                onTap: () => _showUpdateInHandBalanceDialog(context, appState),
                borderRadius: BorderRadius.circular(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'IN-ACCOUNT',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      AppFormatters.currency(appState.inAccountBalance),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: 'Dismiss for today',
              onPressed: () {
                HapticFeedback.lightImpact();
                appState.dismissDailyNotice('in_hand_cash_bar');
                _showUndoSnackBar(context, 'In-Hand Cash card dismissed for today', () => appState.restoreDailyNotice('in_hand_cash_bar'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldSalesRouteBar(BuildContext context, AppState appState, {bool isDark = false}) {
    if (appState.isDailyNoticeDismissed('sales_route_bar')) {
      return const SizedBox.shrink();
    }
    final visitsCompleted = appState.visits.where((v) => v.checkOutTime != null).length;
    final totalVisits = appState.visits.isEmpty ? 15 : appState.visits.length;

    return Dismissible(
      key: ValueKey('sales_route_bar_${appState.getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        appState.dismissDailyNotice('sales_route_bar');
        _showUndoSnackBar(context, 'Route bar dismissed for today', () => appState.restoreDailyNotice('sales_route_bar'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.route_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "TODAY'S BEAT",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "North Beat (MG Road & Sector 12)",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.3) : const Color(0xFFDBEAFE)),
              ),
              child: Text(
                '$visitsCompleted/$totalVisits Visits',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E56E2),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: 'Dismiss for today',
              onPressed: () {
                HapticFeedback.lightImpact();
                appState.dismissDailyNotice('sales_route_bar');
                _showUndoSnackBar(context, 'Route bar dismissed for today', () => appState.restoreDailyNotice('sales_route_bar'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeliveryRouteBar(BuildContext context, AppState appState, List<OrderModel> pendingOrders, {bool isDark = false}) {
    if (appState.isDailyNoticeDismissed('delivery_route_bar')) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: ValueKey('delivery_route_bar_${appState.getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        appState.dismissDailyNotice('delivery_route_bar');
        _showUndoSnackBar(context, 'Delivery route bar dismissed for today', () => appState.restoreDailyNotice('delivery_route_bar'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF312E81).withValues(alpha: 0.5) : const Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.local_shipping_rounded, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "VAN ROUTE",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "Sector 4 & Industrial Hub",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
              ),
              child: Text(
                '${pendingOrders.length} Drops',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: 'Dismiss for today',
              onPressed: () {
                HapticFeedback.lightImpact();
                appState.dismissDailyNotice('delivery_route_bar');
                _showUndoSnackBar(context, 'Delivery route bar dismissed for today', () => appState.restoreDailyNotice('delivery_route_bar'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarehouseStatusBar(BuildContext context, AppState appState, {bool isDark = false}) {
    if (appState.isDailyNoticeDismissed('warehouse_status_bar')) {
      return const SizedBox.shrink();
    }

    return Dismissible(
      key: ValueKey('warehouse_status_bar_${appState.getTodayDateString()}'),
      direction: DismissDirection.horizontal,
      background: _buildDismissBackground(isDark: isDark, alignRight: false),
      secondaryBackground: _buildDismissBackground(isDark: isDark, alignRight: true),
      onDismissed: (direction) {
        HapticFeedback.lightImpact();
        appState.dismissDailyNotice('warehouse_status_bar');
        _showUndoSnackBar(context, 'Warehouse status bar dismissed for today', () => appState.restoreDailyNotice('warehouse_status_bar'));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF4C1D95).withValues(alpha: 0.5) : const Color(0xFFF3E8FF),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.warehouse_rounded, color: isDark ? const Color(0xFFA78BFA) : const Color(0xFF7C3AED), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "MAIN GODOWN SYNC",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "Central Godown A-12 (Active)",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.3) : const Color(0xFFFDE68A)),
              ),
              child: Text(
                '${appState.lowStockCount} Low SKUs',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB45309),
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
              tooltip: 'Dismiss for today',
              onPressed: () {
                HapticFeedback.lightImpact();
                appState.dismissDailyNotice('warehouse_status_bar');
                _showUndoSnackBar(context, 'Warehouse status bar dismissed for today', () => appState.restoreDailyNotice('warehouse_status_bar'));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleTopBar(BuildContext context, AppState appState, List<OrderModel> pendingOrders, {bool isDark = false}) {
    if (appState.isOwnerRole || appState.isAccountantRole) {
      return _buildUpperLeftInHandCashBar(context, appState, isDark: isDark);
    } else if (appState.isFieldSalesRole) {
      return _buildFieldSalesRouteBar(context, appState, isDark: isDark);
    } else if (appState.isDeliveryRole) {
      return _buildDeliveryRouteBar(context, appState, pendingOrders, isDark: isDark);
    } else if (appState.isStoreManagerRole) {
      return _buildWarehouseStatusBar(context, appState, isDark: isDark);
    }
    return _buildUpperLeftInHandCashBar(context, appState, isDark: isDark);
  }
}
