import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/responsive_helper.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/orders/presentation/dialogs/complete_and_bill_order_modal.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/collect_payment_dialog.dart';

class OrdersTab extends StatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onTakeNewOrder;
  final VoidCallback? onBack;
  const OrdersTab({super.key, this.initialTabIndex = 0, this.onTakeNewOrder, this.onBack});

  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with TickerProviderStateMixin {
  late TabController _tabController;

  void _handleTakeNewOrder(BuildContext context, AppState appState) {
    if (widget.onTakeNewOrder != null) {
      widget.onTakeNewOrder!();
      return;
    }

    if (!appState.isOwnerRole && !appState.isFieldSalesRole && !appState.canAccessModule('billing')) {
      showAppError(context, 'Access Restricted: Role (${appState.activeRole}) cannot create orders.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTakerFlow(
          onOrderCompleted: () {
            Navigator.pop(context);
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
  }

  // Orders list state
  String _ordersSearchQuery = '';
  String _ordersStatusFilter = 'All';
  bool _isCardView = true;

  // GST Bills list state
  String _invoicesSearchQuery = '';
  String _invoicesStatusFilter = 'All';

  AppState? _getAppState() {
    try {
      return Provider.of<AppState>(context);
    } catch (_) {
      return null;
    }
  }

  int _getAvailableSubTabsCount(AppState? appState) {
    if (appState == null) return 2;
    // Orders tab is available for all roles with orders access
    int count = 1;
    final canBill = (appState.isOwnerRole || (appState.canAccessModule('billing') && !appState.isFieldSalesRole)) &&
        !appState.isDeliveryRole &&
        !appState.isStoreManagerRole &&
        appState.isGstBillingEnabled;
    if (canBill) count++;
    return count.clamp(1, 2);
  }

  @override
  void initState() {
    super.initState();
    final initialLen = widget.initialTabIndex > 0 ? 2 : 1;
    _tabController = TabController(
      length: initialLen,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, initialLen - 1),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = _getAppState();
    final targetLength = _getAvailableSubTabsCount(appState);
    if (_tabController.length != targetLength) {
      final oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
        length: targetLength,
        vsync: this,
        initialIndex: oldIndex.clamp(0, targetLength - 1),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmCancelOrder(BuildContext context, AppState appState, OrderModel order, ShopModel shop) {
    HapticFeedback.mediumImpact();
    final isDark = appState.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cancel_outlined, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Cancel Order?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to cancel Order #${order.orderId} (${shop.shopName})?\n\nThe order status will be changed to Cancelled.',
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
              'Close',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await appState.updateOrderStatus(order.orderId, 'cancelled');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order #${order.orderId} marked as Cancelled'),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Cancel Order', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteOrder(BuildContext context, AppState appState, OrderModel order, ShopModel shop) {
    HapticFeedback.mediumImpact();
    final isDark = appState.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Delete Order?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete Order #${order.orderId} (${shop.shopName})?\n\nThis will remove the order permanently and adjust customer ledger dues.',
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
              'Close',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              HapticFeedback.mediumImpact();
              await appState.deleteOrder(order.orderId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Order #${order.orderId} deleted successfully'),
                    backgroundColor: const Color(0xFFDC2626),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Delete Order', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showEditOrderDialog(BuildContext context, AppState appState, OrderModel order) {
    String currentStatus = order.status;
    final noteCtrl = TextEditingController(text: order.deliveryNote ?? '');
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Edit Order', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order #${order.orderId}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  const Text('Order Status:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: currentStatus.toLowerCase(),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                      DropdownMenuItem(value: 'delivered', child: Text('Delivered')),
                      DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => currentStatus = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('Delivery Note:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Special instructions...', contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final now = DateTime.now();
                    final updated = order.copyWith(
                      status: currentStatus,
                      deliveryNote: noteCtrl.text.trim().isNotEmpty ? noteCtrl.text.trim() : null,
                      deliveredAt: (currentStatus == 'delivered' || currentStatus == 'completed') ? (order.deliveredAt ?? now) : (currentStatus == 'pending' ? null : order.deliveredAt),
                      updatedAt: now,
                    );
                    await appState.updateOrder(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Order #${order.orderId} updated!'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final orders = appState.orders;
    final invoices = appState.invoices;

    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      // Take New Order floating button removed (client request).
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getOrdersGradient(isDark),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              if (widget.onBack != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                  child: Row(
                    children: [
                      Material(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onBack?.call();
                          },
                          child: Tooltip(
                            message: 'Back to Dashboard',
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                boxShadow: AppTheme.softShadow(blur: 6, dy: 1),
                              ),
                              child: Icon(Icons.arrow_back_rounded, size: 20, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Orders & Dispatches',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              // Sub-Tabs Bar (Role-Tailored & Dynamically Filtered)
            Builder(
              builder: (ctx) {
                final canBill = (appState.isOwnerRole || (appState.canAccessModule('billing') && !appState.isFieldSalesRole)) &&
                    !appState.isDeliveryRole &&
                    !appState.isStoreManagerRole &&
                    appState.isGstBillingEnabled;

                final tabsList = <Tab>[];
                final viewsList = <Widget>[];

                // 1. Orders Tab (Available for all roles with role-tailored label)
                tabsList.add(
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          appState.isDeliveryRole
                              ? Icons.local_shipping_rounded
                              : (appState.isStoreManagerRole ? Icons.warehouse_rounded : Icons.inventory_2_outlined),
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            appState.isDeliveryRole
                                ? 'Deliveries'
                                : (appState.isStoreManagerRole ? 'Dispatches' : 'Orders'),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                viewsList.add(_buildOrdersListView(context, appState, orders, isDark));

                // 3. GST Bills Tab (Only for authorized billing roles)
                if (canBill) {
                  tabsList.add(
                    const Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_rounded, size: 15),
                          SizedBox(width: 4),
                          Flexible(child: Text('Bill', overflow: TextOverflow.ellipsis)),
                        ],
                      ),
                    ),
                  );
                  viewsList.add(_buildInvoicesListView(context, appState, invoices, isDark));
                }

                // If only 1 tab is available (Delivery Staff or Store Manager), show a role status capsule
                if (tabsList.length == 1) {
                  return Expanded(
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E56E2).withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  appState.isDeliveryRole ? Icons.local_shipping_rounded : Icons.warehouse_rounded,
                                  size: 16,
                                  color: const Color(0xFF1E56E2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  appState.isDeliveryRole
                                      ? 'Delivery & Dispatch Route Queue'
                                      : (appState.isStoreManagerRole
                                          ? 'Warehouse Dispatch & Stock Queue'
                                          : 'Orders Management Queue'),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E56E2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${orders.length} ACTIVE',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(child: viewsList.first),
                      ],
                    ),
                  );
                }

                // If multiple tabs are available, keep controller in sync and render capsule TabBar
                if (_tabController.length != tabsList.length) {
                  final oldIdx = _tabController.index;
                  _tabController.dispose();
                  _tabController = TabController(
                    length: tabsList.length,
                    vsync: this,
                    initialIndex: oldIdx.clamp(0, tabsList.length - 1),
                  );
                }

                return Expanded(
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: TabBar(
                          controller: _tabController,
                          indicator: BoxDecoration(
                            color: const Color(0xFF1E56E2),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E56E2).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelColor: Colors.white,
                          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          tabs: tabsList,
                        ),
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: viewsList,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  }

  // ==========================================
  // Tab 1: Orders List View
  // ==========================================
  Widget _buildOrdersListView(BuildContext context, AppState appState, List<OrderModel> allOrders, bool isDark) {
    final filtered = allOrders.where((o) {
      final s = o.status.toLowerCase();
      if (_ordersStatusFilter == 'Pending' && s != 'pending') {
        return false;
      }
      if (_ordersStatusFilter == 'Delivered' && s != 'delivered' && s != 'completed') {
        return false;
      }
      if (_ordersStatusFilter != 'All' && _ordersStatusFilter != 'Pending' && _ordersStatusFilter != 'Delivered' && s != _ordersStatusFilter.toLowerCase()) {
        return false;
      }
      final q = _ordersSearchQuery.toLowerCase();
      final shopMatches = appState.shops.where((s) => s.shopId == o.shopId);
      final shopName = shopMatches.isNotEmpty ? shopMatches.first.shopName : (o.shopId.isNotEmpty ? 'Shop #${o.shopId}' : 'Customer');
      return o.orderId.toLowerCase().contains(q) ||
          shopName.toLowerCase().contains(q) ||
          (o.deliveryNote ?? '').toLowerCase().contains(q);
    }).toList();

    final pendingCount = allOrders.where((o) => o.status.toLowerCase() == 'pending').length;
    final deliveredCount = allOrders.where((o) => o.status.toLowerCase() == 'delivered' || o.status.toLowerCase() == 'completed').length;
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.lightImpact();
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {});
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Field (Clean, Accessible, High Contrast)
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _ordersSearchQuery = val.trim()),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Search by Shop, Order # or Note...',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                    fontSize: 13.5,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 20,
                  ),
                  suffixIcon: _ordersSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          onPressed: () => setState(() => _ordersSearchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Filter Chips & View Toggle (Card vs List View)
            Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All (${allOrders.length})', 'All', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pending ($pendingCount)', 'Pending', isDark),
                        const SizedBox(width: 8),
                        _buildFilterChip('Delivered ($deliveredCount)', 'Delivered', isDark),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildViewToggle(
                  isCardView: _isCardView,
                  onChanged: (val) => setState(() => _isCardView = val),
                  isDark: isDark,
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Order Cards / List Items
            if (filtered.isEmpty)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 20),
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, size: 32, color: Color(0xFF3B82F6)),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No orders found',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _ordersSearchQuery.isNotEmpty || _ordersStatusFilter != 'All'
                          ? 'No orders match your filter criteria or search query.'
                          : 'No orders have been recorded yet. Take an order now!',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: [
                        if (_ordersSearchQuery.isNotEmpty || _ordersStatusFilter != 'All')
                          OutlinedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _ordersSearchQuery = '';
                                _ordersStatusFilter = 'All';
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Reset Filters'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1E56E2),
                              side: const BorderSide(color: Color(0xFFBFDBFE)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _handleTakeNewOrder(context, appState);
                          },
                          icon: const Icon(Icons.add_shopping_cart_rounded, size: 16, color: Colors.white),
                          label: const Text('Take New Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E56E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: ListView.separated(
                  key: ValueKey('orders_list_${_isCardView ? "card" : "list"}'),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => SizedBox(height: _isCardView ? 14 : 10),
                  itemBuilder: (context, idx) {
                    final order = filtered[idx];
                    final shopMatches = appState.shops.where((s) => s.shopId == order.shopId);
                    final shop = shopMatches.isNotEmpty
                        ? shopMatches.first
                        : (appState.shops.isNotEmpty
                            ? appState.shops.first
                            : ShopModel(
                                shopId: order.shopId,
                                shopName: 'Shop #${order.shopId}',
                                ownerName: 'Customer',
                                phone: '-',
                                address: 'Direct',
                              ));

                    return _isCardView
                        ? _buildOrderCard(context, appState, order, shop, isDark)
                        : _buildOrderListItem(context, appState, order, shop, isDark);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Card View for Orders (Clean, Modern, Accessible Architecture)
  Widget _buildOrderCard(BuildContext context, AppState appState, OrderModel order, ShopModel shop, bool isDark) {
    final isDelivered = order.status.toLowerCase() == 'delivered' || order.status.toLowerCase() == 'completed';
    final isCancelled = order.status.toLowerCase() == 'cancelled';
    final totalUnits = order.items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.25) : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Retailer Header: Store Avatar + Shop Name & Meta + Status Badge & Action Buttons (Responsive)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Store Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2563EB).withValues(alpha: 0.25)
                            : const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                          width: 0.8,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        shop.shopName.isNotEmpty ? shop.shopName[0].toUpperCase() : "S",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Shop Details & Order Meta
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shop.shopName,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                order.orderId,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                                ),
                              ),
                              Text(
                                ' • ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  'Order Placed: ${order.placedAt != null ? AppFormatters.dateTime(order.placedAt) : 'Today'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDelivered
                            ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                            : (isCancelled
                                ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2))
                                : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDelivered
                              ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                              : (isCancelled
                                  ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5))
                                  : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A))),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isDelivered
                                ? Icons.check_circle_rounded
                                : (isCancelled ? Icons.cancel_outlined : Icons.schedule_rounded),
                            size: 11.5,
                            color: isDelivered
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                : (isCancelled
                                    ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                    : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))),
                          ),
                          const SizedBox(width: 3.5),
                          Text(
                            isDelivered ? 'Delivered' : (isCancelled ? 'Cancelled' : 'Pending'),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDelivered
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                  : (isCancelled
                                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                      : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Action Buttons Row: Cancel only
                if (!isCancelled)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmCancelOrder(context, appState, order, shop),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF7F1D1D).withValues(alpha: 0.25)
                                  : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFFEF4444).withValues(alpha: 0.35)
                                    : const Color(0xFFFECACA),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cancel_outlined,
                                  size: 12.5,
                                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 2. Delivery Note (if present)
          if (order.deliveryNote != null && order.deliveryNote!.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.notes_rounded, size: 12, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      order.deliveryNote!,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF7DD3FC) : const Color(0xFF0369A1),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Clean Order Items & Total Summary Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.35) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155).withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Items Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${order.items.length} ${order.items.length == 1 ? "Product" : "Products"} • $totalUnits Units',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                        ),
                        if (order.items.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            order.items.map((i) => '${i.productName} (x${i.quantity})').join(', '),
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Total Amount
                  Text(
                    AppFormatters.currency(order.grandTotal),
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Quick Print Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final invoiceMatch = appState.invoices.where((inv) => inv.orderId == order.orderId);
                        if (invoiceMatch.isNotEmpty) {
                          PrinterService.instance.printInvoice(invoiceMatch.first, context: context);
                        } else {
                          PrinterService.instance.printOrder(order, shop: shop, context: context);
                        }
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.print_rounded, size: 13, color: isDark ? const Color(0xFF93C5FA) : const Color(0xFF1D4ED8)),
                            const SizedBox(width: 3.5),
                            Text(
                              'Print',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF93C5FA) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tier 2: Accessible Full-Width Action Buttons (Role-Tailored: Deliver, View Bill)
          Builder(
            builder: (ctx) {
              final actionWidgets = <Widget>[];

              // 1. Deliver / Dispatch button
              if (!isDelivered) {
                if (appState.isStoreManagerRole) {
                  // Store Manager: Dispatch / Fulfill
                  actionWidgets.add(
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            appState.updateOrderStatus(order.orderId, 'dispatched');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order ${order.orderId} marked as Dispatched!'),
                                backgroundColor: const Color(0xFF1E56E2),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E56E2), Color(0xFF173BBF)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E56E2).withValues(alpha: 0.25),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.local_shipping_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'Dispatch',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else {
                  // Delivery Staff / Owner / Field Sales: Deliver
                  actionWidgets.add(
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            appState.updateOrderStatus(order.orderId, 'completed');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order ${order.orderId} marked as Completed!'),
                                backgroundColor: const Color(0xFF059669),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF059669), Color(0xFF047857)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF059669).withValues(alpha: 0.25),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'Deliver',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // 2. Billing actions (View Bill if already billed, or Generate Bill if unbilled)
              final invoiceMatch = appState.invoices.where((inv) => inv.orderId == order.orderId);
              final hasInvoice = invoiceMatch.isNotEmpty;

              final canAccessBilling = appState.isOwnerRole ||
                  appState.canAccessModule('billing') ||
                  appState.isFieldSalesRole ||
                  appState.isAccountantRole;

              if (canAccessBilling && !appState.isDeliveryRole && !appState.isStoreManagerRole) {
                if (actionWidgets.isNotEmpty) actionWidgets.add(const SizedBox(width: 8));

                if (hasInvoice) {
                  // View existing bill
                  final invoice = invoiceMatch.first;
                  actionWidgets.add(
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GstTaxInvoiceViewer(invoice: invoice),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E56E2),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E56E2).withValues(alpha: 0.25),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'View Bill',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                } else if (!isCancelled) {
                  // Generate bill for unbilled order
                  actionWidgets.add(
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.mediumImpact();
                            final cartMap = <String, int>{};
                            for (final item in order.items) {
                              cartMap[item.productId] = (cartMap[item.productId] ?? 0) + item.quantity;
                            }
                            CompleteAndBillOrderModal.show(
                              context,
                              destinationShop: shop,
                              cartQuantities: cartMap,
                              deliveryNote: order.deliveryNote,
                              existingOrder: order,
                              onOrderCompleted: (ord, inv) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Bill ${inv?.invoiceNumber ?? ""} generated for Order ${ord.orderId}!'),
                                    backgroundColor: const Color(0xFF059669),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                if (inv != null) {
                                  GstTaxInvoiceViewer.show(context, inv);
                                }
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E56E2),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1E56E2).withValues(alpha: 0.25),
                                  blurRadius: 5,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_rounded, size: 15, color: Colors.white),
                                SizedBox(width: 5),
                                Text(
                                  'Generate Bill',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }

              // 3. Collect Payment — opens the same Collect Payment dialog used
              //    on the Collections page, prefilled with this order's due.
              final orderDue = appState.getOrderDueAmount(order);
              if (!isCancelled && orderDue > 0.009 && !appState.isStoreManagerRole) {
                if (actionWidgets.isNotEmpty) actionWidgets.add(const SizedBox(width: 8));
                actionWidgets.add(
                  Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          showGatewayPaymentDialog(
                            context,
                            shop,
                            initialAmount: orderDue,
                            // Billed orders are paid against their bill number.
                            orderId: hasInvoice ? invoiceMatch.first.invoiceNumber : order.orderId,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0)),
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.payments_outlined, size: 15, color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857)),
                                const SizedBox(width: 5),
                                Text(
                                  'Collect Payment',
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF047857),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }

              if (actionWidgets.isEmpty) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Row(
                  children: actionWidgets,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // Refined Compact List View for Orders (Clean, Accessible)
  Widget _buildOrderListItem(BuildContext context, AppState appState, OrderModel order, ShopModel shop, bool isDark) {
    final isDelivered = order.status.toLowerCase() == 'delivered' || order.status.toLowerCase() == 'completed';
    final isCancelled = order.status.toLowerCase() == 'cancelled';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            final invoiceMatch = appState.invoices.where((inv) => inv.orderId == order.orderId);
            if (invoiceMatch.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GstTaxInvoiceViewer(invoice: invoiceMatch.first),
                ),
              );
            } else {
              final cartMap = <String, int>{};
              for (final item in order.items) {
                cartMap[item.productId] = (cartMap[item.productId] ?? 0) + item.quantity;
              }
              CompleteAndBillOrderModal.show(
                context,
                destinationShop: shop,
                cartQuantities: cartMap,
                deliveryNote: order.deliveryNote,
                existingOrder: order,
                onOrderCompleted: (ord, inv) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bill ${inv?.invoiceNumber ?? ""} generated for Order ${ord.orderId}!'),
                      backgroundColor: const Color(0xFF059669),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  if (inv != null) {
                    GstTaxInvoiceViewer.show(context, inv);
                  }
                },
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Circular Order Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 22,
                      color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            order.orderId,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isDelivered
                                  ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                                  : (isCancelled
                                      ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.5) : const Color(0xFFFEE2E2))
                                      : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7))),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isDelivered
                                    ? (isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC))
                                    : (isCancelled
                                        ? (isDark ? const Color(0xFFDC2626) : const Color(0xFFFCA5A5))
                                        : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A))),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDelivered
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                        : (isCancelled
                                            ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))),
                                  ),
                                ),
                                const SizedBox(width: 3.5),
                                Text(
                                  isDelivered ? 'Completed' : (isCancelled ? 'Cancelled' : 'Pending'),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: isDelivered
                                        ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                        : (isCancelled
                                            ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                            : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${shop.shopName} • ${order.items.length} items',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        order.placedAt != null ? AppFormatters.dateTime(order.placedAt) : "Today",
                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      AppFormatters.currency(order.grandTotal),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF10B981) : const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isDelivered && !isCancelled) ...[
                          InkWell(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              appState.updateOrderStatus(order.orderId, 'completed');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Order ${order.orderId} marked as Completed!'),
                                  backgroundColor: const Color(0xFF059669),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF059669),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 12, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Deliver',
                                    style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final invoiceMatch = appState.invoices.where((inv) => inv.orderId == order.orderId);
                            if (invoiceMatch.isNotEmpty) {
                              PrinterService.instance.printInvoice(invoiceMatch.first, context: context);
                            } else {
                              PrinterService.instance.printOrder(order, shop: shop, context: context);
                            }
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.all(5.5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                            ),
                            child: Icon(Icons.print_rounded, size: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                          ),
                        ),
                        const SizedBox(width: 5),
                        if (!isCancelled) ...[
                          InkWell(
                            onTap: () => _confirmCancelOrder(context, appState, order, shop),
                            borderRadius: BorderRadius.circular(6),
                            child: Tooltip(
                              message: 'Cancel Order',
                              child: Container(
                                padding: const EdgeInsets.all(5.5),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.25) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: isDark ? const Color(0xFFEF4444).withValues(alpha: 0.3) : const Color(0xFFFECACA)),
                                ),
                                child: Icon(Icons.cancel_outlined, size: 13, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF1D4ED8) : const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'View',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                              ),
                              const SizedBox(width: 2),
                              Icon(Icons.arrow_forward_ios_rounded, size: 10, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Reusable Card vs List View Toggle Capsule
  Widget _buildViewToggle({
    required bool isCardView,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card View Icon
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(true);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: isCardView ? const Color(0xFF1D4ED8) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: isCardView ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // List View Icon
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(false);
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: !isCardView ? const Color(0xFF1D4ED8) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.view_list_rounded,
                size: 16,
                color: !isCardView ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, bool isDark) {
    final isSelected = _ordersStatusFilter == value;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _ordersStatusFilter = value);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E56E2).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }

  void _confirmDeleteInvoice(BuildContext context, AppState appState, InvoiceModel inv) {
    final isDark = appState.isDarkMode;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Delete Bill?',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete Invoice ${inv.invoiceNumber}?',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• Shop: ${inv.shopName}', style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                    const SizedBox(height: 4),
                    Text('• Amount: ${AppFormatters.currency(inv.grandTotal)} (Due: ${AppFormatters.currency(inv.dueAmount)})', style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569))),
                    const SizedBox(height: 4),
                    const Text('• Reverses customer dues in Khata', style: TextStyle(fontSize: 12.5, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('• Restores ${inv.items.length} item(s) back into Inventory Stock', style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await appState.deleteInvoice(inv.invoiceId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bill ${inv.invoiceNumber} deleted and inventory restored.'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              child: const Text('Delete Bill', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // ==========================================
  // Tab 3: GST Bills List View (Matching Screenshot 4)
  // ==========================================
  Widget _buildInvoicesListView(BuildContext context, AppState appState, List<InvoiceModel> allInvoices, bool isDark) {
    final filtered = allInvoices.where((inv) {
      if (_invoicesStatusFilter != 'All') {
        if (_invoicesStatusFilter == 'GST Only') {
          if (inv.invoiceType != 'GST') return false;
        } else if (inv.paymentStatus.toLowerCase() != _invoicesStatusFilter.toLowerCase()) {
          return false;
        }
      }
      final q = _invoicesSearchQuery.toLowerCase();
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          (inv.buyer['shopName'] ?? '').toLowerCase().contains(q) ||
          (inv.buyer['gstin'] ?? '').toLowerCase().contains(q);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Bar: Search by Invoice #, Shop, or GSTIN...
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: (val) => setState(() => _invoicesSearchQuery = val.trim()),
              style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search by Invoice #, Shop, or GSTIN...',
                hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
                prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                suffixIcon: _invoicesSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        onPressed: () => setState(() => _invoicesSearchQuery = ''),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips & View Toggle (Card vs List View)
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildInvoiceFilterChip('All', 'All', isDark),
                      const SizedBox(width: 6),
                      _buildInvoiceFilterChip('Paid', 'paid', isDark),
                      const SizedBox(width: 6),
                      _buildInvoiceFilterChip('Partial', 'partial', isDark),
                      const SizedBox(width: 6),
                      _buildInvoiceFilterChip('Unpaid', 'unpaid', isDark),
                      const SizedBox(width: 6),
                      _buildInvoiceFilterChip('GST Only', 'GST Only', isDark),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _buildViewToggle(
                isCardView: _isCardView,
                onChanged: (val) => setState(() => _isCardView = val),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Invoices List / Cards
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text('No GST invoices found', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => SizedBox(height: _isCardView ? 12 : 8),
              itemBuilder: (context, idx) {
                final inv = filtered[idx];
                return _isCardView
                    ? _buildInvoiceCard(context, appState, inv, isDark)
                    : _buildInvoiceListItem(context, inv, isDark);
              },
            ),
        ],
      ),
    );
  }

  // Card View for GST Invoices
  Widget _buildInvoiceCard(BuildContext context, AppState appState, InvoiceModel inv, bool isDark) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (_) => GstTaxInvoiceViewer(invoice: inv),
        );
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.0),
          boxShadow: isDark
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 3))]
              : [
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: const Color(0xFF1E293B).withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Invoice # + GST Tax Invoice badge + Amount (Responsive & Overflow-Safe)
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          inv.invoiceNumber,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: context.isCompact ? 14 : 15.5,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'GST Tax Invoice',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            fontSize: context.isCompact ? 9.5 : 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppFormatters.currency(inv.grandTotal),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: context.isCompact ? 14 : 15.5,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Shop Name + Payment Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    inv.buyer['shopName'] ?? 'Shree Ganesh Kirana & General Store',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: inv.paymentStatus.toLowerCase() == 'paid'
                        ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                        : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    inv.paymentStatus.isNotEmpty
                        ? '${inv.paymentStatus[0].toUpperCase()}${inv.paymentStatus.substring(1)}'
                        : 'Partial',
                    style: TextStyle(
                      color: inv.paymentStatus.toLowerCase() == 'paid'
                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                          : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Row 3: Timestamp
            Text(
              AppFormatters.dateTime(inv.invoiceDate),
              style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),

            // Row 4: Taxable/Paid/Due on left (Expanded), Quick Actions on right
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Taxable: ${AppFormatters.currency(inv.taxableSubtotal)} • Tax: ${AppFormatters.currency(inv.totalGst)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Paid: ${AppFormatters.currency(inv.paidAmount)} • Due: ${AppFormatters.currency(inv.balanceDue)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: inv.balanceDue > 0 ? (isDark ? const Color(0xFFF59E0B) : const Color(0xFFD97706)) : (isDark ? const Color(0xFF10B981) : const Color(0xFF059669)),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action Buttons
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Print button
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        PrinterService.instance.printInvoice(inv, context: context);
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.print_rounded,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                          size: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // GST Bill button
                    InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => GstTaxInvoiceViewer(invoice: inv),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.description_outlined, size: 14, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            const SizedBox(width: 4),
                            Text(
                              'Bill',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Delete Bill button
                    InkWell(
                      onTap: () => _confirmDeleteInvoice(context, appState, inv),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFFDC2626).withValues(alpha: 0.4) : const Color(0xFFFECACA)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Compact List View for GST Invoices
  Widget _buildInvoiceListItem(BuildContext context, InvoiceModel inv, bool isDark) {
    final isPaid = inv.paymentStatus.toLowerCase() == 'paid';
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        showDialog(
          context: context,
          builder: (_) => GstTaxInvoiceViewer(invoice: inv),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : const Color(0xFF0F172A).withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(Icons.receipt_long_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        inv.invoiceNumber,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isPaid
                              ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                              : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFEF3C7)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPaid ? 'Paid' : 'Partial',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPaid
                                ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inv.buyer['shopName'] ?? 'Kirana Store',
                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  AppFormatters.currency(inv.grandTotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        PrinterService.instance.printInvoice(inv, context: context);
                      },
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(Icons.print_rounded, size: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Bill', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_forward_ios_rounded, size: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoiceFilterChip(String label, String value, bool isDark) {
    final isSelected = _invoicesStatusFilter.toLowerCase() == value.toLowerCase();
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _invoicesStatusFilter = value);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1E56E2))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}
