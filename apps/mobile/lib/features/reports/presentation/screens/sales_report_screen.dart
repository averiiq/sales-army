import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';

class SalesReportScreen extends StatefulWidget {
  const SalesReportScreen({super.key});

  @override
  State<SalesReportScreen> createState() => _SalesReportScreenState();
}

class _SalesReportScreenState extends State<SalesReportScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final invoices = appState.invoices;
    final orders = appState.orders;

    // Totals
    final totalGross = invoices.fold<double>(0.0, (sum, i) => sum + i.grandTotal);
    final totalTaxable = invoices.fold<double>(0.0, (sum, i) => sum + i.subtotal);
    final totalGst = invoices.fold<double>(0.0, (sum, i) => sum + i.totalGst);
    final totalCgst = invoices.fold<double>(0.0, (sum, i) => sum + i.cgst);
    final totalSgst = invoices.fold<double>(0.0, (sum, i) => sum + i.sgst);
    final totalIgst = invoices.fold<double>(0.0, (sum, i) => sum + i.igst);

    final paidInvoices = invoices.where((i) => i.paymentStatus.toLowerCase() == 'paid').toList();
    final paidAmount = paidInvoices.fold<double>(0.0, (sum, i) => sum + i.grandTotal);

    // Top buyers
    final Map<String, double> buyerTotals = {};
    final Map<String, int> buyerCounts = {};
    for (final inv in invoices) {
      final bName = inv.buyer['businessName'] ?? 'Counter Sale';
      buyerTotals[bName] = (buyerTotals[bName] ?? 0.0) + inv.grandTotal;
      buyerCounts[bName] = (buyerCounts[bName] ?? 0) + 1;
    }
    final sortedBuyers = buyerTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topBuyers = sortedBuyers.take(5).toList();

    // Filtered list
    final filtered = invoices.where((inv) {
      final q = _searchQuery.toLowerCase().trim();
      final bName = inv.buyer['businessName']?.toString().toLowerCase() ?? '';
      final invNum = inv.invoiceNumber.toLowerCase();
      final matchesQuery = q.isEmpty || bName.contains(q) || invNum.contains(q);
      final matchesStatus = _statusFilter == 'All' ||
          inv.paymentStatus.toLowerCase() == _statusFilter.toLowerCase();
      return matchesQuery && matchesStatus;
    }).toList();

    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Sales & Tax Report',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            tooltip: 'Download Sales CSV',
            onPressed: () => _downloadCsv(context, invoices, orders),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. KPI Summary Card
            Container(
              padding: const EdgeInsets.all(16),
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
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.point_of_sale_rounded, color: Color(0xFF3B82F6), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL GROSS SALES',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(totalGross),
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)),
                        ),
                        child: Text(
                          '${invoices.length} Bills',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Taxable Subtotal',
                          value: AppFormatters.compactCurrency(totalTaxable),
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'GST Collected',
                          value: AppFormatters.compactCurrency(totalGst),
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                      Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Realized Paid',
                          value: AppFormatters.compactCurrency(paidAmount),
                          color: const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Graphical Visualization: GST Tax Breakdown (CGST / SGST / IGST)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_balance_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'GST Tax Liability Split',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTaxPill('CGST (Central)', totalCgst, isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8), isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTaxPill('SGST (State)', totalSgst, isDark ? const Color(0xFF34D399) : const Color(0xFF059669), isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFECFDF5)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildTaxPill('IGST (Interstate)', totalIgst, isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706), isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          if (totalCgst > 0)
                            Expanded(
                              flex: (totalCgst * 100).toInt(),
                              child: Container(color: const Color(0xFF1D4ED8)),
                            ),
                          if (totalSgst > 0)
                            Expanded(
                              flex: (totalSgst * 100).toInt(),
                              child: Container(color: const Color(0xFF059669)),
                            ),
                          if (totalIgst > 0)
                            Expanded(
                              flex: (totalIgst * 100).toInt(),
                              child: Container(color: const Color(0xFFD97706)),
                            ),
                          if (totalGst == 0)
                            Expanded(child: Container(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Graphical Visualization: Top Buying Retailers Leaderboard
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.leaderboard_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Top 5 Purchasing Retailers',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (topBuyers.isEmpty)
                    const Text('No sales records available', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                  else
                    ...topBuyers.asMap().entries.map((item) {
                      final rank = item.key + 1;
                      final buyer = item.value;
                      final count = buyerCounts[buyer.key] ?? 0;
                      final pct = totalGross > 0 ? (buyer.value / totalGross) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: rank == 1 ? const Color(0xFF1E56E2) : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                        shape: BoxShape.circle,
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        '$rank',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: rank == 1 ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      buyer.key,
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Text('$count bills • ', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                                    Text(
                                      AppFormatters.currency(buyer.value),
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF059669)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Invoices List with Search
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sales Invoice Register',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  '${filtered.length} of ${invoices.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search invoice # or retailer name...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A), width: 1.5)),
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: ['All', 'Paid', 'Pending'].map((st) {
                final isSel = _statusFilter == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(st),
                    selected: isSel,
                    onSelected: (_) => setState(() => _statusFilter = st),
                    selectedColor: isDark ? const Color(0xFF2563EB) : AppTheme.yellowPrimary,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    labelStyle: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                      color: isSel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF0F172A)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            ...filtered.map((inv) {
              final isPaid = inv.paymentStatus.toLowerCase() == 'paid';
              final bName = inv.buyer['businessName'] ?? 'Customer Account';

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isPaid
                            ? (isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFFFBEB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isPaid ? Icons.check_circle_rounded : Icons.pending_actions_rounded,
                        color: isPaid ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20,
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
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isPaid
                                      ? (isDark ? const Color(0xFF065F46).withValues(alpha: 0.4) : const Color(0xFFDCFCE7))
                                      : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isPaid ? 'PAID' : 'PENDING',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: isPaid ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            bName,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tax: ₹${inv.totalGst.toStringAsFixed(1)} | ${AppFormatters.date(inv.invoiceDate)}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.currency(inv.grandTotal),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 4),
                        InkWell(
                          onTap: () => GstTaxInvoiceViewer.show(context, inv),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'View Bill',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),

            // Primary Bottom CSV Download Button
            ElevatedButton.icon(
              icon: const Icon(Icons.file_download_rounded, size: 20),
              label: const Text(
                'Download Deep Sales & GST Tax Register CSV',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              onPressed: () => _downloadCsv(context, invoices, orders),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({required String label, required String value, required Color color}) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: color),
        ),
      ],
    );
  }

  Widget _buildTaxPill(String title, double amount, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: fg)),
          const SizedBox(height: 2),
          Text(
            AppFormatters.compactCurrency(amount),
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: fg),
          ),
        ],
      ),
    );
  }

  void _downloadCsv(BuildContext context, List<InvoiceModel> invoices, List<dynamic> orders) {
    final csv = CsvReportHelper.generateSalesCsv(
      invoices: invoices,
      orders: orders.cast(),
    );
    CsvReportHelper.downloadOrCopyCsv(
      context,
      reportTitle: 'Sales & GST Tax Register',
      fileName: 'sales_gst_register_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csv,
      totalRows: invoices.length,
    );
  }
}
