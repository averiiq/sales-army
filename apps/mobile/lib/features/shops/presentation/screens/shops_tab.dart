import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/features/shops/presentation/screens/shop_detail_screen.dart';
import 'package:salesarmy/features/shops/presentation/dialogs/add_shop_dialog.dart';
import 'package:salesarmy/core/theme/app_theme.dart';

class ShopsTab extends StatefulWidget {
  final Function(ShopModel)? onStartOrderForShop;
  final VoidCallback? onBack;

  const ShopsTab({super.key, this.onStartOrderForShop, this.onBack});

  @override
  State<ShopsTab> createState() => _ShopsTabState();
}

class _ShopsTabState extends State<ShopsTab> {
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Kirana Store',
    'Supermarket',
    'Dairy',
    'Wholesale',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    final shops = appState.shops.where((s) {
      final matchesCategory = _selectedCategory == 'All' ||
          (s.businessType ?? '').toLowerCase().contains(_selectedCategory.toLowerCase()) ||
          (_selectedCategory == 'Kirana Store' && (s.businessType ?? '').toLowerCase().contains('kirana'));
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty ||
          s.shopName.toLowerCase().contains(q) ||
          s.ownerName.toLowerCase().contains(q) ||
          (s.phone ?? '').contains(q) ||
          (s.address ?? '').toLowerCase().contains(q);
      return matchesCategory && matchesSearch;
    }).toList();

    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() {});
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 1. Search Bar & Category Filter Strip (Sliver)
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Capsule Search Input (with optional back button)
                      Row(
                        children: [
                          if (widget.onBack != null) ...[
                            Material(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              shape: const CircleBorder(),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onBack!();
                                },
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                  child: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                              ),
                              child: TextField(
                                onChanged: (val) => setState(() => _searchQuery = val),
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search shop name, owner, phone, or area...',
                                  hintStyle: TextStyle(
                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    fontSize: 13,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search_rounded,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    size: 20,
                                  ),
                                  suffixIcon: _searchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: Icon(
                                            Icons.clear_rounded,
                                            size: 18,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                          onPressed: () => setState(() => _searchQuery = ''),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Category Filter Pills
                      SizedBox(
                        height: 36,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _categories.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, i) {
                            final cat = _categories[i];
                            final isSelected = _selectedCategory == cat;
                            final count = cat == 'All'
                                ? appState.shops.length
                                : appState.shops.where((s) =>
                                    (s.businessType ?? '').toLowerCase().contains(cat.toLowerCase()) ||
                                    (cat == 'Kirana Store' && (s.businessType ?? '').toLowerCase().contains('kirana'))
                                  ).length;

                            return InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedCategory = cat);
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.6) : const Color(0xFFEFF6FF))
                                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2))
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        cat,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected
                                              ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2))
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? (isDark ? const Color(0xFF2563EB).withValues(alpha: 0.4) : const Color(0xFFDBEAFE))
                                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$count',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: isSelected
                                              ? (isDark ? Colors.white : const Color(0xFF1D4ED8))
                                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Metrics & Count Summary Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${shops.length} Retail Outlets showing',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.route_outlined, size: 13, color: Color(0xFF1E56E2)),
                              const SizedBox(width: 4),
                              Text(
                                '$_selectedCategory Beat',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E56E2),
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

              // 2. Retailer Cards List (Enlarged Cards)
              if (shops.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: const Icon(Icons.storefront_outlined, size: 32, color: Color(0xFF1E56E2)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No retail outlets found',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap "+" button below to register a new shop with GPS & photo.',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) {
                        final shop = shops[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildEnlargedShopCard(context, shop, isDark: isDark),
                        );
                      },
                      childCount: shops.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),

      // Circular Royal Blue FAB (Owner & Field Sales Only)
      floatingActionButton: (appState.isOwnerRole || appState.isFieldSalesRole)
          ? FloatingActionButton(
              heroTag: 'fab_shops_tab',
              backgroundColor: const Color(0xFF1E56E2),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              onPressed: () => showAddShopDialog(context),
              child: const Icon(Icons.add, size: 28),
            )
          : null,
    );
  }

  // Enlarged, premium shop card with storefront image, GPS badge, and large touch targets
  Widget _buildEnlargedShopCard(BuildContext context, ShopModel shop, {bool isDark = false}) {
    final hasDues = shop.currentOutstanding > 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: AppTheme.softShadow(blur: 16, dy: 5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Body (Tappable -> Opens ShopDetailScreen)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ShopDetailScreen(
                      shop: shop,
                      onStartOrder: widget.onStartOrderForShop,
                    ),
                  ),
                );
              },
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent Storefront Image / Avatar (58x58 Circular)
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFDBEAFE),
                            width: 2.0,
                          ),
                          image: shop.imageUrl != null && shop.imageUrl!.isNotEmpty
                              ? DecorationImage(
                                  image: AppImageHelper.getImageProvider(shop.imageUrl!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E56E2).withValues(alpha: 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: shop.imageUrl == null || shop.imageUrl!.isEmpty
                            ? Icon(
                                Icons.storefront_rounded,
                                color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                                size: 28,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),

                      // Shop Name, Category & Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    shop.shopName,
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onSelected: (val) {
                                    if (val == 'edit') {
                                      showAddShopDialog(context, existingShop: shop);
                                    } else if (val == 'delete') {
                                      _confirmDeleteShop(context, shop);
                                    }
                                  },
                                  itemBuilder: (_) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 16, color: Color(0xFF1E56E2)),
                                          SizedBox(width: 8),
                                          Text('Edit Outlet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFDC2626)),
                                          SizedBox(width: 8),
                                          Text('Delete Outlet', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${shop.ownerName} • ${shop.sellerCategory ?? "Retailer"} (${shop.businessType ?? "Kirana"})',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (shop.address != null && shop.address!.trim().isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.location_on_outlined, size: 13, color: Color(0xFF94A3B8)),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      shop.address!.trim(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                      ),
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

                  // Pill Badges: Status, Seller Category & Outstanding Dues Badge (Wrap-Safe)
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      // Outlet Status & Seller Category Pills
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified_rounded, size: 13, color: Color(0xFF10B981)),
                                const SizedBox(width: 5),
                                Text(
                                  'Verified',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: (shop.sellerCategory == 'Wholesaler')
                                  ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF))
                                  : (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.3) : const Color(0xFFF0FDF4)),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (shop.sellerCategory == 'Wholesaler')
                                    ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFFBFDBFE))
                                    : (isDark ? const Color(0xFF10B981) : const Color(0xFFBBF7D0)),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (shop.sellerCategory == 'Wholesaler') ? Icons.warehouse_rounded : Icons.storefront_rounded,
                                  size: 12,
                                  color: (shop.sellerCategory == 'Wholesaler')
                                      ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
                                      : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D)),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shop.sellerCategory ?? 'Retailer',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: (shop.sellerCategory == 'Wholesaler')
                                        ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF))
                                        : (isDark ? const Color(0xFF6EE7B7) : const Color(0xFF15803D)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Due Badge or Settled Badge
                      if (hasDues)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Text(
                            'Due: ${AppFormatters.compactCurrency(shop.currentOutstanding)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFFBF4),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Text(
                            'Settled (₹0 Due)',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF16A34A),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

          Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),

          // Bottom Action Strip (Responsive & Overflow-Safe)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                // Visit Frequency
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      'Visit: ${shop.visitFrequency.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),

                // Action Buttons: WhatsApp, Call, New Order
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // WhatsApp Chat Button
                    InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening WhatsApp for ${shop.shopName}...')),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.chat_bubble_rounded, size: 17, color: Color(0xFF10B981)),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Call Button
                    OutlinedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Calling ${shop.ownerName} (${shop.phone ?? ""})...')),
                        );
                      },
                      icon: const Icon(Icons.phone_rounded, size: 13, color: Color(0xFF1E56E2)),
                      label: const Text('Call', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1E56E2))),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 36),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Action button: Role-Tailored (New Order for Sales/Owner, Directions for Delivery, View for others)
                    Builder(
                      builder: (ctx) {
                        final appState = Provider.of<AppState>(context, listen: false);
                        final canTakeOrder = appState.isOwnerRole || appState.isFieldSalesRole;

                        if (canTakeOrder) {
                          return ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              if (widget.onStartOrderForShop != null) {
                                widget.onStartOrderForShop!(shop);
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ShopDetailScreen(shop: shop),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.shopping_cart_outlined, size: 13, color: Colors.white),
                            label: const Text('New Order', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E56E2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 36),
                              elevation: 0,
                            ),
                          );
                        }

                        if (appState.isDeliveryRole) {
                          return ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Opening Navigation Route to ${shop.shopName}...'),
                                  backgroundColor: const Color(0xFF1E56E2),
                                ),
                              );
                            },
                            icon: const Icon(Icons.directions_rounded, size: 14, color: Colors.white),
                            label: const Text('Directions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E56E2),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: const Size(0, 36),
                              elevation: 0,
                            ),
                          );
                        }

                        return ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShopDetailScreen(shop: shop),
                              ),
                            );
                          },
                          icon: const Icon(Icons.visibility_outlined, size: 14, color: Colors.white),
                          label: const Text('View Shop', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E56E2),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: const Size(0, 36),
                            elevation: 0,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteShop(BuildContext context, ShopModel shop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Shop?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to permanently delete "${shop.shopName}"?'),
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
}
