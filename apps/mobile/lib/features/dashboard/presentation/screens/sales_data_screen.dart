import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/ledger_report_modal.dart';

class SalesDataScreen extends StatefulWidget {
  const SalesDataScreen({super.key});

  @override
  State<SalesDataScreen> createState() => _SalesDataScreenState();
}

class _SalesDataScreenState extends State<SalesDataScreen> with SingleTickerProviderStateMixin {
  late TabController _timeTabController;
  String _searchQuery = '';
  String _selectedSection = 'Overview'; // Overview, Parties, Products, Invoices

  @override
  void initState() {
    super.initState();
    _timeTabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _timeTabController.dispose();
    super.dispose();
  }

  List<InvoiceModel> _filterInvoicesByTime(List<InvoiceModel> invoices, int tabIndex) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (tabIndex) {
      case 1: // Today
        return invoices.where((inv) => inv.invoiceDate.isAfter(todayStart)).toList();
      case 2: // This Week
        final weekStart = todayStart.subtract(Duration(days: now.weekday - 1));
        return invoices.where((inv) => inv.invoiceDate.isAfter(weekStart)).toList();
      case 3: // This Month
        final monthStart = DateTime(now.year, now.month, 1);
        return invoices.where((inv) => inv.invoiceDate.isAfter(monthStart)).toList();
      case 0: // All Time
      default:
        return invoices;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allInvoices = appState.invoices;

    // Filter by active time tab
    final timeFilteredInvoices = _filterInvoicesByTime(allInvoices, _timeTabController.index);

    // Search filter
    final filteredInvoices = timeFilteredInvoices.where((inv) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final shopName = inv.buyer['shopName']?.toString().toLowerCase() ?? '';
      return inv.invoiceNumber.toLowerCase().contains(q) ||
          shopName.contains(q) ||
          inv.orderId.toLowerCase().contains(q);
    }).toList();

    // Aggregations
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);

    final todaySales = allInvoices
        .where((i) => i.invoiceDate.isAfter(todayStart))
        .fold<double>(0.0, (acc, i) => acc + i.grandTotal);
    final monthSales = allInvoices
        .where((i) => i.invoiceDate.isAfter(monthStart))
        .fold<double>(0.0, (acc, i) => acc + i.grandTotal);
    final totalSales = allInvoices.fold<double>(0.0, (acc, i) => acc + i.grandTotal);
    final avgOrderValue = allInvoices.isNotEmpty ? totalSales / allInvoices.length : 0.0;

    // Party-wise calculation
    final Map<String, _PartySalesStat> partySalesMap = {};
    for (final inv in timeFilteredInvoices) {
      final partyName = inv.buyer['shopName']?.toString() ?? 'Counter Buyer';
      final current = partySalesMap[partyName] ?? _PartySalesStat(partyName: partyName, totalAmount: 0.0, invoiceCount: 0);
      partySalesMap[partyName] = _PartySalesStat(
        partyName: partyName,
        totalAmount: current.totalAmount + inv.grandTotal,
        invoiceCount: current.invoiceCount + 1,
      );
    }
    final sortedParties = partySalesMap.values.toList()
      ..sort((a, b) => b.totalAmount.compareTo(a.totalAmount));

    // Product-wise calculation
    final Map<String, _ProductSalesStat> productSalesMap = {};
    for (final inv in timeFilteredInvoices) {
      for (final item in inv.items) {
        final current = productSalesMap[item.productName] ??
            _ProductSalesStat(productName: item.productName, totalQty: 0, totalRevenue: 0.0);
        productSalesMap[item.productName] = _ProductSalesStat(
          productName: item.productName,
          totalQty: current.totalQty + item.quantity,
          totalRevenue: current.totalRevenue + item.total,
        );
      }
    }
    final sortedProducts = productSalesMap.values.toList()
      ..sort((a, b) => b.totalRevenue.compareTo(a.totalRevenue));

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
              'Sales Data & Analytics',
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            Text(
              'Comprehensive Revenue & Party Performance',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2)),
            tooltip: 'Download Sales Report',
            onPressed: () {
              LedgerReportModal.open(context, initialIsKhata: false);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Executive Stats Carousel / Grid
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E56E2), Color(0xFF173BBF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1E56E2).withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TOTAL REVENUE OVERVIEW',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Icon(Icons.insights_rounded, color: Colors.white, size: 20),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppFormatters.currency(totalSales),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildMetricPill("Today's Sale", AppFormatters.currency(todaySales)),
                      const SizedBox(width: 8),
                      _buildMetricPill("This Month", AppFormatters.currency(monthSales)),
                      const SizedBox(width: 8),
                      _buildMetricPill("Avg Order", AppFormatters.currency(avgOrderValue)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Time Period Filter Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: TabBar(
                controller: _timeTabController,
                onTap: (_) => setState(() {}),
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF334155) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppTheme.softShadow(blur: 4, dy: 1),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                tabs: const [
                  Tab(text: 'All Time'),
                  Tab(text: 'Today'),
                  Tab(text: 'This Week'),
                  Tab(text: 'This Month'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Navigation Pill Selector: Overview, Parties, Products, Invoices
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSectionChip('Overview', Icons.dashboard_outlined, isDark),
                  const SizedBox(width: 8),
                  _buildSectionChip('Parties (${sortedParties.length})', Icons.storefront_outlined, isDark),
                  const SizedBox(width: 8),
                  _buildSectionChip('Products (${sortedProducts.length})', Icons.inventory_2_outlined, isDark),
                  const SizedBox(width: 8),
                  _buildSectionChip('Invoices (${filteredInvoices.length})', Icons.receipt_long_outlined, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 1. SECTION: OVERVIEW
            if (_selectedSection == 'Overview') ...[
              _buildSectionCard(
                title: 'Sales Summary Highlights',
                subtitle: 'Period: ${_getPeriodLabel(_timeTabController.index)}',
                isDark: isDark,
                child: Column(
                  children: [
                    _buildSummaryRow('Total Invoices', '${timeFilteredInvoices.length}', isDark),
                    _buildSummaryRow('Period Revenue', AppFormatters.currency(timeFilteredInvoices.fold<double>(0.0, (acc, i) => acc + i.grandTotal)), isDark),
                    _buildSummaryRow('Active Buying Parties', '${sortedParties.length}', isDark),
                    _buildSummaryRow('Distinct Products Sold', '${sortedProducts.length}', isDark),
                    _buildSummaryRow('Average Invoice Value', AppFormatters.currency(timeFilteredInvoices.isNotEmpty ? timeFilteredInvoices.fold<double>(0.0, (acc, i) => acc + i.grandTotal) / timeFilteredInvoices.length : 0.0), isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Top 3 Parties preview
              _buildSectionCard(
                title: 'Top Purchasing Parties',
                subtitle: 'Highest grossing retail outlets in this period',
                isDark: isDark,
                trailing: TextButton(
                  onPressed: () => setState(() => _selectedSection = 'Parties (${sortedParties.length})'),
                  child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2))),
                ),
                child: Column(
                  children: sortedParties.take(3).map((p) => _buildPartyRow(p, totalSales, isDark)).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // Top 3 Products preview
              _buildSectionCard(
                title: 'Top Performing Products',
                subtitle: 'Highest revenue generating items in this period',
                isDark: isDark,
                trailing: TextButton(
                  onPressed: () => setState(() => _selectedSection = 'Products (${sortedProducts.length})'),
                  child: Text('View All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2))),
                ),
                child: Column(
                  children: sortedProducts.take(3).map((pr) => _buildProductRow(pr, isDark)).toList(),
                ),
              ),
            ],

            // 2. SECTION: PARTIES
            if (_selectedSection.startsWith('Parties')) ...[
              _buildSectionCard(
                title: 'Party-Wise Sales Breakdown',
                subtitle: 'Retail outlets ranked by turnover',
                isDark: isDark,
                child: sortedParties.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No party sales in this period', style: TextStyle(color: Color(0xFF94A3B8)))),
                      )
                    : Column(
                        children: sortedParties.map((p) => _buildPartyRow(p, totalSales, isDark)).toList(),
                      ),
              ),
            ],

            // 3. SECTION: PRODUCTS
            if (_selectedSection.startsWith('Products')) ...[
              _buildSectionCard(
                title: 'Product & SKU Sales Volume',
                subtitle: 'Line items ordered and revenue generated',
                isDark: isDark,
                child: sortedProducts.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('No product sales in this period', style: TextStyle(color: Color(0xFF94A3B8)))),
                      )
                    : Column(
                        children: sortedProducts.map((pr) => _buildProductRow(pr, isDark)).toList(),
                      ),
              ),
            ],

            // 4. SECTION: INVOICES
            if (_selectedSection.startsWith('Invoices')) ...[
              // Search Input
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: InputDecoration(
                    hintText: 'Search by Invoice # or Shop name...',
                    hintStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                    prefixIcon: Icon(Icons.search, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              if (filteredInvoices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: Text('No invoices match the search filter', style: TextStyle(color: Color(0xFF94A3B8)))),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredInvoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, idx) {
                    final inv = filteredInvoices[idx];
                    final buyerName = inv.buyer['shopName'] ?? 'Counter Buyer';
                    return Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: AppTheme.softShadow(blur: 6, dy: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
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
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$buyerName • ${inv.items.length} items',
                                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  AppFormatters.dateTime(inv.invoiceDate),
                                  style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                AppFormatters.currency(inv.grandTotal),
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
                                ),
                              ),
                              const SizedBox(height: 4),
                              InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => GstTaxInvoiceViewer(invoice: inv)),
                                  );
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E56E2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'View Bill',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _getPeriodLabel(int idx) {
    switch (idx) {
      case 1:
        return 'Today';
      case 2:
        return 'This Week';
      case 3:
        return 'This Month';
      default:
        return 'All Time';
    }
  }

  Widget _buildMetricPill(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionChip(String label, IconData icon, bool isDark) {
    final isSelected = _selectedSection == label || _selectedSection.startsWith(label.split(' ').first);
    return ChoiceChip(
      avatar: Icon(icon, size: 16, color: isSelected ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      label: Text(label),
      selected: isSelected,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      selectedColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFEFF6FF),
      side: BorderSide(
        color: isSelected
            ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD))
            : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      ),
      onSelected: (_) => setState(() => _selectedSection = label),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    Widget? trailing,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String val, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
          Text(
            val,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyRow(_PartySalesStat party, double totalTurnover, bool isDark) {
    final pct = totalTurnover > 0 ? (party.totalAmount / totalTurnover * 100).clamp(0, 100) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  party.partyName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                AppFormatters.currency(party.totalAmount),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1E56E2)),
                    minHeight: 5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${party.invoiceCount} bills • ${pct.toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductRow(_ProductSalesStat prod, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prod.productName,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${prod.totalQty} units sold',
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          Text(
            AppFormatters.currency(prod.totalRevenue),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartySalesStat {
  final String partyName;
  final double totalAmount;
  final int invoiceCount;
  _PartySalesStat({required this.partyName, required this.totalAmount, required this.invoiceCount});
}

class _ProductSalesStat {
  final String productName;
  final int totalQty;
  final double totalRevenue;
  _ProductSalesStat({required this.productName, required this.totalQty, required this.totalRevenue});
}
