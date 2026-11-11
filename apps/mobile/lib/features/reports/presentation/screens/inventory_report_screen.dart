import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';

class InventoryReportScreen extends StatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  String _searchQuery = '';
  String _selectedCategoryFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final products = appState.products;

    // Calculations
    final totalValuation = products.fold<double>(0.0, (sum, p) => sum + (p.stockQuantity * p.basePrice));
    final totalWholesaleValuation = products.fold<double>(0.0, (sum, p) => sum + (p.stockQuantity * p.wholesalePrice));
    final totalUnits = products.fold<int>(0, (sum, p) => sum + p.stockQuantity);
    final lowStockCount = products.where((p) => p.stockQuantity > 0 && p.stockQuantity <= p.lowStockAlertQty).length;
    final outOfStockCount = products.where((p) => p.stockQuantity <= 0).length;
    final healthyCount = products.where((p) => p.stockQuantity > p.lowStockAlertQty).length;

    // Category breakdown
    final Map<String, double> categoryValuations = {};
    final Map<String, int> categoryCounts = {};
    for (final p in products) {
      final cat = p.categoryId ?? 'General';
      final val = p.stockQuantity * p.basePrice;
      categoryValuations[cat] = (categoryValuations[cat] ?? 0.0) + val;
      categoryCounts[cat] = (categoryCounts[cat] ?? 0) + 1;
    }
    final sortedCategories = categoryValuations.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Filtered list
    final filtered = products.where((p) {
      final q = _searchQuery.toLowerCase().trim();
      final matchesQuery = q.isEmpty ||
          p.name.toLowerCase().contains(q) ||
          (p.sku?.toLowerCase().contains(q) ?? false) ||
          (p.categoryId?.toLowerCase().contains(q) ?? false);
      final matchesCat = _selectedCategoryFilter == 'All' || p.categoryId == _selectedCategoryFilter;
      return matchesQuery && matchesCat;
    }).toList();

    final allCategories = ['All', ...categoryValuations.keys];

    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Inventory & Valuation Report',
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
            tooltip: 'Download CSV',
            onPressed: () => _downloadCsv(context, products),
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
            // 1. KPI Summary Strip
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
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : AppTheme.yellowSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.inventory_2_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL IN-HAND VALUATION',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(totalValuation),
                              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: -0.5),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF2563EB) : const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '${products.length} SKUs',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
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
                          label: 'Wholesale Value',
                          value: AppFormatters.compactCurrency(totalWholesaleValuation),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Total Units',
                          value: totalUnits.toString(),
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Low Stock',
                          value: '$lowStockCount SKUs',
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Graphical Visualization: Stock Health Gauge
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
                      Icon(Icons.pie_chart_outline_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Stock Health Status Distribution',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          if (healthyCount > 0)
                            Expanded(
                              flex: healthyCount,
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (lowStockCount > 0)
                            Expanded(
                              flex: lowStockCount,
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                          if (outOfStockCount > 0)
                            Expanded(
                              flex: outOfStockCount,
                              child: Container(color: const Color(0xFFEF4444)),
                            ),
                          if (products.isEmpty)
                            Expanded(
                              child: Container(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegendDot(const Color(0xFF10B981), 'Healthy ($healthyCount)', isDark),
                      _buildLegendDot(const Color(0xFFF59E0B), 'Low Stock ($lowStockCount)', isDark),
                      _buildLegendDot(const Color(0xFFEF4444), 'Out of Stock ($outOfStockCount)', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Graphical Visualization: Category Valuation Bars
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
                      Icon(Icons.bar_chart_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Stock Valuation by Category',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (sortedCategories.isEmpty)
                    const Text('No inventory data to display', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                  else
                    ...sortedCategories.map((entry) {
                      final pct = totalValuation > 0 ? (entry.value / totalValuation) : 0.0;
                      final count = categoryCounts[entry.key] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  entry.key,
                                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '$count items • ',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                    ),
                                    Text(
                                      AppFormatters.compactCurrency(entry.value),
                                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    ),
                                    Text(
                                      ' (${(pct * 100).toStringAsFixed(0)}%)',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 8,
                                backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
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

            // 4. Detailed Line-by-Line SKU Register with Search
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Itemized SKU Register',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  '${filtered.length} of ${products.length}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Search Bar & Category Filter
            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search SKU code, name or category...',
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

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allCategories.map((c) {
                  final isSel = _selectedCategoryFilter == c;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(c),
                      selected: isSel,
                      onSelected: (_) => setState(() => _selectedCategoryFilter = c),
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
            ),
            const SizedBox(height: 12),

            // Product Cards List
            ...filtered.map((p) {
              final val = p.stockQuantity * p.basePrice;
              final isLow = p.stockQuantity <= p.lowStockAlertQty;
              final isOut = p.stockQuantity <= 0;

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
                        color: isOut
                            ? (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.3) : const Color(0xFFFEE2E2))
                            : isLow
                                ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7))
                                : (isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFECFDF5)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isOut
                            ? Icons.warning_amber_rounded
                            : isLow
                                ? Icons.access_time_rounded
                                : Icons.check_circle_outline_rounded,
                        color: isOut
                            ? const Color(0xFFEF4444)
                            : isLow
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.name,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'SKU: ${p.sku} • ${p.variant ?? p.size ?? "Standard"} • ${p.categoryId ?? "General"}',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Base: ₹${p.basePrice.toStringAsFixed(1)} | Whsl: ₹${p.wholesalePrice.toStringAsFixed(1)} | GST: ${p.gstRate.toInt()}%',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${p.stockQuantity} in-stock',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: isOut
                                ? const Color(0xFFEF4444)
                                : isLow
                                    ? const Color(0xFFF59E0B)
                                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Val: ${AppFormatters.compactCurrency(val)}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
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
                'Download Detailed Inventory CSV (Full Depth)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              onPressed: () => _downloadCsv(context, products),
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

  void _downloadCsv(BuildContext context, List<ProductModel> products) {
    final csv = CsvReportHelper.generateInventoryCsv(products: products);
    CsvReportHelper.downloadOrCopyCsv(
      context,
      reportTitle: 'Inventory Stock Valuation Report',
      fileName: 'inventory_valuation_register_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csv,
      totalRows: products.length,
    );
  }
}
