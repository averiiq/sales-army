import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/ledger_report_modal.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/collect_payment_dialog.dart';

class CollectionsTab extends StatefulWidget {
  final VoidCallback? onBack;
  final int initialTabIndex;

  const CollectionsTab({
    super.key,
    this.onBack,
    this.initialTabIndex = 0,
  });

  @override
  State<CollectionsTab> createState() => _CollectionsTabState();
}

class _CollectionsTabState extends State<CollectionsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _duesFilters = [
    'All',
    'High Due (> ₹5k)',
    'Kirana Store',
    'Supermarket',
    'Wholesale',
  ];

  final List<String> _paymentFilters = [
    'All',
    'Cash',
    'Online / UPI',
  ];

  List<String> get _currentFilterList {
    if (_tabController.index == 0) return _duesFilters;
    return _paymentFilters;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
    _tabController.addListener(() {
      if (mounted) {
        if (!_currentFilterList.contains(_selectedFilter)) {
          _selectedFilter = 'All';
        }
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showCollectPaymentModal(BuildContext context, ShopModel shop, {double? initialAmount, String? orderId}) {
    showCollectPaymentDialog(
      context,
      shop,
      initialAmount: initialAmount,
      orderId: orderId,
    );
  }

  void _showGatewayPaymentModal(BuildContext context, ShopModel shop, {double? initialAmount, String? orderId}) {
    showGatewayPaymentDialog(
      context,
      shop,
      initialAmount: initialAmount,
      orderId: orderId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final totalOutstanding = appState.totalOutstanding;
    final totalPayments = appState.payments.fold<double>(0.0, (acc, p) => acc + p.amount);

    final cashPayments = appState.payments
        .where((p) => p.paymentMode.toLowerCase() == 'cash')
        .fold<double>(0.0, (acc, p) => acc + p.amount);
    final displayCash = cashPayments;
    final onlinePayments = appState.payments
        .where((p) => p.paymentMode.toLowerCase() != 'cash')
        .fold<double>(0.0, (acc, p) => acc + p.amount);

    // 1. Filter shops with dues (ensuring any shop with pending orders or unpaid invoices is included)
    final allShopsWithDues = appState.shops.where((s) => appState.getShopOutstandingDue(s) > 0).toList()
      ..sort((a, b) => appState.getShopOutstandingDue(b).compareTo(appState.getShopOutstandingDue(a)));

    final filteredShopsWithDues = allShopsWithDues.where((s) {
      final q = _searchQuery.toLowerCase();
      final due = appState.getShopOutstandingDue(s);
      final matchesSearch = q.isEmpty ||
          s.shopName.toLowerCase().contains(q) ||
          s.ownerName.toLowerCase().contains(q) ||
          (s.phone ?? '').contains(q) ||
          (s.address ?? '').toLowerCase().contains(q);

      bool matchesFilter = true;
      if (_selectedFilter == 'High Due (> ₹5k)') {
        matchesFilter = due >= 5000;
      } else if (_selectedFilter != 'All') {
        matchesFilter = (s.businessType ?? '').toLowerCase().contains(_selectedFilter.toLowerCase());
      }

      return matchesSearch && matchesFilter;
    }).toList();

    // 6. Filtered payments based on search & filter pill
    final filteredPayments = appState.payments.where((p) {
      final q = _searchQuery.toLowerCase();
      final shopMatches = appState.shops.where((s) => s.shopId == p.shopId);
      final shopName = shopMatches.isNotEmpty ? shopMatches.first.shopName : (p.shopId.isNotEmpty ? 'Shop #${p.shopId}' : 'Customer');
      final matchesSearch = q.isEmpty ||
          shopName.toLowerCase().contains(q) ||
          (p.referenceNumber ?? '').toLowerCase().contains(q) ||
          p.paymentMode.toLowerCase().contains(q);

      bool matchesFilter = true;
      if (_selectedFilter == 'Cash') {
        matchesFilter = p.paymentMode.toLowerCase() == 'cash';
      } else if (_selectedFilter == 'Online / UPI') {
        matchesFilter = p.paymentMode.toLowerCase() != 'cash';
      }

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getCollectionsGradient(isDark),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Optional Back Bar
              if (widget.onBack != null && Navigator.canPop(context))
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      children: [
                        Material(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          elevation: 0,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              widget.onBack?.call();
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                boxShadow: AppTheme.softShadow(blur: 6, dy: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.arrow_back_rounded, size: 16, color: isDark ? Colors.white : const Color(0xFF334155)),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Back to Dashboard',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF334155)),
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

              // 2. Executive Territory Outstanding Balance Card
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E56E2), Color(0xFF173BBF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1E56E2).withValues(alpha: 0.28),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row: Circular Icon + Title + Khata Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_outlined,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Territory Credit Outstanding',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Khata Ledger Action Button
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  LedgerReportModal.open(context, initialIsKhata: true);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.menu_book_rounded, size: 14, color: Colors.white),
                                      SizedBox(width: 6),
                                      Text(
                                        'Khata Ledger',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Grand Amount
                      Text(
                        AppFormatters.currency(totalOutstanding),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Gateway Status Strip Pill
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF4ADE80),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Razorpay Gateway Connected & Ready',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Metrics Strip with Cash, Online & Pending Bills count
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Row(
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4ADE80),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cash: ₹${displayCash.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF93C5FD),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'PG: ₹${onlinePayments.toInt()}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.storefront_rounded, size: 12, color: Color(0xFFFEF08A)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${allShopsWithDues.length} Shops Due',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Sub-Tabs Bar: Segmented Capsule with 2 Tabs
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                    tabs: [
                      Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.storefront_rounded, size: 15),
                              const SizedBox(width: 4),
                              const Text('Retailer Dues'),
                              if (allShopsWithDues.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: _tabController.index == 0
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${allShopsWithDues.length}',
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w900,
                                      color: _tabController.index == 0 ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const Tab(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_rounded, size: 15),
                              SizedBox(width: 4),
                              Text('Ledger'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Search & Filter Strip (Capsule Input + Category Pills)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Capsule Search Input
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          boxShadow: AppTheme.softShadow(blur: 6, dy: 1),
                        ),
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val),
                          style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: _tabController.index == 0
                                ? 'Search retailer name, owner, or phone...'
                                : 'Search payment reference, retailer...',
                            hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: Icon(Icons.clear_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Filter Pills
                      SizedBox(
                        height: 34,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _currentFilterList.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final f = _currentFilterList[i];
                            final isSelected = _selectedFilter == f;
                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedFilter = f);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF1E56E2))
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    f,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2))
                                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. Download Territory Dues Ledger Banner (on Retailer Dues tab)
              if (_tabController.index == 0)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFBBF7D0)),
                        boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.description_outlined, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669), size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Download Territory Dues Ledger',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Generate PDF or CSV report for all outstanding balances.',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF047857)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: const Color(0xFF059669),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                LedgerReportModal.open(context, initialIsKhata: false);
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF059669).withValues(alpha: 0.3),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.download_rounded, size: 14, color: Colors.white),
                                    SizedBox(width: 5),
                                    Text(
                                      'Export',
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
                        ],
                      ),
                    ),
                  ),
                ),

              // 6. Content Views — Pending Orders tab removed; orders now
              // flow through Billing / Orders. Only Retailer Dues (idx 0)
              // and Ledger (idx 1) render here.
              if (_tabController.index == 0) ...[
                // ==========================================
                // SUB-TAB 0: RETAILER DUES
                // ==========================================
                if (filteredShopsWithDues.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 60,
                              height: 60,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.verified_rounded, size: 30, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'All Territory Dues Settled!',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Zero pending receivables across all registered retailers.',
                              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final shop = filteredShopsWithDues[idx];
                          final shopDue = appState.getShopOutstandingDue(shop);

                          // Find specific pending orders and unpaid invoices for this retailer
                          final retailerPendingOrders = appState.orders.where((o) {
                            final isPending = o.status.toLowerCase() == 'pending' || o.status.toLowerCase() == 'confirmed';
                            final hasInv = appState.invoices.any((i) => i.orderId == o.orderId);
                            return o.shopId == shop.shopId && isPending && !hasInv;
                          }).toList();

                          final retailerUnpaidInvoices = appState.invoices.where((i) {
                            return i.shopId == shop.shopId && i.paymentStatus.toLowerCase() != 'paid' && (i.dueAmount > 0 || (i.grandTotal - i.paidAmount) > 0);
                          }).toList();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              boxShadow: AppTheme.softShadow(blur: 10, dy: 3),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Retailer Circular Avatar
                                    Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF713F12).withValues(alpha: 0.3) : const Color(0xFFFFFDEB),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: isDark ? const Color(0xFF854D0E) : const Color(0xFFFEF08A), width: 1.5),
                                      ),
                                      alignment: Alignment.center,
                                      child: shop.imageUrl != null && shop.imageUrl!.isNotEmpty
                                          ? ClipOval(
                                              child: Image.network(
                                                shop.imageUrl!,
                                                width: 52,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) => Text(
                                                  shop.shopName.isNotEmpty ? shop.shopName[0].toUpperCase() : 'S',
                                                  style: TextStyle(
                                                    fontSize: 19,
                                                    fontWeight: FontWeight.w900,
                                                    color: isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Text(
                                              shop.shopName.isNotEmpty ? shop.shopName[0].toUpperCase() : 'S',
                                              style: TextStyle(
                                                fontSize: 19,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? const Color(0xFFFDE047) : const Color(0xFF854D0E),
                                              ),
                                            ),
                                    ),
                                    const SizedBox(width: 12),

                                    // Shop Info & Due Badge
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            shop.shopName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 15.5,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${shop.ownerName} • ${shop.businessType ?? 'Retail Store'}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 6),

                                          // Due Highlight Badge
                                          Wrap(
                                            spacing: 6,
                                            runSpacing: 4,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                                                  borderRadius: BorderRadius.circular(10),
                                                  border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Due: ',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                                        fontWeight: FontWeight.w700,
                                                      ),
                                                    ),
                                                    Text(
                                                      AppFormatters.currency(shopDue),
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w900,
                                                        color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (shop.creditLimit > 0)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                                  ),
                                                  child: Text(
                                                    'Limit: ₹${shop.creditLimit.toInt()}',
                                                    style: TextStyle(
                                                      fontSize: 10.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    // Khata Ledger Quick Pill
                                    Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          LedgerReportModal.open(
                                            context,
                                            initialIsKhata: true,
                                            initialShopId: shop.shopId,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.menu_book_rounded, size: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Khata',
                                                style: TextStyle(
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Breakdown of Pending Orders for this Shop
                                if (retailerPendingOrders.isNotEmpty || retailerUnpaidInvoices.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'PENDING BILLS & ORDERS (${retailerPendingOrders.length + retailerUnpaidInvoices.length})',
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            Text(
                                              'Tap to Collect',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ...retailerPendingOrders.map((ord) => Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.shopping_bag_outlined, size: 14, color: Color(0xFFD97706)),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      '#${ord.orderId} • ${ord.items.length} items',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    AppFormatters.currency(ord.grandTotal),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: () {
                                                      HapticFeedback.lightImpact();
                                                      _showCollectPaymentModal(
                                                        context,
                                                        shop,
                                                        initialAmount: ord.grandTotal,
                                                        orderId: ord.orderId,
                                                      );
                                                    },
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF059669),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'Collect',
                                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )),
                                        ...retailerUnpaidInvoices.map((inv) => Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                              ),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.receipt_rounded, size: 14, color: Color(0xFF4F46E5)),
                                                  const SizedBox(width: 6),
                                                  Expanded(
                                                    child: Text(
                                                      'Bill #${inv.invoiceNumber}',
                                                      style: TextStyle(
                                                        fontSize: 11.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Text(
                                                    AppFormatters.currency(inv.dueAmount > 0 ? inv.dueAmount : (inv.grandTotal - inv.paidAmount)),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFDC2626),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  InkWell(
                                                    onTap: () {
                                                      HapticFeedback.lightImpact();
                                                      _showCollectPaymentModal(
                                                        context,
                                                        shop,
                                                        initialAmount: inv.dueAmount > 0 ? inv.dueAmount : (inv.grandTotal - inv.paidAmount),
                                                        orderId: inv.invoiceNumber,
                                                      );
                                                    },
                                                    borderRadius: BorderRadius.circular(8),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF059669),
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: const Text(
                                                        'Collect',
                                                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 14),
                                Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                const SizedBox(height: 12),

                                // Action Buttons: Record Payment & Collect Payment
                                Row(
                                  children: [
                                    // 1. Record Payment (Manual / Counter / Cash / Cheque / Ledger Entry)
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            _showCollectPaymentModal(
                                              context,
                                              shop,
                                              initialAmount: shopDue,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: isDark ? const Color(0xFF059669) : const Color(0xFFA7F3D0),
                                              ),
                                            ),
                                            child: FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.payments_rounded,
                                                    size: 16,
                                                    color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Record Payment',
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                                                      fontWeight: FontWeight.w800,
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
                                    const SizedBox(width: 8),

                                    // 2. Collect Payment (Major button — opens live UPI QR / Razorpay checkout modal)
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            HapticFeedback.lightImpact();
                                            _showGatewayPaymentModal(
                                              context,
                                              shop,
                                              initialAmount: shopDue,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(14),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
                                            decoration: BoxDecoration(
                                              gradient: const LinearGradient(
                                                colors: [Color(0xFF1E56E2), Color(0xFF173BBF)],
                                              ),
                                              borderRadius: BorderRadius.circular(14),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: const Color(0xFF1E56E2).withValues(alpha: 0.35),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(Icons.qr_code_2_rounded, size: 16, color: Colors.white),
                                                  SizedBox(width: 6),
                                                  Text(
                                                    'Collect Payment',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.w800,
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
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                        childCount: filteredShopsWithDues.length,
                      ),
                    ),
                  ),
              ] else ...[
                // ==========================================
                // SUB-TAB 1: PAYMENT LEDGER
                // ==========================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: AppTheme.softShadow(blur: 10, dy: 3),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL COLLECTIONS RECORDED',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                AppFormatters.currency(totalPayments),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                LedgerReportModal.open(context, initialIsKhata: false);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.download_rounded, size: 15, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Export CSV',
                                      style: TextStyle(
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
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
                ),

                if (filteredPayments.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.all(40),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          boxShadow: AppTheme.softShadow(blur: 8, dy: 2),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              const SizedBox(height: 10),
                              Text(
                                'No payments recorded yet',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                          final payment = filteredPayments[idx];
                          final shopMatches = appState.shops.where((s) => s.shopId == payment.shopId);
                          final shop = shopMatches.isNotEmpty
                              ? shopMatches.first
                              : (appState.shops.isNotEmpty
                                  ? appState.shops.first
                                  : ShopModel(
                                      shopId: payment.shopId,
                                      shopName: 'Shop #${payment.shopId}',
                                      ownerName: 'Customer',
                                      phone: '-',
                                      address: 'Direct',
                                    ));

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              child: InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  showPaymentReceiptModal(context, payment, shop);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    boxShadow: AppTheme.softShadow(blur: 6, dy: 1),
                                  ),
                                  child: Row(
                                    children: [
                                      // Circular Verified Icon
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFDCFCE7)),
                                        ),
                                        child: Icon(Icons.check_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A), size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              shop.shopName,
                                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: payment.paymentMode.toLowerCase() == 'cash'
                                                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4))
                                                        : (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF)),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: Text(
                                                    payment.paymentMode.toUpperCase(),
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: payment.paymentMode.toLowerCase() == 'cash'
                                                          ? (isDark ? const Color(0xFF34D399) : const Color(0xFF166534))
                                                          : (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF)),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    payment.referenceNumber ?? (payment.notes != null && payment.notes!.isNotEmpty ? payment.notes! : "Direct Receipt"),
                                                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 11.5),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              AppFormatters.dateTime(payment.date),
                                              style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '+ ${AppFormatters.currency(payment.amount)}',
                                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A)),
                                          ),
                                          const SizedBox(height: 5),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  showEditPaymentDialog(context, shop, payment);
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1E56E2).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Icon(Icons.edit_outlined, size: 14, color: Color(0xFF1E56E2)),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              InkWell(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  _confirmDeletePayment(context, appState, payment, shop);
                                                },
                                                borderRadius: BorderRadius.circular(6),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Icon(Icons.delete_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      'Receipt',
                                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Icon(Icons.chevron_right_rounded, size: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
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
                        },
                        childCount: filteredPayments.length,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeletePayment(BuildContext context, AppState appState, dynamic payment, ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Payment?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to delete payment of ₹${payment.amount.toStringAsFixed(0)} from ${shop.shopName}? Shop outstanding dues will be restored.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await appState.deletePayment(payment.paymentId);
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
