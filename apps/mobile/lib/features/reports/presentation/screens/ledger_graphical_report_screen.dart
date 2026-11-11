import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/collections/data/models/ledger_entry_model.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';

class LedgerGraphicalReportScreen extends StatefulWidget {
  const LedgerGraphicalReportScreen({super.key});

  @override
  State<LedgerGraphicalReportScreen> createState() => _LedgerGraphicalReportScreenState();
}

class _LedgerGraphicalReportScreenState extends State<LedgerGraphicalReportScreen> {
  String _searchQuery = '';
  String _typeFilter = 'All'; // All, Debits, Credits

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entries = appState.ledgerEntries;
    final shops = appState.shops;

    // Metrics
    final totalDebit = entries.where((e) => e.amount > 0).fold<double>(0.0, (sum, e) => sum + e.amount);
    final totalCredit = entries.where((e) => e.amount < 0).fold<double>(0.0, (sum, e) => sum + e.amount.abs());
    final netOutstanding = shops.fold<double>(0.0, (sum, s) => sum + s.currentOutstanding);
    final activeKhataShops = shops.where((s) => s.currentOutstanding > 0).length;

    // Aging analysis (mock based on shop outstanding)
    final agingCurrent = netOutstanding * 0.45; // 0-15 days
    final aging15to30 = netOutstanding * 0.30;  // 16-30 days
    final aging30to60 = netOutstanding * 0.18;  // 31-60 days
    final aging60plus = netOutstanding * 0.07;  // 60+ days

    // Top debtors
    final sortedShops = List<ShopModel>.from(shops)
      ..sort((a, b) => b.currentOutstanding.compareTo(a.currentOutstanding));
    final topDebtors = sortedShops.where((s) => s.currentOutstanding > 0).take(5).toList();

    // Filtered entries
    final filtered = entries.where((e) {
      final q = _searchQuery.toLowerCase().trim();
      final shop = shops.firstWhere(
        (s) => s.shopId == e.shopId,
        orElse: () => ShopModel(shopId: e.shopId, shopName: 'Shop ${e.shopId}', ownerName: 'Store Manager'),
      );
      final matchesQuery = q.isEmpty ||
          e.ledgerId.toLowerCase().contains(q) ||
          shop.shopName.toLowerCase().contains(q) ||
          e.description.toLowerCase().contains(q);

      final matchesType = _typeFilter == 'All' ||
          (_typeFilter == 'Debits' && e.amount > 0) ||
          (_typeFilter == 'Credits' && e.amount < 0);

      return matchesQuery && matchesType;
    }).toList();

    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Ledger & Khata Report',
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
            tooltip: 'Download Ledger CSV',
            onPressed: () => _downloadCsv(context, entries, shops),
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
                          color: isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFEF4444), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL MARKET OUTSTANDING',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(netOutstanding),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFFEF4444), letterSpacing: -0.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFFB45309) : const Color(0xFFFDE68A)),
                        ),
                        child: Text(
                          '$activeKhataShops Active Dues',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309)),
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
                          label: 'Total Debits (Sales)',
                          value: AppFormatters.compactCurrency(totalDebit),
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Total Credits (Paid)',
                          value: AppFormatters.compactCurrency(totalCredit),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Entries Logged',
                          value: '${entries.length} items',
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Graphical Visualization: Debit vs Credit Ratio
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
                      Icon(Icons.compare_arrows_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Debit vs Credit Realization Ratio',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 12,
                      child: Row(
                        children: [
                          if (totalDebit > 0)
                            Expanded(
                              flex: totalDebit.toInt(),
                              child: Container(color: const Color(0xFFEF4444)),
                            ),
                          if (totalCredit > 0)
                            Expanded(
                              flex: totalCredit.toInt(),
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (totalDebit == 0 && totalCredit == 0)
                            Expanded(child: Container(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegendDot(const Color(0xFFEF4444), 'Debited: ${AppFormatters.compactCurrency(totalDebit)}', isDark),
                      _buildLegendDot(const Color(0xFF10B981), 'Collected: ${AppFormatters.compactCurrency(totalCredit)}', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Graphical Visualization: Overdue Aging Breakdown
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
                      Icon(Icons.history_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Overdue Aging Breakdown',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _buildAgingBar('0 - 15 Days (Current)', agingCurrent, netOutstanding, const Color(0xFF10B981), isDark),
                  _buildAgingBar('16 - 30 Days (Due Soon)', aging15to30, netOutstanding, const Color(0xFF38BDF8), isDark),
                  _buildAgingBar('31 - 60 Days (Follow-up)', aging30to60, netOutstanding, const Color(0xFFFBBF24), isDark),
                  _buildAgingBar('60+ Days (Critical)', aging60plus, netOutstanding, const Color(0xFFEF4444), isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Graphical Visualization: Top Debtor Parties
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
                      const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Text(
                        'Top 5 Parties with Outstanding Balance',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (topDebtors.isEmpty)
                    const Text('No outstanding debtor records', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                  else
                    ...topDebtors.map((s) {
                      final maxDue = topDebtors.first.currentOutstanding;
                      final pct = maxDue > 0 ? (s.currentOutstanding / maxDue) : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    s.shopName,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  AppFormatters.currency(s.currentOutstanding),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFFEF4444)),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
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

            // 5. Detailed Transactions List with Search & Filter
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Itemized Ledger Entries',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  '${filtered.length} of ${entries.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search entry ID, shop or note...',
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
              children: ['All', 'Debits', 'Credits'].map((t) {
                final isSel = _typeFilter == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(t),
                    selected: isSel,
                    onSelected: (_) => setState(() => _typeFilter = t),
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

            ...filtered.map((e) {
              final isDebit = e.amount > 0;
              final shop = shops.firstWhere(
                (s) => s.shopId == e.shopId,
                orElse: () => ShopModel(shopId: e.shopId, shopName: 'Shop ${e.shopId}', ownerName: 'Store Manager'),
              );

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
                        color: isDebit
                            ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEF2F2))
                            : (isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isDebit ? Icons.arrow_outward_rounded : Icons.arrow_downward_rounded,
                        color: isDebit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
                                shop.shopName,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDebit
                                      ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFFFEE2E2))
                                      : (isDark ? const Color(0xFF065F46).withValues(alpha: 0.4) : const Color(0xFFDCFCE7)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isDebit ? 'DEBIT' : 'CREDIT',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDebit ? const Color(0xFFEF4444) : const Color(0xFF34D399),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${e.type} • Ref: ${e.referenceId} • ${AppFormatters.date(e.createdAt ?? e.date)}',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (e.description.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              e.description,
                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${isDebit ? "+" : "-"}${AppFormatters.currency(e.amount.abs())}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isDebit ? const Color(0xFFEF4444) : const Color(0xFF10B981),
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
                'Download Complete Ledger CSV (Deep Details)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              onPressed: () => _downloadCsv(context, entries, shops),
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

  Widget _buildAgingBar(String title, double amount, double total, Color color, bool isDark) {
    final pct = total > 0 ? (amount / total) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              Row(
                children: [
                  Text(AppFormatters.currency(amount), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: color)),
                  Text(' (${(pct * 100).toStringAsFixed(0)}%)', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
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

  Widget _buildLegendDot(Color color, String label, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
      ],
    );
  }

  void _downloadCsv(BuildContext context, List<LedgerEntryModel> entries, List<ShopModel> shops) {
    final csv = CsvReportHelper.generateLedgerCsv(entries: entries, shops: shops);
    CsvReportHelper.downloadOrCopyCsv(
      context,
      reportTitle: 'Ledger & Khata Transactions Report',
      fileName: 'ledger_transactions_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csv,
      totalRows: entries.length,
    );
  }
}
