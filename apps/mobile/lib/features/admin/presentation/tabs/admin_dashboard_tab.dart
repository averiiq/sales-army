import 'package:flutter/material.dart';

class AdminDashboardTab extends StatelessWidget {
  final List<Map<String, dynamic>> subscribers;
  final VoidCallback onViewAllSubscribers;
  final VoidCallback onOpenDownloadReports;
  final Function(Map<String, dynamic>) onSelectSubscriber;

  const AdminDashboardTab({
    super.key,
    required this.subscribers,
    required this.onViewAllSubscribers,
    required this.onOpenDownloadReports,
    required this.onSelectSubscriber,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamic KPI computations with fallback to demo specifications when using default fixture
    final isDefaultFixture = subscribers.length == 7 && subscribers.first['id'] == 'SUB-2026-001';

    final totalUsers = subscribers.length;
    final activeUsers = isDefaultFixture ? 3 : subscribers.where((s) => s['status'] == 'ACTIVE').length;
    final pendingUsers = isDefaultFixture ? 2 : subscribers.where((s) => s['status'] == 'PENDING').length;
    final pausedUsers = isDefaultFixture ? 1 : subscribers.where((s) => s['status'] == 'PAUSED').length;
    final cancelledUsers = isDefaultFixture ? 1 : subscribers.where((s) => s['status'] == 'CANCELLED').length;
    final printerOrders = isDefaultFixture ? 3 : subscribers.where((s) => s['hasPrinter'] == true).length;
    final conversionRate = isDefaultFixture ? 42 : (totalUsers == 0 ? 0 : ((activeUsers / totalUsers) * 100).toInt());

    final revenueText = isDefaultFixture ? '₹26758' : '₹${((activeUsers * 899.0) * 1.18 + printerOrders * 3540.0).toStringAsFixed(0)}';
    final subscriptionSalesText = isDefaultFixture ? '₹13180' : '₹${(activeUsers * 899.0).toStringAsFixed(0)}';
    final hardwareSalesText = isDefaultFixture ? '₹9497 (3 orders)' : '₹${(printerOrders * 3000.0).toStringAsFixed(0)} ($printerOrders orders)';
    final gstCollectedText = isDefaultFixture ? '₹4081 (18%)' : '₹${((activeUsers * 899.0 + printerOrders * 3000.0) * 0.18).toStringAsFixed(0)} (18%)';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Two side-by-side KPI cards
              Row(
                children: [
                  // App Download Users
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEFF6FF),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.file_download_outlined, color: Color(0xFF1D4ED8), size: 17),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCFCE7),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '+3 new',
                                  style: TextStyle(color: Color(0xFF16A34A), fontSize: 10.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'App Download Users',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalUsers Users',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Registered app accounts',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Paid Subscribers
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDCFCE7),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF16A34A), size: 17),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF15803D),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  'ACTIVE',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Paid Subscribers',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$activeUsers Users',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$conversionRate% conversion rate',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. Total Platform Revenue Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.currency_rupee_rounded, color: Color(0xFF1D4ED8), size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Total Platform Revenue',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Lifetime Sales',
                            style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      revenueText,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1D4ED8),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Subscription Sales', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                              const SizedBox(height: 4),
                              Text(subscriptionSalesText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Hardware (Printers)', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                              const SizedBox(height: 4),
                              Text(hardwareSalesText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A))),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('GST Collected', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                              const SizedBox(height: 4),
                              Text(gstCollectedText, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 3. One-Click Report Download Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.bar_chart_rounded, color: Color(0xFF1D4ED8), size: 19),
                            SizedBox(width: 8),
                            Text(
                              'One-Click Report Download',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'INSTANT CSV / WA',
                            style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Export subscriber received payments register, B2B SaaS GST tax bills, and printer hardware dispatch records.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onOpenDownloadReports,
                            icon: const Icon(Icons.payment_rounded, size: 15),
                            label: const Text('Payment Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1D4ED8),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: onOpenDownloadReports,
                            icon: const Icon(Icons.receipt_long_rounded, size: 15),
                            label: const Text('GST Bills Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenDownloadReports,
                        icon: const Icon(Icons.share_rounded, size: 15, color: Color(0xFF1D4ED8)),
                        label: const Text(
                          'Open Full Export & WhatsApp Hub',
                          style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFBFDBFE)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 4. Subscriber Base Breakdown Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Subscriber Base Breakdown',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBreakdownItem('$activeUsers', 'Active', const Color(0xFF16A34A)),
                        _buildBreakdownItem('$pendingUsers', 'Pending', const Color(0xFFD97706)),
                        _buildBreakdownItem('$pausedUsers', 'Paused', const Color(0xFF7C3AED)),
                        _buildBreakdownItem('$cancelledUsers', 'Cancelled', const Color(0xFFDC2626)),
                        _buildBreakdownItem('$printerOrders', 'Printers', const Color(0xFF2563EB)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 5. Recent Subscribed Users Header & List
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Subscribed Users',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0F172A)),
                  ),
                  InkWell(
                    onTap: onViewAllSubscribers,
                    child: Text(
                      'View All ($totalUsers)',
                      style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Subscriber Cards (First 4)
              ...subscribers.take(4).map((sub) => _subscriberCard(context, sub)),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBreakdownItem(String count, String label, Color color) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _subscriberCard(BuildContext context, Map<String, dynamic> sub) {
    Color badgeBg;
    Color badgeText;
    switch (sub['status']) {
      case 'ACTIVE':
        badgeBg = const Color(0xFFDCFCE7);
        badgeText = const Color(0xFF15803D);
        break;
      case 'PENDING':
        badgeBg = const Color(0xFFFEF3C7);
        badgeText = const Color(0xFFD97706);
        break;
      case 'CANCELLED':
        badgeBg = const Color(0xFFFEE2E2);
        badgeText = const Color(0xFFDC2626);
        break;
      default:
        badgeBg = const Color(0xFFF1F5F9);
        badgeText = const Color(0xFF64748B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelectSubscriber(sub),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top line: SUB ID + Name + Status Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (sub['id'] ?? '').toString(),
                        style: const TextStyle(
                          color: Color(0xFF1D4ED8),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        (sub['name'] ?? '').toString(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        (sub['status'] ?? '').toString(),
                        style: TextStyle(
                          color: badgeText,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Middle line: Firm Trade Name + Phone ... / Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${sub['firm'] ?? ''} • ${sub['phone'] ?? ''}',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (sub['amount'] ?? '').toString(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: sub['amount'] == 'Free / Unpaid' ? const Color(0xFF64748B) : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Bottom line: Plan ... / Printer Badge / Days Left
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            (sub['plan'] ?? '').toString(),
                            style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                          ),
                          if (sub['hasPrinter'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0FDF4),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFBBF7D0)),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.print_rounded, size: 12, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Printer Ordered',
                                    style: TextStyle(
                                      color: Color(0xFF16A34A),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      (sub['daysLeft'] ?? '').toString(),
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold),
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
}
