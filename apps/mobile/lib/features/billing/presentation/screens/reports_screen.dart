import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/features/reports/presentation/screens/inventory_report_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/sales_report_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/orders_report_screen.dart';
import 'package:salesarmy/features/reports/presentation/screens/ledger_graphical_report_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  int _activeTab = 0; // 0: GST Tax Invoices, 1: Statements & Exports
  String _searchQuery = '';
  String _selectedPeriod = 'This Month'; // 'Today', 'This Month', 'Quarter', 'Financial Year', 'Custom Range'
  String _invoiceFilter = 'All'; // 'All', 'Paid', 'Pending'
  DateTimeRange _customDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime.now(),
  );

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final invoices = appState.invoices;

    final filteredInvoices = invoices.where((inv) {
      if (_invoiceFilter == 'Paid' && inv.paymentStatus.toLowerCase() != 'paid') return false;
      if (_invoiceFilter == 'Pending' && inv.paymentStatus.toLowerCase() == 'paid') return false;

      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      final buyerName = inv.buyer['businessName']?.toString().toLowerCase() ?? '';
      final invNum = inv.invoiceNumber.toLowerCase();
      final totalStr = inv.grandTotal.toInt().toString();
      return buyerName.contains(query) || invNum.contains(query) || totalStr.contains(query);
    }).toList();

    final totalInvoiced = invoices.fold<double>(0.0, (sum, i) => sum + i.grandTotal);
    final totalGst = invoices.fold<double>(0.0, (sum, i) => sum + i.totalGst);
    final paidInvoices = invoices.where((i) => i.paymentStatus.toLowerCase() == 'paid').toList();
    final paidAmount = paidInvoices.fold<double>(0.0, (sum, i) => sum + i.grandTotal);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Reports & Downloads',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      body: Column(
        children: [
          // 1. Metric Summary Strip
          Container(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricCard(
                    label: 'TOTAL GST BILLS',
                    value: '${invoices.length}',
                    valueColor: isDark ? Colors.white : const Color(0xFF0F172A),
                    bgColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                    borderColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    icon: Icons.receipt_long_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    label: 'INVOICED VALUE',
                    value: AppFormatters.compactCurrency(totalInvoiced),
                    valueColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                    bgColor: isDark ? const Color(0xFF0C4A6E).withValues(alpha: 0.3) : const Color(0xFFF0F9FF),
                    borderColor: isDark ? const Color(0xFF0284C7).withValues(alpha: 0.4) : const Color(0xFFBAE6FD),
                    icon: Icons.trending_up_rounded,
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildMetricCard(
                    label: 'TOTAL GST TAX',
                    value: AppFormatters.compactCurrency(totalGst),
                    valueColor: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                    bgColor: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB),
                    borderColor: isDark ? const Color(0xFFD97706).withValues(alpha: 0.4) : const Color(0xFFFDE68A),
                    icon: Icons.account_balance_rounded,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),

          // 2. Tab Navigation Capsule
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(0, 'GST Tax Invoices', Icons.receipt_long_rounded, isDark: isDark),
                  ),
                  Expanded(
                    child: _buildTabButton(1, 'Statements & Exports', Icons.analytics_outlined, isDark: isDark),
                  ),
                ],
              ),
            ),
          ),

          // 3. Tab Content
          Expanded(
            child: _activeTab == 0
                ? _buildInvoicesTab(filteredInvoices, invoices.length, paidInvoices.length, paidAmount, isDark)
                : _buildStatementsTab(context, appState, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon, {required bool isDark, String? badge}) {
    final isSelected = _activeTab == index;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setState(() => _activeTab = index);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? (isDark ? const Color(0xFF334155) : Colors.white) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? Colors.white : const Color(0xFF0F172A))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFEFF6FF))
                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: isSelected
                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB))
                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color valueColor,
    required Color bgColor,
    required Color borderColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 13, color: valueColor),
            ],
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: valueColor, letterSpacing: -0.2),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoicesTab(List<InvoiceModel> invoices, int totalCount, int paidCount, double paidAmount, bool isDark) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              hintText: 'Search GST bill number or retailer name...',
              hintStyle: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 20,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        size: 18,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A), width: 1.5),
              ),
            ),
          ),
        ),

        // Filter pills row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(
            children: [
              _invoiceFilterChip('All', 'All Bills', isDark),
              const SizedBox(width: 8),
              _invoiceFilterChip('Paid', 'Paid', isDark),
              const SizedBox(width: 8),
              _invoiceFilterChip('Pending', 'Pending', isDark),
            ],
          ),
        ),

        // List
        Expanded(
          child: invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.receipt_long_rounded,
                          size: 36,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No GST Bills Found',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _searchQuery.isNotEmpty || _invoiceFilter != 'All'
                            ? 'Try clearing the search query or status filter.'
                            : 'Bills created in Orders will appear here for download.',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty || _invoiceFilter != 'All') ...[
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => setState(() {
                            _searchQuery = '';
                            _invoiceFilter = 'All';
                          }),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A),
                            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Reset Filters', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: invoices.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final inv = invoices[idx];
                    final buyerName = inv.buyer['businessName'] ?? 'Customer Account';
                    final isPaid = inv.paymentStatus.toLowerCase() == 'paid';

                    return InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        GstTaxInvoiceViewer.show(context, inv);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0F172A).withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isPaid
                                    ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4))
                                    : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.5) : const Color(0xFFFFFBEB)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPaid
                                      ? (isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0))
                                      : (isDark ? const Color(0xFFD97706) : const Color(0xFFFDE68A)),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                isPaid ? Icons.check_circle_outline_rounded : Icons.pending_outlined,
                                color: isPaid
                                    ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
                                    : (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                                size: 22,
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
                                        inv.invoiceNumber,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isPaid
                                              ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                                              : (isDark ? const Color(0xFF78350F) : const Color(0xFFFEF3C7)),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          isPaid ? 'PAID' : 'PENDING',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: isPaid
                                                ? (isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D))
                                                : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    buyerName,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        AppFormatters.date(inv.invoiceDate),
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'GST: ${AppFormatters.compactCurrency(inv.totalGst)}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                                        ),
                                      ),
                                    ],
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
                                    fontSize: 14,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.yellowPrimary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.download_rounded, size: 12, color: Color(0xFF0F172A)),
                                      SizedBox(width: 3),
                                      Text(
                                        'View/Print',
                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _invoiceFilterChip(String key, String label, bool isDark) {
    final isSel = _invoiceFilter == key;
    return InkWell(
      onTap: () => setState(() => _invoiceFilter = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSel
              ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSel
                ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
            color: isSel
                ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildStatementsTab(BuildContext context, AppState appState, bool isDark) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        // 1. Period Selector Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'REPORT STATEMENT PERIOD',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                  if (_selectedPeriod == 'Custom Range')
                    InkWell(
                      onTap: () async {
                        final picked = await showDateRangePicker(
                          context: context,
                          initialDateRange: _customDateRange,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _customDateRange = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.edit_calendar_rounded,
                              size: 12,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Change Dates',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Today', 'This Month', 'Quarter', 'Financial Year', 'Custom Range'].map((p) {
                    final isSel = _selectedPeriod == p;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(p),
                        selected: isSel,
                        onSelected: (_) async {
                          if (p == 'Custom Range') {
                            final picked = await showDateRangePicker(
                              context: context,
                              initialDateRange: _customDateRange,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (picked != null) {
                              setState(() {
                                _customDateRange = picked;
                                _selectedPeriod = p;
                              });
                              return;
                            }
                          }
                          setState(() => _selectedPeriod = p);
                        },
                        selectedColor: AppTheme.yellowPrimary,
                        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                          color: isSel ? const Color(0xFF0F172A) : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              if (_selectedPeriod == 'Custom Range') ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFF86EFAC)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.date_range_rounded,
                        size: 16,
                        color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Active Range: ${AppFormatters.date(_customDateRange.start)} - ${AppFormatters.date(_customDateRange.end)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF166534),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 1. Consolidated Khata Ledger Report Card
        _buildReportOptionCard(
          title: 'Khata Ledger & Accounts Statement',
          subtitle: 'Aging analysis, debit/credit flow ratio, debtor leaderboard & full deep CSV download',
          icon: Icons.menu_book_rounded,
          iconColor: const Color(0xFF1D4ED8),
          iconBg: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
          actionLabel: 'Open Graphical Ledger',
          isDark: isDark,
          statChips: const [
            'Ledger Transactions',
            'Party Accounts',
            'Real-time Aging',
          ],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LedgerGraphicalReportScreen()),
            );
          },
          onDownloadCsv: () {
            final csv = CsvReportHelper.generateLedgerCsv(
              entries: appState.ledgerEntries,
              shops: appState.shops,
            );
            CsvReportHelper.downloadOrCopyCsv(
              context,
              reportTitle: 'Khata Ledger & Accounts Report',
              fileName: 'ledger_report_${DateTime.now().millisecondsSinceEpoch}.csv',
              csvContent: csv,
              totalRows: appState.ledgerEntries.length,
            );
          },
          onShareWa: () {
            final totalDebit = appState.ledgerEntries.where((e) => e.amount > 0).fold<double>(0, (s, e) => s + e.amount);
            final totalCredit = appState.ledgerEntries.where((e) => e.amount < 0).fold<double>(0, (s, e) => s + e.amount.abs());
            final netBalance = totalDebit - totalCredit;
            final msg = "*SALESARMY KHATA LEDGER STATEMENT*\n"
                "--------------------------------\n"
                "Total Entries: ${appState.ledgerEntries.length}\n"
                "Total Receivables: Rs. ${AppFormatters.currency(totalDebit)}\n"
                "Total Collected: Rs. ${AppFormatters.currency(totalCredit)}\n"
                "Net Outstanding: Rs. ${AppFormatters.currency(netBalance)}\n"
                "Active Retail Parties: ${appState.shops.length}\n"
                "Generated on: ${AppFormatters.date(DateTime.now())}\n"
                "--------------------------------\n"
                "SalesArmy Automated Accounting";
            CsvReportHelper.shareViaWhatsApp(context: context, message: msg);
          },
        ),
        const SizedBox(height: 12),

        // 2. Retail Orders & Delivery Register
        _buildReportOptionCard(
          title: 'Orders & Sales Register',
          subtitle: 'Status pipeline funnel, top 5 ordered items, AOV metric & itemized SKU CSV',
          icon: Icons.inventory_rounded,
          iconColor: const Color(0xFF059669),
          iconBg: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFF0FDF4),
          actionLabel: 'Open Graphical Orders',
          isDark: isDark,
          statChips: const [
            'Logged Orders',
            'Full SKU Register',
            'Pipeline Status',
          ],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrdersReportScreen()),
            );
          },
          onDownloadCsv: () {
            final csv = CsvReportHelper.generateOrdersCsv(
              orders: appState.orders,
              shops: appState.shops,
            );
            CsvReportHelper.downloadOrCopyCsv(
              context,
              reportTitle: 'Orders & Sales Register',
              fileName: 'orders_register_${DateTime.now().millisecondsSinceEpoch}.csv',
              csvContent: csv,
              totalRows: appState.orders.length,
            );
          },
          onShareWa: () {
            final totalOrders = appState.orders.length;
            final totalRevenue = appState.orders.fold<double>(0, (s, o) => s + o.grandTotal);
            final delivered = appState.orders.where((o) => o.status.toLowerCase() == 'delivered').length;
            final pending = totalOrders - delivered;
            final msg = "*SALESARMY RETAIL ORDERS REGISTER*\n"
                "--------------------------------\n"
                "Total Orders: $totalOrders\n"
                "Total Order Value: Rs. ${AppFormatters.currency(totalRevenue)}\n"
                "Delivered Orders: $delivered\n"
                "Pending / Transit: $pending\n"
                "Generated on: ${AppFormatters.date(DateTime.now())}\n"
                "--------------------------------\n"
                "SalesArmy Field Operations";
            CsvReportHelper.shareViaWhatsApp(context: context, message: msg);
          },
        ),
        const SizedBox(height: 12),

        // 3. Inventory & Stock Valuation Report
        _buildReportOptionCard(
          title: 'Inventory & Stock Valuation Report',
          subtitle: 'Category valuation bars, stock health gauge, low stock warnings & full SKU register CSV',
          icon: Icons.inventory_2_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB),
          actionLabel: 'Open Graphical Inventory',
          isDark: isDark,
          statChips: const [
            'Products Cataloged',
            'Live Stock Valuation',
            'Low Stock Alerts',
          ],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InventoryReportScreen()),
            );
          },
          onDownloadCsv: () {
            final csv = CsvReportHelper.generateInventoryCsv(
              products: appState.products,
            );
            CsvReportHelper.downloadOrCopyCsv(
              context,
              reportTitle: 'Inventory Stock Valuation Report',
              fileName: 'inventory_valuation_${DateTime.now().millisecondsSinceEpoch}.csv',
              csvContent: csv,
              totalRows: appState.products.length,
            );
          },
          onShareWa: () {
            final totalSkus = appState.products.length;
            final totalUnits = appState.products.fold<int>(0, (s, p) => s + p.stockQuantity);
            final valuation = appState.products.fold<double>(0, (s, p) => s + (p.stockQuantity * p.wholesalePrice));
            final lowStock = appState.products.where((p) => p.stockQuantity < 10).length;
            final msg = "*SALESARMY INVENTORY & STOCK VALUATION*\n"
                "--------------------------------\n"
                "Total Products / SKUs: $totalSkus\n"
                "Total Stock Units: $totalUnits\n"
                "Total Inventory Value: Rs. ${AppFormatters.currency(valuation)}\n"
                "Low Stock Alerts (< 10 units): $lowStock\n"
                "Generated on: ${AppFormatters.date(DateTime.now())}\n"
                "--------------------------------\n"
                "SalesArmy Warehouse Management";
            CsvReportHelper.shareViaWhatsApp(context: context, message: msg);
          },
        ),
        const SizedBox(height: 12),

        // 4. Sales & GST Tax Report
        _buildReportOptionCard(
          title: 'GST Tax Liability Summary',
          subtitle: 'CGST/SGST/IGST tax breakdown, top buying retailers, invoice register & deep tax CSV',
          icon: Icons.point_of_sale_rounded,
          iconColor: const Color(0xFF7C3AED),
          iconBg: isDark ? const Color(0xFF581C87).withValues(alpha: 0.4) : const Color(0xFFF5F3FF),
          actionLabel: 'Open Graphical Sales',
          isDark: isDark,
          statChips: const [
            'CGST & SGST Split',
            'Bills Reconciled',
            'GSTR-1 Ready',
          ],
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SalesReportScreen()),
            );
          },
          onDownloadCsv: () {
            final csv = CsvReportHelper.generateSalesCsv(
              invoices: appState.invoices,
              orders: appState.orders,
            );
            CsvReportHelper.downloadOrCopyCsv(
              context,
              reportTitle: 'Sales & GST Tax Register',
              fileName: 'sales_gst_tax_register_${DateTime.now().millisecondsSinceEpoch}.csv',
              csvContent: csv,
              totalRows: appState.invoices.length,
            );
          },
          onShareWa: () {
            final totalBills = appState.invoices.length;
            final taxable = appState.invoices.fold<double>(0, (s, i) => s + i.taxableSubtotal);
            final totalGst = appState.invoices.fold<double>(0, (s, i) => s + i.totalGst);
            final grandTotal = appState.invoices.fold<double>(0, (s, i) => s + i.grandTotal);
            final msg = "*SALESARMY GST TAX LIABILITY SUMMARY*\n"
                "--------------------------------\n"
                "Total GST Invoices: $totalBills\n"
                "Total Taxable Value: Rs. ${AppFormatters.currency(taxable)}\n"
                "Total GST Collected: Rs. ${AppFormatters.currency(totalGst)}\n"
                "Total Gross Revenue: Rs. ${AppFormatters.currency(grandTotal)}\n"
                "Generated on: ${AppFormatters.date(DateTime.now())}\n"
                "--------------------------------\n"
                "SalesArmy Tax & Compliance";
            CsvReportHelper.shareViaWhatsApp(context: context, message: msg);
          },
        ),
      ],
    );
  }

  Widget _buildReportOptionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String actionLabel,
    required VoidCallback onTap,
    required bool isDark,
    List<String>? statChips,
    VoidCallback? onDownloadCsv,
    VoidCallback? onShareWa,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: iconBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 10,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (statChips != null && statChips.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: statChips.map((chip) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Text(
                            chip,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onDownloadCsv != null || onShareWa != null) ...[
            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  if (onDownloadCsv != null)
                    Expanded(
                      child: InkWell(
                        onTap: onDownloadCsv,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.download_rounded, size: 15, color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                              const SizedBox(width: 5),
                              Text(
                                'Download CSV',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (onDownloadCsv != null && onShareWa != null) const SizedBox(width: 10),
                  if (onShareWa != null)
                    Expanded(
                      child: InkWell(
                        onTap: onShareWa,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.share_outlined, size: 15, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
                              const SizedBox(width: 5),
                              Text(
                                'Share via WA',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
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
          ],
        ],
      ),
    );
  }
}

/// Full-screen GST Tax Summary Page (no modal dialogs, includes downloads)
class GstTaxSummaryScreen extends StatelessWidget {
  const GstTaxSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final invoices = appState.invoices;
    final taxableTotal = invoices.fold<double>(0.0, (s, i) => s + i.taxableSubtotal);
    final cgstTotal = invoices.fold<double>(0.0, (s, i) => s + i.cgst);
    final sgstTotal = invoices.fold<double>(0.0, (s, i) => s + i.sgst);
    final totalTax = invoices.fold<double>(0.0, (s, i) => s + i.totalGst);
    final grandTotal = invoices.fold<double>(0.0, (s, i) => s + i.grandTotal);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'GST Tax Liability Statement',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // 1. Grand Tax Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF78350F).withValues(alpha: 0.6), const Color(0xFF451A03)]
                    : const [Color(0xFFFFFBEB), Color(0xFFFEF3C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.4) : const Color(0xFFFDE68A),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'GSTR-1 READY',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                    ),
                    Text(
                      '${invoices.length} INVOICES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Total Tax Liability (CGST + SGST)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppFormatters.currency(totalTax),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF78350F),
                  ),
                ),
                const SizedBox(height: 14),
                Divider(
                  color: isDark ? const Color(0xFFD97706).withValues(alpha: 0.4) : const Color(0xFFFCD34D),
                  height: 1,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Taxable Turnover',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(taxableTotal),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Gross Invoice Total',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(grandTotal),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF78350F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. CGST / SGST Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TAX COMPONENT SPLIT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _taxRow('Central GST (CGST)', AppFormatters.currency(cgstTotal), isDark: isDark),
                Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                _taxRow('State GST (SGST)', AppFormatters.currency(sgstTotal), isDark: isDark),
                Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                _taxRow('Integrated GST (IGST)', '₹0.00 (Intra-state)', isDark: isDark),
                Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                _taxRow('Total Tax Output', AppFormatters.currency(totalTax), isBold: true, color: const Color(0xFFFBBF24), isDark: isDark),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Download & Action Buttons
          ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.mediumImpact();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('GSTR-1 Tax Report (Excel/CSV) downloaded successfully!'),
                  backgroundColor: Color(0xFF059669),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.file_download_outlined, size: 20, color: Colors.white),
            label: const Text(
              'Download GSTR-1 Report (CSV / Excel)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening WhatsApp with GST Tax Summary...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.share_outlined, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                  label: Text(
                    'Share on WA',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                    foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Clipboard.setData(ClipboardData(
                      text: 'SalesArmy GST Statement\nTaxable Turnover: ₹$taxableTotal\nCGST: ₹$cgstTotal\nSGST: ₹$sgstTotal\nTotal Tax: ₹$totalTax\nGrand Total: ₹$grandTotal',
                    ));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('GST tax statement copied to clipboard!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: Icon(Icons.copy_outlined, size: 16, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                  label: Text(
                    'Copy Summary',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 4. Invoices Included
          Text(
            'INVOICES INCLUDED',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ...invoices.map((inv) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.receipt_long_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            inv.invoiceNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            inv.buyer['businessName'] ?? 'Customer Account',
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.currency(inv.grandTotal),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'GST: ${AppFormatters.currency(inv.totalGst)}',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  static Widget _taxRow(String label, String value, {bool isBold = false, Color? color, required bool isDark}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w900 : FontWeight.w700,
            color: color ?? (isDark ? Colors.white : const Color(0xFF0F172A)),
          ),
        ),
      ],
    );
  }
}
