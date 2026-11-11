import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';

class OrdersReportScreen extends StatefulWidget {
  const OrdersReportScreen({super.key});

  @override
  State<OrdersReportScreen> createState() => _OrdersReportScreenState();
}

class _OrdersReportScreenState extends State<OrdersReportScreen> {
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final orders = appState.orders;
    final shops = appState.shops;

    // Metrics
    final totalOrders = orders.length;
    final totalGrossVolume = orders.fold<double>(0.0, (sum, o) => sum + o.grandTotal);
    final deliveredOrders = orders.where((o) => o.status.toLowerCase() == 'delivered').toList();
    final pendingOrders = orders.where((o) => o.status.toLowerCase() != 'delivered' && o.status.toLowerCase() != 'cancelled').toList();
    final aov = totalOrders > 0 ? (totalGrossVolume / totalOrders) : 0.0;

    // Top selling items
    final Map<String, int> itemUnits = {};
    final Map<String, double> itemRevenue = {};
    for (final o in orders) {
      for (final item in o.items) {
        final name = item.productName;
        itemUnits[name] = (itemUnits[name] ?? 0) + item.quantity;
        itemRevenue[name] = (itemRevenue[name] ?? 0.0) + item.total;
      }
    }
    final sortedItems = itemUnits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topItems = sortedItems.take(5).toList();

    // Filtered
    final filtered = orders.where((o) {
      final q = _searchQuery.toLowerCase().trim();
      final shop = shops.firstWhere(
        (s) => s.shopId == o.shopId,
        orElse: () => ShopModel(shopId: o.shopId, shopName: 'Shop ${o.shopId}', ownerName: 'Store Manager'),
      );
      final matchesQuery = q.isEmpty ||
          o.orderId.toLowerCase().contains(q) ||
          shop.shopName.toLowerCase().contains(q) ||
          shop.ownerName.toLowerCase().contains(q);
      final matchesStatus = _statusFilter == 'All' ||
          o.status.toLowerCase() == _statusFilter.toLowerCase();
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
          'Orders & Volume Report',
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
            tooltip: 'Download Orders CSV',
            onPressed: () => _downloadCsv(context, orders, shops),
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
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : AppTheme.yellowSurface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.shopping_bag_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF0F172A), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'TOTAL ORDERED VOLUME',
                              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              AppFormatters.currency(totalGrossVolume),
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
                          '$totalOrders Orders',
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
                          label: 'Avg Order Value',
                          value: AppFormatters.compactCurrency(aov),
                          color: const Color(0xFF10B981),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Delivered',
                          value: '${deliveredOrders.length} orders',
                          color: const Color(0xFF38BDF8),
                        ),
                      ),
                      Container(width: 1, height: 32, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      Expanded(
                        child: _buildMetricTile(
                          label: 'Pending Dispatch',
                          value: '${pendingOrders.length} orders',
                          color: const Color(0xFFFBBF24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Graphical Visualization: Order Status Funnel
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
                      Icon(Icons.tune_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Fulfillment Status Distribution',
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
                          if (deliveredOrders.isNotEmpty)
                            Expanded(
                              flex: deliveredOrders.length,
                              child: Container(color: const Color(0xFF10B981)),
                            ),
                          if (pendingOrders.isNotEmpty)
                            Expanded(
                              flex: pendingOrders.length,
                              child: Container(color: const Color(0xFFF59E0B)),
                            ),
                          if (totalOrders == 0)
                            Expanded(child: Container(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLegendDot(const Color(0xFF10B981), 'Delivered (${deliveredOrders.length})', isDark),
                      _buildLegendDot(const Color(0xFFF59E0B), 'In-Progress / Pending (${pendingOrders.length})', isDark),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Graphical Visualization: Top Ordered SKUs
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
                      Icon(Icons.star_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      const SizedBox(width: 8),
                      Text(
                        'Top 5 Ordered FMCG Items',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (topItems.isEmpty)
                    const Text('No order line items recorded', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))
                  else
                    ...topItems.map((entry) {
                      final maxUnits = topItems.first.value;
                      final pct = maxUnits > 0 ? (entry.value / maxUnits) : 0.0;
                      final rev = itemRevenue[entry.key] ?? 0.0;

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
                                    entry.key,
                                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: [
                                    Text(
                                      '${entry.value} units • ',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8)),
                                    ),
                                    Text(
                                      AppFormatters.compactCurrency(rev),
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
                                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
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

            // 4. Detailed Orders Register with Search
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Orders Register',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                Text(
                  '${filtered.length} of $totalOrders',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: 'Search order # or shop name...',
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
              children: ['All', 'Delivered', 'Pending'].map((st) {
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

            ...filtered.map((o) {
              final isDelivered = o.status.toLowerCase() == 'delivered';
              final shop = shops.firstWhere(
                (s) => s.shopId == o.shopId,
                orElse: () => ShopModel(shopId: o.shopId, shopName: 'Shop ${o.shopId}', ownerName: 'Store Manager'),
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
                        color: isDelivered
                            ? (isDark ? const Color(0xFF065F46).withValues(alpha: 0.3) : const Color(0xFFECFDF5))
                            : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        isDelivered ? Icons.local_shipping_rounded : Icons.schedule_rounded,
                        color: isDelivered ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
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
                                o.orderId,
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: isDelivered
                                      ? (isDark ? const Color(0xFF065F46).withValues(alpha: 0.4) : const Color(0xFFDCFCE7))
                                      : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  o.status.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w900,
                                    color: isDelivered ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            shop.shopName,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${o.items.length} items • ${AppFormatters.date(o.createdAt)}',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          AppFormatters.currency(o.grandTotal),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tax: ₹${o.totalGst.toStringAsFixed(1)}',
                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                'Download Deep Orders Register CSV (Itemized)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              onPressed: () => _downloadCsv(context, orders, shops),
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

  void _downloadCsv(BuildContext context, List<OrderModel> orders, List<ShopModel> shops) {
    final csv = CsvReportHelper.generateOrdersCsv(orders: orders, shops: shops);
    CsvReportHelper.downloadOrCopyCsv(
      context,
      reportTitle: 'Orders & Volume Register',
      fileName: 'orders_register_${DateTime.now().millisecondsSinceEpoch}.csv',
      csvContent: csv,
      totalRows: orders.length,
    );
  }
}
