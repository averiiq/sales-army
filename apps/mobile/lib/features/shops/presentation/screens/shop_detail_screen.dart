import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/visits/data/models/reminder_model.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/ledger_report_modal.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/collect_payment_dialog.dart';
import 'package:salesarmy/features/shops/presentation/screens/create_shop_screen.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

class ShopDetailScreen extends StatefulWidget {
  final ShopModel shop;
  final Function(ShopModel)? onStartOrder;

  const ShopDetailScreen({
    super.key,
    required this.shop,
    this.onStartOrder,
  });

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> with TickerProviderStateMixin {
  late TabController _tabController;

  AppState? _getAppState() {
    try {
      return Provider.of<AppState>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  int _calculateSubTabsCount(AppState? appState) {
    if (appState == null) return 2;
    int count = 2; // Overview & Orders are standard
    final canAccessBilling = (appState.isOwnerRole || (appState.canAccessModule('billing') && !appState.isFieldSalesRole)) &&
        !appState.isDeliveryRole &&
        !appState.isStoreManagerRole &&
        appState.isGstBillingEnabled;
    final canAccessPayments = (appState.isOwnerRole || appState.canAccessModule('accounts') || appState.canAccessModule('collections')) &&
        !appState.isStoreManagerRole;
    if (canAccessBilling) count++;
    if (canAccessPayments) count++;
    return count.clamp(2, 4);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = _getAppState();
    final targetLength = _calculateSubTabsCount(appState);
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

  void _showCollectPaymentDialog(ShopModel shop) {
    showCollectPaymentDialog(context, shop);
  }

  void _showScheduleVisitDialog(ShopModel shop) {
    final noteCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Schedule Visit Reminder',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFF2563EB)),
                      title: Text(
                        AppFormatters.date(selectedDate),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: Text(
                        'Tap to pick date',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedDate = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteCtrl,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Follow-up Purpose / Note',
                        hintText: 'e.g. Routine field beat visit and dues collection',
                        labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E56E2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        final rem = ReminderModel(
                          reminderId: 'rem_${DateTime.now().millisecondsSinceEpoch}',
                          shopId: shop.shopId,
                          assignedToUid: 'rep_user',
                          dueDate: selectedDate,
                          description: 'Visit ${shop.shopName}: ${noteCtrl.text.trim()}',
                        );
                        if (!FeatureGate.allowWrite(context, feature: 'visits')) return;
                        context.read<AppState>().addReminder(rem);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Visit reminder scheduled!'), backgroundColor: Color(0xFF059669)),
                        );
                      },
                      child: const Text('Save Reminder', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _startOrder(ShopModel currentShop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTakerFlow(
          initialShop: currentShop,
          onOrderCompleted: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final currentShop = appState.shops.firstWhere(
      (s) => s.shopId == widget.shop.shopId,
      orElse: () => widget.shop,
    );

    final shopOrders = appState.orders.where((o) => o.shopId == currentShop.shopId).toList();
    final shopInvoices = appState.invoices.where((i) => i.shopId == currentShop.shopId).toList();
    final shopLedger = appState.ledgerEntries.where((l) => l.shopId == currentShop.shopId).toList();
    final totalSales = shopInvoices.fold(0.0, (sum, i) => sum + i.grandTotal);
    final hasDues = currentShop.currentOutstanding > 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              currentShop.shopName,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${currentShop.ownerName} • ${currentShop.sellerCategory ?? "Retailer"} (${currentShop.businessType ?? "Kirana"})',
              style: TextStyle(
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          // 1. Orders Report & Khata Ledger (Owner & Authorized Accounting Roles Only)
          if (appState.isOwnerRole || appState.canAccessModule('reports') || appState.canAccessModule('accounts')) ...[
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded, color: Color(0xFF1E56E2), size: 22),
              tooltip: 'Orders Statement',
              onPressed: () {
                HapticFeedback.lightImpact();
                LedgerReportModal.open(
                  context,
                  initialIsKhata: false,
                  initialShopId: currentShop.shopId,
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.menu_book_rounded, color: Color(0xFF16A34A), size: 21),
              tooltip: 'Khata Ledger',
              onPressed: () {
                HapticFeedback.lightImpact();
                LedgerReportModal.open(
                  context,
                  initialIsKhata: true,
                  initialShopId: currentShop.shopId,
                );
              },
            ),
          ],

          // 3. Call Store
          if (currentShop.phone != null && currentShop.phone!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.phone_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), size: 20),
              tooltip: 'Call Store',
              onPressed: () {
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Calling ${currentShop.shopName} (${currentShop.phone})...')),
                );
              },
            ),

          // Edit Outlet Button
          IconButton(
            icon: Icon(Icons.edit_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), size: 20),
            tooltip: 'Edit Outlet',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CreateShopScreen(initialShop: currentShop)),
              );
            },
          ),

          // 4. Secondary Actions Menu
          PopupMenuButton<String>(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            icon: Icon(Icons.more_vert_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569), size: 22),
            onSelected: (val) {
              if (val == 'edit_shop') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CreateShopScreen(initialShop: currentShop)),
                );
              } else if (val == 'delete_shop') {
                _confirmDeleteShop(context, currentShop);
              } else if (val == 'whatsapp') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Opening WhatsApp for ${currentShop.shopName}...')),
                );
              } else if (val == 'navigate_gps') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening GPS route navigation...')),
                );
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'edit_shop',
                child: Row(
                  children: [
                    const Icon(Icons.edit_rounded, size: 18, color: Color(0xFF1E56E2)),
                    const SizedBox(width: 10),
                    Text(
                      'Edit Outlet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete_shop',
                child: const Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFDC2626)),
                    SizedBox(width: 10),
                    Text(
                      'Delete Outlet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'whatsapp',
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 10),
                    Text(
                      'Chat on WhatsApp',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'navigate_gps',
                child: Row(
                  children: [
                    Icon(Icons.navigation_outlined, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    const SizedBox(width: 10),
                    Text(
                      'Open in Google Maps',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Retailer Hero Card (Screenshots 3 & 4)
          Container(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top Row: Store Graphic, Title, Monthly Tag
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2563EB) : const Color(0xFFDBEAFE),
                            width: 1.5,
                          ),
                          image: currentShop.imageUrl != null && currentShop.imageUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: AppImageHelper.getImageProvider(currentShop.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        alignment: Alignment.center,
                        child: currentShop.imageUrl == null || currentShop.imageUrl!.isEmpty
                            ? Icon(
                                Icons.store_mall_directory_rounded,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                                size: 26,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    currentShop.shopName,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Monthly',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Prop: ${currentShop.ownerName} • ${currentShop.sellerCategory ?? "Retailer"} (${currentShop.businessType ?? "General"})',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (currentShop.address != null && currentShop.address!.trim().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      currentShop.address!.trim(),
                                      style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 3 Financial Metric Columns (Total Sales, Orders Placed, Outstanding)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Total Sales
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Sales',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppFormatters.compactCurrency(totalSales),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 26, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                        // Orders Placed
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Orders Placed',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${shopOrders.length}',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Container(width: 1, height: 26, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                        // Outstanding
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Outstanding',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasDues ? AppFormatters.compactCurrency(currentShop.currentOutstanding) : '₹0',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: hasDues
                                        ? const Color(0xFFEF4444)
                                        : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2 Quick Action Buttons: [Schedule Reminder] [Call Owner]
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _showScheduleVisitDialog(currentShop);
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5FD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 15, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
                                const SizedBox(width: 6),
                                Text(
                                  'Schedule Reminder',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Calling ${currentShop.ownerName} (${currentShop.phone ?? ""})...')),
                            );
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5FD),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.phone_rounded, size: 15, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
                                const SizedBox(width: 6),
                                Text(
                                  'Call Owner',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
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
          ),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

          // 2. Tab Bar Header & Views (Role-Tailored)
          Builder(
            builder: (ctx) {
              final canAccessBilling = (appState.isOwnerRole || (appState.canAccessModule('billing') && !appState.isFieldSalesRole)) &&
                  !appState.isDeliveryRole &&
                  !appState.isStoreManagerRole &&
                  appState.isGstBillingEnabled;
              final canAccessPayments = (appState.isOwnerRole || appState.canAccessModule('accounts') || appState.canAccessModule('collections')) &&
                  !appState.isStoreManagerRole;

              final detailTabs = <Widget>[
                const Tab(text: 'Overview & Notes'),
                Tab(text: appState.isDeliveryRole ? 'Deliveries (${shopOrders.length})' : 'Orders (${shopOrders.length})'),
                if (canAccessBilling) Tab(text: 'Bills (${shopInvoices.length})'),
                if (canAccessPayments) Tab(text: 'Payments (${shopLedger.length})'),
              ];

              final detailViews = <Widget>[
                _buildOverviewTab(currentShop),
                _buildOrdersTab(shopOrders),
                if (canAccessBilling) _buildBillsTab(shopInvoices),
                if (canAccessPayments) _buildLedgerTab(shopLedger),
              ];

              if (_tabController.length != detailTabs.length) {
                final oldIdx = _tabController.index;
                _tabController.dispose();
                _tabController = TabController(
                  length: detailTabs.length,
                  vsync: this,
                  initialIndex: oldIdx.clamp(0, detailTabs.length - 1),
                );
              }

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      child: TabBar(
                        controller: _tabController,
                        labelColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                        unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        indicatorColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                        indicatorWeight: 2.5,
                        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                        tabs: detailTabs,
                      ),
                    ),
                    Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: detailViews,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // 3. Fixed Bottom Action Dock (Role-Tailored)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                top: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                  offset: const Offset(0, -3),
                  blurRadius: 10,
                ),
              ],
            ),
            child: SafeArea(
              child: Builder(
                builder: (ctx) {
                  final canTakeOrder = appState.isOwnerRole || appState.isFieldSalesRole;
                  final canCollectDue = !appState.isStoreManagerRole &&
                      (appState.isOwnerRole ||
                          appState.canAccessModule('accounts') ||
                          appState.canAccessModule('collections') ||
                          appState.isDeliveryRole);

                  final buttons = <Widget>[];

                  if (canCollectDue) {
                    buttons.add(
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showCollectPaymentDialog(currentShop),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                            side: BorderSide(
                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                              width: 1.2,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.payments_outlined, size: 16),
                          label: Text(
                            hasDues
                                ? 'Collect Due (${AppFormatters.compactCurrency(currentShop.currentOutstanding)})'
                                : 'Collect Due',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                      ),
                    );
                  }

                  if (canTakeOrder) {
                    if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
                    buttons.add(
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _startOrder(currentShop),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E56E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.shopping_cart_outlined, size: 17),
                          label: const Text(
                            'Take Order',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ),
                    );
                  }

                  if (appState.isDeliveryRole) {
                    if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
                    buttons.add(
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Opening Navigation Route to ${currentShop.shopName}...'),
                                backgroundColor: const Color(0xFF1E56E2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E56E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.directions_rounded, size: 17),
                          label: const Text(
                            'Directions',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ),
                    );
                  }

                  if (buttons.isEmpty) {
                    buttons.add(
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Calling ${currentShop.shopName}...'),
                                backgroundColor: const Color(0xFF1E56E2),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E56E2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.phone_rounded, size: 17),
                          label: const Text(
                            'Contact Retailer',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                        ),
                      ),
                    );
                  }

                  return Row(children: buttons);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(ShopModel shop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Logistics & Business Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Retail Outlet Logistics',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                _overviewInfoRow(Icons.location_on_outlined, 'Address', shop.address ?? 'Not recorded', isDark),
                _overviewInfoRow(Icons.category_outlined, 'Category', shop.businessType ?? 'Kirana Store', isDark),
                _overviewInfoRow(Icons.route_outlined, 'Visit Frequency', shop.visitFrequency.toUpperCase(), isDark),
                _overviewInfoRow(Icons.account_balance_wallet_outlined, 'Credit Limit', AppFormatters.currency(shop.creditLimit), isDark),
                if (shop.gstin != null && shop.gstin!.isNotEmpty)
                  _overviewInfoRow(Icons.receipt_long_outlined, 'GSTIN', shop.gstin!, isDark),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Notes Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Field & Payment Notes',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  shop.notes != null && shop.notes!.trim().isNotEmpty
                      ? shop.notes!.trim()
                      : 'No specific notes recorded for this outlet.',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewInfoRow(IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
          const SizedBox(width: 10),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab(List<dynamic> orders) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_bag_outlined, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              'No orders placed yet',
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "New Order" below to generate a bill',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final ord = orders[idx];
        final isDelivered = ord.status.toLowerCase() == 'delivered';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    ord.orderId,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDelivered
                          ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                          : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDelivered
                            ? (isDark ? const Color(0xFF047857) : const Color(0xFFBBF7D0))
                            : (isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
                      ),
                    ),
                    child: Text(
                      isDelivered ? 'DELIVERED' : ord.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isDelivered
                            ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D))
                            : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${ord.items.length} items • ${ord.placedAt != null ? AppFormatters.dateTime(ord.placedAt) : 'Today'}',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    AppFormatters.currency(ord.grandTotal),
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              if (!isDelivered) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          context.read<AppState>().updateOrderStatus(ord.orderId, 'delivered');
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Order ${ord.orderId} marked as Delivered!'),
                              backgroundColor: const Color(0xFF059669),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF059669), Color(0xFF047857)],
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF059669).withValues(alpha: 0.25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 13, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Deliver',
                                style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }



  Widget _buildBillsTab(List<dynamic> invoices) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (invoices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.receipt_long_outlined, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              'No GST tax invoices yet',
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Tax invoices are created when orders are confirmed',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: invoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final inv = invoices[idx];

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.receipt_long_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.invoiceNumber,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AppFormatters.date(inv.invoiceDate)} • ${AppFormatters.currency(inv.grandTotal)}',
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GstTaxInvoiceViewer(invoice: inv),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Tax Bill',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 14,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLedgerTab(List<dynamic> ledger) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (ledger.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 40, color: Color(0xFF94A3B8)),
            const SizedBox(height: 10),
            Text(
              'No Khata transactions yet',
              style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B)),
            ),
            const SizedBox(height: 4),
            Text(
              'Payments and invoices will appear in this ledger',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      itemCount: ledger.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final entry = ledger[idx];
        final isPayment = entry.type == 'PAYMENT';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: isPayment
                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                    : (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2)),
                child: Icon(
                  isPayment ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  size: 16,
                  color: isPayment
                      ? (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D))
                      : (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.description,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppFormatters.dateTime(entry.date),
                      style: TextStyle(
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isPayment ? "-" : "+"} ${AppFormatters.currency(entry.amount.abs())}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                      color: isPayment
                          ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                          : (isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626)),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bal: ${AppFormatters.currency(entry.balanceAfter)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (isPayment) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            final appState = context.read<AppState>();
                            final pMatches = appState.payments.where((p) => p.paymentId == entry.referenceId);
                            if (pMatches.isNotEmpty) {
                              final currentShop = appState.shops.firstWhere(
                                (s) => s.shopId == widget.shop.shopId,
                                orElse: () => widget.shop,
                              );
                              showEditPaymentDialog(context, currentShop, pMatches.first);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E56E2).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Edit',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF1E56E2)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            final appState = context.read<AppState>();
                            final pMatches = appState.payments.where((p) => p.paymentId == entry.referenceId);
                            if (pMatches.isNotEmpty) {
                              _confirmDeletePayment(context, pMatches.first);
                            }
                          },
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Delete',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteShop(BuildContext context, ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Shop?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to permanently delete "${shop.shopName}"? All related data will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deleteShop(shop.shopId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Shop "${shop.shopName}" was deleted.'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, PaymentModel payment) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Payment?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to delete payment of ₹${payment.amount.toStringAsFixed(0)}? Shop outstanding dues will be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deletePayment(payment.paymentId);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Payment of ₹${payment.amount.toStringAsFixed(0)} deleted.'),
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
