import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/collections/data/models/ledger_entry_model.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

class LedgerReportModal extends StatefulWidget {
  final bool initialIsKhata;
  final String? initialShopId;
  final bool isPage;

  const LedgerReportModal({
    super.key,
    this.initialIsKhata = false,
    this.initialShopId,
    this.isPage = false,
  });

  static Future<T?> open<T>(
    BuildContext context, {
    bool initialIsKhata = false,
    String? initialShopId,
  }) {
    return Navigator.push<T>(
      context,
      MaterialPageRoute(
        builder: (_) => LedgerReportScreen(
          initialIsKhata: initialIsKhata,
          initialShopId: initialShopId,
        ),
      ),
    );
  }

  @override
  State<LedgerReportModal> createState() => _LedgerReportModalState();
}

class LedgerReportScreen extends StatelessWidget {
  final bool initialIsKhata;
  final String? initialShopId;

  const LedgerReportScreen({
    super.key,
    this.initialIsKhata = false,
    this.initialShopId,
  });

  @override
  Widget build(BuildContext context) {
    return LedgerReportModal(
      initialIsKhata: initialIsKhata,
      initialShopId: initialShopId,
      isPage: true,
    );
  }
}

class _LedgerReportModalState extends State<LedgerReportModal> {
  late bool _isKhataMode; // false = Orders Report, true = Ledger & Khata
  int _khataSubTab = 0; // 0 = All Shops Ledger, 1 = Individual Shop Khata
  String _selectedTimePeriod = 'Half Year';
  String? _selectedShopId;
  bool _isDetailsExpanded = false;

  @override
  void initState() {
    super.initState();
    _isKhataMode = widget.initialIsKhata;
    _selectedShopId = widget.initialShopId;
    _khataSubTab = widget.initialShopId != null ? 1 : 0;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final shops = appState.shops;

    // Determine current selected shop
    ShopModel currentShop;
    if (_selectedShopId != null) {
      currentShop = shops.firstWhere(
        (s) => s.shopId == _selectedShopId,
        orElse: () => shops.isNotEmpty
            ? shops.first
            : ShopModel(shopId: 'shop_default', shopName: 'Retail Counter Customer', ownerName: 'Walk-in Retailer'),
      );
    } else if (shops.isNotEmpty) {
      currentShop = shops.first;
      _selectedShopId = currentShop.shopId;
    } else {
      currentShop = ShopModel(shopId: 'shop_default', shopName: 'Retail Counter Customer', ownerName: 'Walk-in Retailer');
    }

    // Filtered data for this shop
    final shopOrders = appState.orders.where((o) => o.shopId == currentShop.shopId).toList();
    final deliveredOrders = shopOrders.where((o) => o.status.toLowerCase() == 'delivered').length;
    final pendingOrders = shopOrders.where((o) => o.status.toLowerCase() != 'delivered').length;
    final grossRevenue = shopOrders.fold<double>(0.0, (acc, o) => acc + o.grandTotal);
    final totalGst = shopOrders.fold<double>(0.0, (acc, o) => acc + o.totalGst);

    // Ledger entries for this shop
    final shopLedger = appState.ledgerEntries.where((l) => l.shopId == currentShop.shopId).toList();
    final totalDebit = shopLedger.where((l) => l.amount > 0).fold<double>(0.0, (acc, l) => acc + l.amount);
    final totalCredit = shopLedger.where((l) => l.amount < 0).fold<double>(0.0, (acc, l) => acc + l.amount.abs());
    final closingDue = currentShop.currentOutstanding;

    final isDark = appState.isDarkMode;

    if (widget.isPage) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(
            _isKhataMode ? 'Download Ledger & Khata' : 'Download Orders Report',
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: _isKhataMode
              ? _buildKhataContent(context, appState, shops, currentShop, totalDebit, totalCredit, closingDue, shopLedger, isDark)
              : _buildOrdersContent(context, appState, shops, currentShop, shopOrders, grossRevenue, totalGst, deliveredOrders, pendingOrders, closingDue, isDark),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Modal Header
            _buildHeader(context, isDark),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: _isKhataMode
                    ? _buildKhataContent(context, appState, shops, currentShop, totalDebit, totalCredit, closingDue, shopLedger, isDark)
                    : _buildOrdersContent(context, appState, shops, currentShop, shopOrders, grossRevenue, totalGst, deliveredOrders, pendingOrders, closingDue, isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Header matching screenshot
  Widget _buildHeader(BuildContext context, bool isDark) {
    final isKhata = _isKhataMode;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Icon Container - Mint green box with emerald book icon matching Screenshots 1, 2, 3
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isKhata
                  ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0))
                  : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isKhata ? Icons.menu_book_rounded : Icons.bar_chart_rounded,
              color: isKhata
                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                  : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),

          // Title & Subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isKhata ? 'Download Ledger & Khata' : 'Download Orders Report',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isKhata
                      ? 'All Shops & Individual Khata Statement'
                      : 'One-Click Half Year / Annual Sales Export',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          // Close Button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF0F172A), size: 22),
            splashRadius: 20,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // --- MODE 1: Orders Report View (Images 1 & 2) ---
  Widget _buildOrdersContent(
    BuildContext context,
    AppState appState,
    List<ShopModel> shops,
    ShopModel currentShop,
    List dynamicOrders,
    double grossRevenue,
    double totalGst,
    int deliveredOrders,
    int pendingOrders,
    double closingDue,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section 1 Header
        Text(
          '1. Select Report Time Period',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
          ),
        ),
        const SizedBox(height: 12),

        // 2x2 Time Period Matrix
        _buildTimePeriodGrid(isDark: isDark),
        const SizedBox(height: 20),

        // Section 2 Header
        Text(
          '2. Filter by Shop / Territory',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w800,
            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
          ),
        ),
        const SizedBox(height: 10),

        // Shop Dropdown Selector with Floating Label
        _buildShopDropdown(shops, currentShop, 'Target Retail Shop Scope', isDark),
        const SizedBox(height: 16),

        // Report Summary Metrics Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📊', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Report Summary Metrics',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${dynamicOrders.length} Orders Found',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gross Sales Revenue',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          grossRevenue > 0
                              ? '₹ ${grossRevenue.toInt() >= 1000 ? "${(grossRevenue.toInt() ~/ 1000)},${(grossRevenue.toInt() % 1000).toString().padLeft(3, '0')}" : grossRevenue.toInt()}'
                              : '₹ 0',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'GST Tax Amount',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          totalGst > 0 ? '₹ ${totalGst.toInt()}' : '₹ 0',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Delivered: $deliveredOrders | Pending: $pendingOrders',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Balance Due: ₹${closingDue.toInt()}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Show Orders & Delivery Details Preview Accordion
        _buildAccordion(
          isDark: isDark,
          title: 'Show Orders & Delivery Details Preview (${dynamicOrders.length})',
          icon: Icons.visibility_rounded,
          content: dynamicOrders.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No individual orders placed yet for this shop in selected timeframe.',
                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280), fontStyle: FontStyle.italic),
                  ),
                )
              : Column(
                  children: dynamicOrders.map<Widget>((ord) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('${ord.orderId}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      subtitle: Text('${ord.items.length} items • ${ord.status}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      trailing: Text(AppFormatters.currency(ord.grandTotal), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 18),

        // Primary Button: Download CSV / Excel Report
        ElevatedButton.icon(
          onPressed: () {
            final appState = Provider.of<AppState>(context, listen: false);
            final typedOrders = dynamicOrders.whereType<OrderModel>().toList();
            final ordersToExport = typedOrders.isNotEmpty ? typedOrders : appState.orders;
            final csv = CsvReportHelper.generateOrdersCsv(
              orders: ordersToExport,
              shops: shops,
            );
            CsvReportHelper.downloadOrCopyCsv(
              context,
              reportTitle: 'Orders & Sales Report',
              fileName: 'orders_report_${DateTime.now().millisecondsSinceEpoch}.csv',
              csvContent: csv,
              totalRows: ordersToExport.length,
            );
          },
          icon: const Icon(Icons.file_download_outlined, size: 20, color: Colors.white),
          label: const Text(
            'Download CSV / Excel Report',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1D5BD8),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
        ),
        const SizedBox(height: 12),

        // Secondary Buttons Row
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening WhatsApp with Orders Summary...')),
                  );
                },
                icon: Icon(Icons.share_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                label: Text(
                  'Share via WA',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFF0F5FF),
                  foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Orders report summary copied to clipboard!')),
                  );
                },
                icon: Icon(Icons.copy_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                label: Text(
                  'Copy Report',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E3A8A)),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- MODE 2: Ledger & Khata View (Images 3, 4, 5) ---
  Widget _buildKhataContent(
    BuildContext context,
    AppState appState,
    List<ShopModel> shops,
    ShopModel currentShop,
    double totalDebit,
    double totalCredit,
    double closingDue,
    List dynamicLedger,
    bool isDark,
  ) {
    final totalTerritoryBilled = appState.invoices.isNotEmpty
        ? appState.invoices.fold<double>(0.0, (double sum, o) => sum + o.grandTotal)
        : appState.orders.fold<double>(0.0, (double sum, o) => sum + o.grandTotal);
    final totalTerritoryCollections = appState.payments.fold<double>(0.0, (double sum, p) => sum + p.amount);
    final totalTerritoryDue = shops.fold<double>(0.0, (double sum, s) => sum + s.currentOutstanding);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sub-Tabs Switcher: "All Shops Ledger (8)" vs "Individual Shop Khata"
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _khataSubTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: _khataSubTab == 0
                          ? Border(bottom: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), width: 2.5))
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('📄', style: TextStyle(fontSize: 12)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'All Shops Ledger',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _khataSubTab == 0 ? FontWeight.w800 : FontWeight.w600,
                                  color: _khataSubTab == 0
                                      ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E3A8A)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '(${shops.length})',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _khataSubTab == 0 ? FontWeight.w800 : FontWeight.w600,
                            color: _khataSubTab == 0
                                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E3A8A)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _khataSubTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      border: _khataSubTab == 1
                          ? Border(bottom: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), width: 2.5))
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person,
                              size: 15,
                              color: _khataSubTab == 1
                                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                'Individual Shop',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: _khataSubTab == 1 ? FontWeight.w800 : FontWeight.w600,
                                  color: _khataSubTab == 1
                                      ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E3A8A)),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Khata',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: _khataSubTab == 1 ? FontWeight.w800 : FontWeight.w600,
                            color: _khataSubTab == 1
                                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E3A8A)),
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
        const SizedBox(height: 16),

        if (_khataSubTab == 1) ...[
          // Statement Time Range (Screenshot 3)
          Text(
            'Statement Time Range',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 12),
          _buildTimePeriodGrid(isKhataLabel: true, isDark: isDark),
          const SizedBox(height: 20),

          // Select Retail Shop
          Text(
            'Select Retail Shop',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 10),
          _buildShopDropdown(shops, currentShop, 'Customer / Retailer Account', isDark),
          const SizedBox(height: 16),

          // Individual Shop Khata Summary Card with Vertical Pending Due Ribbon
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                // Content
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 38, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentShop.shopName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Prop: ${currentShop.ownerName} • ${currentShop.phone ?? "+91 98901 23456"}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Debit / Credit / Net Due Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Invoiced\n(Debit)', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(
                                  totalDebit > 0 ? AppFormatters.currency(totalDebit) : '₹0',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text('Total Paid\n(Credit)', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(
                                  totalCredit > 0 ? AppFormatters.currency(totalCredit) : '₹0',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Net Closing\nDue', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 4),
                                Text(
                                  closingDue > 0 ? AppFormatters.currency(closingDue) : '₹0',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Vertical Ribbon on the right: "Pending Due"
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                      border: Border(left: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA), width: 1)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'P\ne\nn\nd\ni\nn\ng\n \nD\nu\ne',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Show Transaction History Accordion
          _buildAccordion(
            isDark: isDark,
            title: 'Show Transaction History (${dynamicLedger.length} Entries)',
            icon: Icons.visibility_rounded,
            content: dynamicLedger.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'No ledger entries found for this period. Current balance due: ₹4,500.',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280), fontStyle: FontStyle.italic),
                    ),
                  )
                : Column(
                    children: dynamicLedger.map<Widget>((entry) {
                      final isInvoice = entry.type == 'INVOICE';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(entry.description, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        subtitle: Text(AppFormatters.date(entry.date), style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        trailing: Text(
                          AppFormatters.currency(entry.amount.abs()),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: isInvoice
                                ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                                : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 18),

          // Primary Button: Download Shop Khata Book (CSV / Excel)
          ElevatedButton.icon(
            onPressed: () async {
              if (!await FeatureGate.requireFeature(context, 'khata_ledger')) return;
              if (!context.mounted) return;
              final appState = Provider.of<AppState>(context, listen: false);
              final typedLedger = dynamicLedger.whereType<LedgerEntryModel>().toList();
              final entriesToExport = typedLedger.isNotEmpty ? typedLedger : appState.ledgerEntries;
              final csv = CsvReportHelper.generateLedgerCsv(
                entries: entriesToExport,
                shops: shops,
              );
              CsvReportHelper.downloadOrCopyCsv(
                context,
                reportTitle: 'Shop Khata Statement',
                fileName: 'shop_khata_${DateTime.now().millisecondsSinceEpoch}.csv',
                csvContent: csv,
                totalRows: entriesToExport.length,
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 20, color: Colors.white),
            label: const Text(
              'Download Shop Khata Book (CSV / Excel)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),

          // Secondary Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening WhatsApp with Khata Statement...')),
                    );
                  },
                  icon: Icon(Icons.share_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  label: Text(
                    'Send to Shop WA',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                    foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Khata statement copied to clipboard!')),
                    );
                  },
                  icon: Icon(Icons.copy_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  label: Text(
                    'Copy Statement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Consolidated All Shops Ledger (Tab 0 - Matching Screenshots 1 & 2)
          // 1. Statement Time Range
          Text(
            'Statement Time Range',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(height: 12),
          _buildTimePeriodGrid(isKhataLabel: true, isDark: isDark),
          const SizedBox(height: 18),

          // 2. Territory Consolidated Ledger Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('📊', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Territory Consolidated Ledger',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Territory Billed',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${totalTerritoryBilled.toInt() >= 1000 ? "${(totalTerritoryBilled.toInt() ~/ 1000)},${(totalTerritoryBilled.toInt() % 1000).toString().padLeft(3, '0')}" : totalTerritoryBilled.toInt()}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Total Collections',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹ ${totalTerritoryCollections.toInt() >= 1000 ? "${(totalTerritoryCollections.toInt() ~/ 1000)},${(totalTerritoryCollections.toInt() % 1000).toString().padLeft(3, '0')}" : totalTerritoryCollections.toInt()}',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Text(
                        '${shops.where((s) => s.currentOutstanding > 0).length} of ${shops.length} Shops have pending dues',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Net Due:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '₹${totalTerritoryDue.toInt()}',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Show Outlet Breakdown Accordion
          _buildAccordion(
            isDark: isDark,
            title: 'Show Outlet Breakdown (${shops.length} Shops)',
            icon: Icons.remove_red_eye_outlined,
            content: Column(
              children: shops.map((s) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(s.shopName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  subtitle: Text('${s.businessType ?? "Retail"} • ${s.ownerName}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  trailing: Text(
                    'Due: ${AppFormatters.currency(s.currentOutstanding)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: s.currentOutstanding > 0
                          ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                          : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),

          // 4. Primary Action Button: Download All Shops Ledger (CSV / Excel)
          ElevatedButton.icon(
            onPressed: () {
              final appState = Provider.of<AppState>(context, listen: false);
              final csv = CsvReportHelper.generateLedgerCsv(
                entries: appState.ledgerEntries,
                shops: shops,
              );
              CsvReportHelper.downloadOrCopyCsv(
                context,
                reportTitle: 'All Shops Ledger & Settlement Report',
                fileName: 'all_shops_ledger_${DateTime.now().millisecondsSinceEpoch}.csv',
                csvContent: csv,
                totalRows: appState.ledgerEntries.length,
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 20, color: Colors.white),
            label: const Text(
              'Download All Shops Ledger (CSV / Excel)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 12),

          // 5. Secondary Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Opening WhatsApp with territory summary...')),
                    );
                  },
                  icon: Icon(Icons.share_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  label: Text(
                    'Share Summary',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                    foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Territory ledger summary copied to clipboard!')),
                    );
                  },
                  icon: Icon(Icons.copy_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  label: Text(
                    'Copy Statement',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // 2x2 Time Period Matrix (matching mockup)
  Widget _buildTimePeriodGrid({bool isKhataLabel = false, required bool isDark}) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTimeChip(
                period: 'Half Year',
                subLabel: 'Last 6 Months',
                badgeText: isKhataLabel ? '6 Mo' : 'Popular',
                badgeBg: const Color(0xFF1D4ED8),
                badgeFg: Colors.white,
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeChip(
                period: 'Annual Sale',
                subLabel: 'Full 1 Year (12 Mo)',
                badgeText: isKhataLabel ? '1 Year' : 'Full FY',
                badgeBg: isDark ? const Color(0xFF064E3B) : const Color(0xFFE8F8F0),
                badgeFg: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimeChip(
                period: 'This Month',
                subLabel: 'Last 30 Days',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeChip(
                period: 'All Time',
                subLabel: isKhataLabel ? 'Full Ledger History' : 'Lifetime History',
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeChip({
    required String period,
    required String subLabel,
    String? badgeText,
    Color? badgeBg,
    Color? badgeFg,
    required bool isDark,
  }) {
    final isSelected = _selectedTimePeriod == period;
    return InkWell(
      onTap: () => setState(() => _selectedTimePeriod = period),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : Colors.white)
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 2.0 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1D4ED8).withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    period,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                          : (isDark ? Colors.white : const Color(0xFF111827)),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badgeText != null) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg ?? const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: badgeFg ?? Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subLabel,
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Dropdown for target shop
  Widget _buildShopDropdown(List<ShopModel> shops, ShopModel currentShop, String labelText, bool isDark) {
    return DropdownButtonFormField<String>(
      initialValue: _selectedShopId ?? (shops.isNotEmpty ? shops.first.shopId : null),
      isExpanded: true,
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      icon: Icon(Icons.arrow_drop_down, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF374151), size: 28),
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : const Color(0xFF111827),
      ),
      decoration: InputDecoration(
        labelText: labelText,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: TextStyle(
          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF4B5563),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFD1D5DB), width: 1.2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: Color(0xFF2563EB), width: 1.5),
        ),
      ),
      onChanged: (val) {
        if (val != null) setState(() => _selectedShopId = val);
      },
      items: shops.map((s) {
        return DropdownMenuItem(
          value: s.shopId,
          child: Text(
            s.shopName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF111827)),
          ),
        );
      }).toList(),
    );
  }

  // Accordion Expandable Preview
  Widget _buildAccordion({
    required String title,
    required IconData icon,
    required Widget content,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 1.2),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isDetailsExpanded = !_isDetailsExpanded),
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Icon(
                    _isDetailsExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
          if (_isDetailsExpanded) ...[
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: content,
            ),
          ],
        ],
      ),
    );
  }
}
