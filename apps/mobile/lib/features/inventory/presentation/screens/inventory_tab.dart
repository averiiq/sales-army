import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/product_image_helper.dart';
import 'package:salesarmy/core/utils/responsive_helper.dart';
import 'package:salesarmy/core/widgets/bouncing_widget.dart';

class InventoryTab extends StatefulWidget {
  final bool isStandalone;
  final VoidCallback? onBack;

  const InventoryTab({
    super.key,
    this.isStandalone = false,
    this.onBack,
  });

  @override
  State<InventoryTab> createState() => _InventoryTabState();
}

class _InventoryTabState extends State<InventoryTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _onlyLowStock = false;
  bool _isCardView = true;

  final List<String> _categories = [
    'All',
    'Home Cleaning',
    'Groceries',
    'Edible Oils',
    'Dairy',
    'Bakery',
    'Snacks',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesCategory(ProductModel p, String selected) {
    if (selected == 'All') return true;
    final cat = (p.categoryId ?? '').toLowerCase();
    final name = p.name.toLowerCase();

    switch (selected) {
      case 'Home Cleaning':
        return cat.contains('clean') ||
            cat.contains('home') ||
            name.contains('cleaner') ||
            name.contains('harpic') ||
            name.contains('lizol') ||
            name.contains('colin') ||
            name.contains('vim') ||
            name.contains('surf') ||
            name.contains('ariel') ||
            name.contains('dettol') ||
            name.contains('comfort');
      case 'Groceries':
        return cat.contains('grocer') ||
            cat.contains('atta') ||
            cat.contains('staple') ||
            name.contains('atta') ||
            name.contains('tea') ||
            name.contains('coffee') ||
            name.contains('powder') ||
            name.contains('salt') ||
            name.contains('rice') ||
            name.contains('noodle') ||
            name.contains('ketchup');
      case 'Edible Oils':
        return cat.contains('oil') || name.contains('oil') || name.contains('sunlite') || name.contains('saffola');
      case 'Dairy':
        return cat.contains('dairy') || cat.contains('milk') || name.contains('milk') || name.contains('butter');
      case 'Bakery':
        return cat.contains('bakery') ||
            cat.contains('biscuit') ||
            name.contains('biscuit') ||
            name.contains('parle') ||
            name.contains('good day') ||
            name.contains('oreo');
      case 'Snacks':
        return cat.contains('snack') ||
            cat.contains('namkeen') ||
            name.contains('bhujia') ||
            name.contains('silk') ||
            name.contains('cadbury');
      default:
        return cat == selected.toLowerCase();
    }
  }

  void _showAddEditProductModal(BuildContext context, {ProductModel? existingProduct}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditProductBottomSheet(existingProduct: existingProduct),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final allProducts = appState.products;

    final filteredProducts = allProducts.where((p) {
      if (_onlyLowStock && p.stockQuantity > p.lowStockAlertQty) return false;
      if (!_matchesCategory(p, _selectedCategory)) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = p.name.toLowerCase().contains(q);
        final matchSku = (p.sku ?? '').toLowerCase().contains(q);
        final matchHsn = (p.hsnSacCode ?? '').toLowerCase().contains(q);
        final matchCat = (p.categoryId ?? '').toLowerCase().contains(q);
        if (!matchName && !matchSku && !matchHsn && !matchCat) return false;
      }
      return true;
    }).toList();

    final lowStockCount = appState.lowStockCount;
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        backgroundColor: const Color(0xFF1E56E2),
        elevation: 4,
        onPressed: () {
          HapticFeedback.lightImpact();
          _showAddEditProductModal(context);
        },
        tooltip: 'Add Product',
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
      appBar: widget.isStandalone
          ? AppBar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onPressed: () {
                  if (widget.onBack != null) {
                    widget.onBack!();
                  } else if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              title: Text(
                'Inventory & Stock',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              centerTitle: true,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
              ),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.getInventoryGradient(isDark),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top Inventory Header: Search & Category Carousel
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: Border(
                      bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9), width: 1.0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Clean Single-Line Search Bar
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Search product, brand, SKU or HSN...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF64748B)),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Clean Category Carousel (with Low Stock Chip)
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // All Chip
                            _buildCategoryChip(
                              label: 'All (${allProducts.length})',
                              isSelected: _selectedCategory == 'All' && !_onlyLowStock,
                              onTap: () => setState(() {
                                _selectedCategory = 'All';
                                _onlyLowStock = false;
                              }),
                            ),
                            const SizedBox(width: 8),

                            // Low Stock Alert Filter Chip (if any exist)
                            if (lowStockCount > 0) ...[
                              _buildCategoryChip(
                                label: '⚠️ Low Stock ($lowStockCount)',
                                isSelected: _onlyLowStock,
                                activeColor: const Color(0xFFDC2626),
                                onTap: () => setState(() {
                                  _onlyLowStock = !_onlyLowStock;
                                  if (_onlyLowStock) _selectedCategory = 'All';
                                }),
                              ),
                              const SizedBox(width: 8),
                            ],

                            // Categories
                            ..._categories.where((c) => c != 'All').map((cat) {
                              final isSelected = _selectedCategory == cat && !_onlyLowStock;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: _buildCategoryChip(
                                  label: cat,
                                  isSelected: isSelected,
                                  onTap: () => setState(() {
                                    _selectedCategory = cat;
                                    _onlyLowStock = false;
                                  }),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sub-header stats bar & View Toggle (Card vs List View)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${filteredProducts.length} Products showing',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Tap item to edit stock',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2563EB),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildViewToggle(
                            isCardView: _isCardView,
                            onChanged: (val) => setState(() => _isCardView = val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Product Catalog: Card View (2-Column Grid) or List View
              if (filteredProducts.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 28, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No products found',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Try changing category or clearing search',
                          style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_isCardView)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    context.horizontalPadding,
                    4,
                    context.horizontalPadding,
                    96,
                  ),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: context.screenWidth >= 1200
                          ? 4
                          : (context.screenWidth >= 800
                              ? 3
                              : (context.screenWidth >= 600 ? 3 : 2)),
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: context.isCompact
                          ? 0.63
                          : (context.isTablet ? 0.72 : 0.66),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) => _buildProductCard(context, filteredProducts[idx]),
                      childCount: filteredProducts.length,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    context.horizontalPadding,
                    4,
                    context.horizontalPadding,
                    96,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, idx) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _buildProductListItem(context, filteredProducts[idx]),
                      ),
                      childCount: filteredProducts.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // 2-Column Grid Card View for Products (Modern B2B FMCG Showcase Design)
  Widget _buildProductCard(BuildContext context, ProductModel product) {
    final isLowStock = product.stockQuantity <= product.lowStockAlertQty;
    final isOutOfStock = product.stockQuantity <= 0;
    final double marginPercent = product.wholesalePrice > 0 && product.customerPrice > product.wholesalePrice
        ? (((product.customerPrice - product.wholesalePrice) / product.wholesalePrice) * 100)
        : 0.0;

    return BouncingWidget(
      scaleFactor: 0.975,
      onTap: () => _showAddEditProductModal(context, existingProduct: product),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isOutOfStock
                ? const Color(0xFFFECACA)
                : (isLowStock ? const Color(0xFFFED7AA) : const Color(0xFFE2E8F0)),
            width: isOutOfStock || isLowStock ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Product Showcase Image with Floating Badges
            Container(
              height: 110,
              width: double.infinity,
              color: const Color(0xFFF8FAFC),
              child: Stack(
                children: [
                  // Product Image (Clean contain on soft slate)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ProductImageView(
                        imageUrl: product.imageUrl,
                        productName: product.name,
                        categoryId: product.categoryId,
                        height: 94,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                  ),

                  // Top-Left: Margin Pill
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: marginPercent > 0 ? const Color(0xFFECFDF5) : Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: marginPercent > 0 ? const Color(0xFFA7F3D0) : const Color(0xFFE2E8F0),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (marginPercent > 0) ...[
                            const Icon(Icons.trending_up_rounded, size: 10.5, color: Color(0xFF059669)),
                            const SizedBox(width: 3),
                          ],
                          Text(
                            marginPercent > 0 ? '+${marginPercent.toInt()}% Margin' : '${product.gstRate.toInt()}% GST',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: marginPercent > 0 ? const Color(0xFF059669) : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Top-Right: Stock Health Indicator (Only when Out or Low) with subtle breathing animation
                  if (isOutOfStock || isLowStock)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.93, end: 1.0),
                        duration: const Duration(milliseconds: 600),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) {
                          return Transform.scale(
                            scale: scale,
                            child: child,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: isOutOfStock ? const Color(0xFFFEF2F2) : const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isOutOfStock ? const Color(0xFFFECACA) : const Color(0xFFFED7AA),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                isOutOfStock ? 'Out' : 'Low: ${product.stockQuantity}',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFFD97706),
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

            // Card Body (Information & Pricing)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Name (2 Lines Max)
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Variant / Pack Size Tag
                  if (product.variants != null && product.variants!.length > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.layers_rounded, size: 10, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              '${product.variants!.length} sizes (${product.variants!.map((v) => v.displayName).take(2).join(', ')})',
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        '${product.variant ?? product.size ?? "Standard"} • ${product.categoryId ?? "General"}',
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  const SizedBox(height: 8),

                  // Wholesale Price & MRP Row (Responsive & Overflow-Safe)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WHOLESALE',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                letterSpacing: 0.3,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'WS: ${AppFormatters.currency(product.wholesalePrice)}',
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF1E56E2),
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'MRP: ₹${product.customerPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                'Ret: ₹${product.retailPrice.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Quick Stock Action Button Pill
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: isOutOfStock
                          ? const Color(0xFFFEF2F2)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isOutOfStock ? const Color(0xFFFECACA) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isOutOfStock ? Icons.warning_amber_rounded : Icons.edit_note_rounded,
                          size: 15,
                          color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isOutOfStock ? 'Out • Restock' : 'Stock: ${product.stockQuantity}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isOutOfStock ? const Color(0xFFDC2626) : const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Refined Compact List View for Products (With Real Product Photo & Swipe Gestures)
  Widget _buildProductListItem(BuildContext context, ProductModel product) {
    final isLowStock = product.stockQuantity <= product.lowStockAlertQty;
    final isOutOfStock = product.stockQuantity <= 0;

    return Dismissible(
      key: ValueKey('dismiss_prod_${product.productId}'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Quick +5 Stock bump
          final updated = product.copyWith(
            stockQuantity: product.stockQuantity + 5,
          );
          context.read<AppState>().updateProduct(updated);
          HapticFeedback.heavyImpact();
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Added +5 units to ${product.name} (Stock: ${product.stockQuantity + 5})'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(milliseconds: 1800),
            ),
          );
          return false;
        } else if (direction == DismissDirection.endToStart) {
          // Swipe left: Edit product
          HapticFeedback.mediumImpact();
          _showAddEditProductModal(context, existingProduct: product);
          return false;
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF059669),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerLeft,
        child: const Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              '+5 Quick Stock',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E56E2),
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Edit Product',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
            SizedBox(width: 8),
            Icon(Icons.edit_note_rounded, color: Colors.white, size: 22),
          ],
        ),
      ),
      child: BouncingWidget(
        scaleFactor: 0.98,
        onTap: () => _showAddEditProductModal(context, existingProduct: product),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOutOfStock
                  ? const Color(0xFFFECACA)
                  : (isLowStock ? const Color(0xFFFED7AA) : const Color(0xFFF1F5F9)),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Refined Product Photo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(4),
                child: ProductImageView(
                  imageUrl: product.imageUrl,
                  productName: product.name,
                  categoryId: product.categoryId,
                  width: 52,
                  height: 52,
                  borderRadius: BorderRadius.circular(10),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 12),

              // Product Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.variants != null && product.variants!.length > 1
                          ? '${product.variants!.length} Variants (${product.variants!.map((v) => v.displayName).join(', ')}) • ${product.categoryId ?? "General"}'
                          : '${product.variant ?? product.size ?? "Standard"} • ${product.categoryId ?? "General"} • ${product.gstRate.toInt()}% GST',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? const Color(0xFFFEF2F2)
                            : (isLowStock ? const Color(0xFFFFFBEB) : const Color(0xFFF0FDF4)),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: isOutOfStock
                              ? const Color(0xFFFECACA)
                              : (isLowStock ? const Color(0xFFFED7AA) : const Color(0xFFBBF7D0)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: isOutOfStock
                                  ? const Color(0xFFDC2626)
                                  : (isLowStock ? const Color(0xFFD97706) : const Color(0xFF16A34A)),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isOutOfStock
                                ? 'Out of stock'
                                : (isLowStock ? 'Low: ${product.stockQuantity}' : '${product.stockQuantity} in stock'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isOutOfStock
                                  ? const Color(0xFFDC2626)
                                  : (isLowStock ? const Color(0xFFD97706) : const Color(0xFF15803D)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Price Column
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'WS: ${AppFormatters.currency(product.wholesalePrice)}',
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D4ED8),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Ret: ₹${product.retailPrice.toStringAsFixed(1)} • MRP: ₹${product.customerPrice.toStringAsFixed(1)}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.edit_note_rounded, size: 14, color: Color(0xFF1D4ED8)),
                        SizedBox(width: 2),
                        Text(
                          'Edit',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
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
      ),
    );
  }

  // Reusable Card vs List View Toggle Capsule
  Widget _buildViewToggle({
    required bool isCardView,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Card View Icon
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(true);
            },
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: isCardView ? const Color(0xFF1D4ED8) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.grid_view_rounded,
                size: 16,
                color: isCardView ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(width: 2),
          // List View Icon
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onChanged(false);
            },
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
              decoration: BoxDecoration(
                color: !isCardView ? const Color(0xFF1D4ED8) : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.view_list_rounded,
                size: 16,
                color: !isCardView ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    Color? activeColor,
  }) {
    final effectiveColor = activeColor ?? const Color(0xFF1E56E2);
    final bgColor = isSelected ? (activeColor != null ? activeColor.withValues(alpha: 0.12) : const Color(0xFFEFF6FF)) : Colors.white;
    final textColor = isSelected ? effectiveColor : const Color(0xFF64748B);
    final borderColor = isSelected ? effectiveColor : const Color(0xFFE2E8F0);

    return BouncingWidget(
      scaleFactor: 0.94,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

// ==========================================
// Add / Edit Inventory Product Bottom Sheet
// Matches Images 2, 3, 4, 5
// ==========================================

class _AddEditProductBottomSheet extends StatefulWidget {
  final ProductModel? existingProduct;
  const _AddEditProductBottomSheet({this.existingProduct});

  @override
  State<_AddEditProductBottomSheet> createState() => _AddEditProductBottomSheetState();
}

class _AddEditProductBottomSheetState extends State<_AddEditProductBottomSheet> {
  late TextEditingController _nameCtrl;
  late TextEditingController _variantCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _hsnCtrl;
  late TextEditingController _basePriceCtrl;
  late TextEditingController _wholesalePriceCtrl;
  late TextEditingController _retailPriceCtrl;
  late TextEditingController _customerPriceCtrl;
  late TextEditingController _stockCtrl;
  late TextEditingController _alertQtyCtrl;
  late TextEditingController _skuCtrl;

  // Custom Size & Unit controllers & variant list
  late TextEditingController _sizeValueCtrl;
  late TextEditingController _customUnitCtrl;
  String _selectedUnit = 'ml';
  List<ProductVariant> _variants = [];
  bool _showAddVariantForm = false;

  // Extra variant controllers (per-variant 3-tier pricing + stock)
  final TextEditingController _extraSizeCtrl = TextEditingController();
  String _extraUnit = 'ml';
  final TextEditingController _extraCustomUnitCtrl = TextEditingController();
  final TextEditingController _extraWsCtrl = TextEditingController();
  final TextEditingController _extraRetCtrl = TextEditingController();
  final TextEditingController _extraMrpCtrl = TextEditingController();
  final TextEditingController _extraStockCtrl = TextEditingController();

  // Picked product image (local file path OR base64 data URI from camera/gallery).
  String? _imageDataUri;

  late double _selectedGst;
  late TextEditingController _customGstCtrl;
  bool _isCustomGst = false;

  final List<String> _availableUnits = [
    'ml',
    'L',
    'g',
    'kg',
    'pcs',
    'pack',
    'box',
    'bag',
    'pouch',
    'bottle',
    'tin',
    'can',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.existingProduct;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _variantCtrl = TextEditingController(text: p?.variant ?? p?.size ?? '');
    _categoryCtrl = TextEditingController(text: p?.categoryId ?? '');
    _hsnCtrl = TextEditingController(text: p?.hsnSacCode ?? '');
    _basePriceCtrl = TextEditingController(text: p != null ? p.basePrice.toStringAsFixed(1) : '');
    _wholesalePriceCtrl = TextEditingController(text: p != null ? p.wholesalePrice.toStringAsFixed(1) : '');
    _retailPriceCtrl = TextEditingController(text: p != null ? p.retailPrice.toStringAsFixed(1) : '');
    _customerPriceCtrl = TextEditingController(text: p != null ? p.customerPrice.toStringAsFixed(1) : '');
    _stockCtrl = TextEditingController(text: p != null ? p.stockQuantity.toString() : '');
    _alertQtyCtrl = TextEditingController(text: p != null ? p.lowStockAlertQty.toString() : '10');
    _skuCtrl = TextEditingController(text: p?.sku ?? '');
    _imageDataUri = p?.imageUrl;
    _selectedGst = p?.gstRate ?? 18.0;
    final predefinedGsts = [0.0, 5.0, 12.0, 18.0, 28.0];
    _isCustomGst = !predefinedGsts.contains(_selectedGst);
    _customGstCtrl = TextEditingController(text: _isCustomGst ? _selectedGst.toStringAsFixed(1) : '');

    // Initialize custom size, unit, and variants
    if (p?.variants != null && p!.variants!.isNotEmpty) {
      _variants = List.from(p.variants!);
      final first = _variants.first;
      _sizeValueCtrl = TextEditingController(text: first.size);
      if (_availableUnits.contains(first.unit)) {
        _selectedUnit = first.unit;
        _customUnitCtrl = TextEditingController();
      } else {
        _selectedUnit = 'Custom';
        _customUnitCtrl = TextEditingController(text: first.unit);
      }
    } else if (p != null) {
      final rawVariant = p.variant ?? p.size ?? '';
      final match = RegExp(r'^(\d+(?:\.\d+)?)\s*(.*)$').firstMatch(rawVariant.trim());
      if (match != null) {
        _sizeValueCtrl = TextEditingController(text: match.group(1) ?? '');
        final unitPart = (match.group(2) ?? 'pcs').trim();
        final lower = unitPart.toLowerCase();
        if (_availableUnits.contains(lower)) {
          _selectedUnit = lower;
          _customUnitCtrl = TextEditingController();
        } else if (_availableUnits.contains(unitPart)) {
          _selectedUnit = unitPart;
          _customUnitCtrl = TextEditingController();
        } else if (unitPart.isNotEmpty) {
          _selectedUnit = 'Custom';
          _customUnitCtrl = TextEditingController(text: unitPart);
        } else {
          _selectedUnit = 'pcs';
          _customUnitCtrl = TextEditingController();
        }
      } else {
        _sizeValueCtrl = TextEditingController(text: rawVariant);
        _selectedUnit = 'pcs';
        _customUnitCtrl = TextEditingController();
      }
    } else {
      _sizeValueCtrl = TextEditingController();
      _selectedUnit = 'pcs';
      _customUnitCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _variantCtrl.dispose();
    _categoryCtrl.dispose();
    _hsnCtrl.dispose();
    _basePriceCtrl.dispose();
    _wholesalePriceCtrl.dispose();
    _retailPriceCtrl.dispose();
    _customerPriceCtrl.dispose();
    _stockCtrl.dispose();
    _alertQtyCtrl.dispose();
    _skuCtrl.dispose();
    _sizeValueCtrl.dispose();
    _customUnitCtrl.dispose();
    _customGstCtrl.dispose();
    _extraSizeCtrl.dispose();
    _extraCustomUnitCtrl.dispose();
    _extraWsCtrl.dispose();
    _extraRetCtrl.dispose();
    _extraMrpCtrl.dispose();
    _extraStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProductImage({required bool fromCamera}) async {
    final dataUri = await AppImageHelper.pickImageAsDataUri(
      fromCamera: fromCamera,
      onError: (err) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: const Color(0xFFDC2626)),
        );
      },
    );
    if (!mounted) return;
    if (dataUri != null && dataUri.isNotEmpty) {
      setState(() => _imageDataUri = dataUri);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF1E56E2)),
                title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProductImage(fromCamera: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF059669)),
                title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickProductImage(fromCamera: false);
                },
              ),
              if (_imageDataUri != null && _imageDataUri!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626)),
                  title: const Text('Remove Image',
                      style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() => _imageDataUri = null);
                  },
                ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  ImageProvider? _resolveImageProvider(String uri) {
    if (uri.startsWith('data:image')) {
      try {
        final base64Part = uri.split(',').last;
        return MemoryImage(base64Decode(base64Part));
      } catch (_) {
        return null;
      }
    }
    if (uri.startsWith('http://') || uri.startsWith('https://')) {
      return NetworkImage(uri);
    }
    try {
      final f = File(uri);
      if (f.existsSync()) return FileImage(f);
    } catch (_) {}
    return null;
  }

  void _showAddCustomProductCategoryDialog() {
    final catTextCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Custom Category', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: catTextCtrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Product Category Name',
            hintText: 'e.g. Frozen Foods, Ayurvedic, Electronics',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = catTextCtrl.text.trim();
              if (val.isNotEmpty) {
                context.read<AppState>().addProductCategory(val);
                setState(() => _categoryCtrl.text = val);
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFCC00),
              foregroundColor: const Color(0xFF0F172A),
            ),
            child: const Text('Add Category'),
          ),
        ],
      ),
    );
  }

  Widget _variantPricePill(String label, double? price, Color color) {
    final text = price != null ? '₹${price.toStringAsFixed(0)}' : '—';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        '$label $text',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color),
      ),
    );
  }

  Widget _priceField({
    required TextEditingController controller,
    required String label,
    required Color color,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800),
        prefixText: '₹ ',
        prefixStyle: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color, width: 1.4),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }

  void _updatePrimaryVariantString() {
    final size = _sizeValueCtrl.text.trim();
    final unit = _selectedUnit == 'Custom' ? _customUnitCtrl.text.trim() : _selectedUnit;
    final combined = unit.isNotEmpty ? '$size $unit'.trim() : size;
    _variantCtrl.text = combined.isNotEmpty ? combined : 'Standard';
  }

  @override
  Widget build(BuildContext context) {
    final basePrice = double.tryParse(_basePriceCtrl.text.trim()) ?? 0.0;
    final totalGst = basePrice * (_selectedGst / 100);
    final cgst = totalGst / 2;
    final sgst = totalGst / 2;
    final grandTotal = basePrice + totalGst;

    return Container(
      constraints: const BoxConstraints(maxWidth: 620),
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Modal Top Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.existingProduct == null ? 'Add Inventory Product' : 'Edit Product Details',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF0F172A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Scrollable Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image Section
                  const Text(
                    'Product Image',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _showImageSourceSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      height: _imageDataUri != null && _imageDataUri!.isNotEmpty ? 120 : 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: (_imageDataUri != null && _imageDataUri!.isNotEmpty)
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: () {
                                    final provider = _resolveImageProvider(_imageDataUri!);
                                    if (provider == null) {
                                      return const Center(
                                        child: Icon(Icons.broken_image_outlined, color: Color(0xFF94A3B8)),
                                      );
                                    }
                                    return Image(image: provider, fit: BoxFit.cover);
                                  }(),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.55),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.edit_rounded, color: Colors.white, size: 12),
                                        SizedBox(width: 4),
                                        Text('Change',
                                            style: TextStyle(
                                                color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined, color: Color(0xFF0F172A), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Upload Product Image',
                                  style: TextStyle(
                                    color: Color(0xFF0F172A),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product Name Field
                  TextField(
                    controller: _nameCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Product Name *',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Field with Custom Category Option
                  Builder(
                    builder: (bCtx) {
                      final appState = Provider.of<AppState>(bCtx);
                      final categories = List<String>.from(appState.productCategories);
                      final currentCat = _categoryCtrl.text.trim();
                      if (currentCat.isNotEmpty && !categories.contains(currentCat)) {
                        categories.add(currentCat);
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: categories.contains(currentCat) ? currentCat : (categories.isNotEmpty ? categories.first : null),
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                          const DropdownMenuItem(
                            value: '__ADD_CUSTOM_CAT__',
                            child: Row(
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 16, color: Color(0xFF1D4ED8)),
                                SizedBox(width: 6),
                                Text('+ Add Custom Category', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == '__ADD_CUSTOM_CAT__') {
                            _showAddCustomProductCategoryDialog();
                          } else if (val != null) {
                            setState(() => _categoryCtrl.text = val);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 14),

                  // ========================================================
                  // Product Variants & Packaging Section
                  // ========================================================
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Section Header
                        const Row(
                          children: [
                            Icon(Icons.layers_rounded, size: 16, color: Color(0xFF1D4ED8)),
                            SizedBox(width: 8),
                            Text(
                              'Variants & Packaging',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Size Value & Unit Dropdown Row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Size Value Input
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: _sizeValueCtrl,
                                onChanged: (_) {
                                  _updatePrimaryVariantString();
                                  setState(() {});
                                },
                                decoration: InputDecoration(
                                  labelText: 'Size / Value *',
                                  hintText: 'e.g. 500, 1, 250',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Unit Selector Dropdown
                            Expanded(
                              flex: 2,
                              child: Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _availableUnits.contains(_selectedUnit) ? _selectedUnit : 'Custom',
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF1E56E2)),
                                    items: _availableUnits.map((unit) {
                                      return DropdownMenuItem<String>(
                                        value: unit,
                                        child: Text(
                                          unit,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() {
                                          _selectedUnit = val;
                                          _updatePrimaryVariantString();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Inline Custom Unit Input (shown when 'Custom' is selected)
                        if (_selectedUnit == 'Custom') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _customUnitCtrl,
                            onChanged: (_) {
                              _updatePrimaryVariantString();
                              setState(() {});
                            },
                            decoration: InputDecoration(
                              labelText: 'Custom Unit *',
                              hintText: 'e.g. roll, crate, pouch',
                              labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF93C5FD)),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Live Variant Preview Badge
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFBFDBFE)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_outline_rounded, size: 14, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Variant: ${_variantCtrl.text.isNotEmpty ? _variantCtrl.text : "Standard"}',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // 3-tier pricing + stock for THIS (primary) variant.
                        const SizedBox(height: 12),
                        const Text(
                          'Pricing for this variant (₹)',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: _priceField(
                                controller: _wholesalePriceCtrl,
                                label: 'Wholesale',
                                color: const Color(0xFF1D4ED8),
                                onChanged: (v) {
                                  _basePriceCtrl.text = v;
                                  setState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _priceField(
                                controller: _retailPriceCtrl,
                                label: 'Retail',
                                color: const Color(0xFF047857),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _priceField(
                                controller: _customerPriceCtrl,
                                label: 'MRP',
                                color: const Color(0xFFB45309),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _stockCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Stock Qty *',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _alertQtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Low-stock Alert',
                                  labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // List of Additional Variants (Multi-Variant Support)
                        if (_variants.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Additional variants',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          ..._variants.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final v = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          v.displayName,
                                          style: const TextStyle(
                                              fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text('Stock: ${v.stockQuantity ?? 0}',
                                          style: const TextStyle(
                                              fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => setState(() => _variants.removeAt(idx)),
                                        child: const Icon(Icons.delete_outline_rounded,
                                            size: 16, color: Color(0xFFDC2626)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _variantPricePill('WS',
                                          v.wholesalePrice, const Color(0xFF1D4ED8)),
                                      const SizedBox(width: 6),
                                      _variantPricePill('Retail',
                                          v.retailPrice, const Color(0xFF047857)),
                                      const SizedBox(width: 6),
                                      _variantPricePill('MRP',
                                          v.customerPrice, const Color(0xFFB45309)),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],

                        // Add Additional Variant Subform
                        if (_showAddVariantForm) ...[
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFF93C5FD)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Add Another Size / Variant',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: _extraSizeCtrl,
                                        decoration: InputDecoration(
                                          labelText: 'Size (e.g. 1, 250)',
                                          labelStyle: const TextStyle(fontSize: 11),
                                          filled: true,
                                          fillColor: const Color(0xFFF8FAFC),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        height: 42,
                                        padding: const EdgeInsets.symmetric(horizontal: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFFCBD5E1)),
                                        ),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: _availableUnits.contains(_extraUnit) ? _extraUnit : 'Custom',
                                            isExpanded: true,
                                            items: _availableUnits.map((u) {
                                              return DropdownMenuItem<String>(
                                                value: u,
                                                child: Text(u, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              if (val != null) setState(() => _extraUnit = val);
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (_extraUnit == 'Custom') ...[
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: _extraCustomUnitCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'Custom Unit',
                                      labelStyle: const TextStyle(fontSize: 11),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                // 3-tier pricing for THIS additional variant
                                Row(
                                  children: [
                                    Expanded(
                                      child: _priceField(
                                        controller: _extraWsCtrl,
                                        label: 'Wholesale',
                                        color: const Color(0xFF1D4ED8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _priceField(
                                        controller: _extraRetCtrl,
                                        label: 'Retail',
                                        color: const Color(0xFF047857),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: _priceField(
                                        controller: _extraMrpCtrl,
                                        label: 'MRP',
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _extraStockCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText: 'Stock Qty',
                                    labelStyle: const TextStyle(fontSize: 11),
                                    filled: true,
                                    fillColor: const Color(0xFFF8FAFC),
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton(
                                      onPressed: () => setState(() => _showAddVariantForm = false),
                                      child: const Text('Cancel', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ),
                                    const SizedBox(width: 6),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E56E2),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      onPressed: () {
                                        final s = _extraSizeCtrl.text.trim();
                                        final u = _extraUnit == 'Custom' ? _extraCustomUnitCtrl.text.trim() : _extraUnit;
                                        if (s.isEmpty) return;
                                        final ws = double.tryParse(_extraWsCtrl.text.trim()) ??
                                            (double.tryParse(_wholesalePriceCtrl.text.trim()) ?? 0.0);
                                        final ret = double.tryParse(_extraRetCtrl.text.trim()) ??
                                            (double.tryParse(_retailPriceCtrl.text.trim()) ?? ws);
                                        final mrp = double.tryParse(_extraMrpCtrl.text.trim()) ??
                                            (double.tryParse(_customerPriceCtrl.text.trim()) ?? ret);
                                        final st = int.tryParse(_extraStockCtrl.text.trim()) ??
                                            (int.tryParse(_stockCtrl.text.trim()) ?? 0);

                                        setState(() {
                                          _variants.add(ProductVariant(
                                            size: s,
                                            unit: u.isNotEmpty ? u : 'Standard',
                                            wholesalePrice: ws,
                                            retailPrice: ret,
                                            customerPrice: mrp,
                                            stockQuantity: st,
                                          ));
                                          _extraSizeCtrl.clear();
                                          _extraCustomUnitCtrl.clear();
                                          _extraWsCtrl.clear();
                                          _extraRetCtrl.clear();
                                          _extraMrpCtrl.clear();
                                          _extraStockCtrl.clear();
                                          _showAddVariantForm = false;
                                        });
                                      },
                                      child: const Text('Add Variant', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              _extraWsCtrl.text = _wholesalePriceCtrl.text;
                              _extraRetCtrl.text = _retailPriceCtrl.text;
                              _extraMrpCtrl.text = _customerPriceCtrl.text;
                              _extraStockCtrl.text = _stockCtrl.text;
                              setState(() => _showAddVariantForm = true);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF93C5FD), style: BorderStyle.solid),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_circle_outline_rounded, size: 14, color: Color(0xFF1E56E2)),
                                  SizedBox(width: 4),
                                  Text(
                                    '+ Add Another Variant / Size',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E56E2),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Product-Wise GST Slab Option Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Product-Wise GST Slab Option',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: Color(0xFF1E3A8A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1D4ED8),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_selectedGst.toStringAsFixed(_selectedGst % 1 == 0 ? 0 : 1)}% Tax Slab',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Radio options list (Clean - without descriptive text/notes)
                        Builder(
                          builder: (bCtx) {
                            final appState = Provider.of<AppState>(bCtx);
                            final activeSlabs = appState.activeGstSlabs;

                            return Column(
                              children: [
                                ...activeSlabs.map((s) {
                                  final rate = s.rate;
                                  final isSel = !_isCustomGst && _selectedGst == rate;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        _isCustomGst = false;
                                        _selectedGst = rate;
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 6),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: isSel ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                                                width: 2,
                                              ),
                                            ),
                                            alignment: Alignment.center,
                                            child: isSel
                                                ? Container(
                                                    width: 10,
                                                    height: 10,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFF1D4ED8),
                                                      shape: BoxShape.circle,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              '${s.formattedRate} • ${s.name}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                                color: isSel ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),

                                // Custom GST Rate Option
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      _isCustomGst = true;
                                      final parsed = double.tryParse(_customGstCtrl.text.trim()) ?? 0.0;
                                      _selectedGst = parsed;
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _isCustomGst ? const Color(0xFF1D4ED8) : const Color(0xFF94A3B8),
                                              width: 2,
                                            ),
                                          ),
                                          alignment: Alignment.center,
                                          child: _isCustomGst
                                              ? Container(
                                                  width: 10,
                                                  height: 10,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF1D4ED8),
                                                    shape: BoxShape.circle,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Custom GST Rate %',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const Spacer(),
                                        SizedBox(
                                          width: 95,
                                          height: 38,
                                          child: TextField(
                                            controller: _customGstCtrl,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: InputDecoration(
                                              hintText: 'e.g. 7.5',
                                              suffixText: '%',
                                              filled: true,
                                              fillColor: Colors.white,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5),
                                              ),
                                            ),
                                            onChanged: (val) {
                                              final parsed = double.tryParse(val.trim()) ?? 0.0;
                                              setState(() {
                                                _isCustomGst = true;
                                                _selectedGst = parsed;
                                              });
                                            },
                                            onTap: () {
                                              setState(() {
                                                _isCustomGst = true;
                                                final parsed = double.tryParse(_customGstCtrl.text.trim()) ?? 0.0;
                                                _selectedGst = parsed;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            );
                        },
                      ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // HSN / SAC Code
                  TextField(
                    controller: _hsnCtrl,
                    decoration: InputDecoration(
                      labelText: 'HSN / SAC Code',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SKU / Barcode Field
                  TextField(
                    controller: _skuCtrl,
                    decoration: InputDecoration(
                      labelText: 'SKU / Barcode',
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // GST Calculation Preview (Per Unit) Card (Image 3)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x05000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'GST Calculation Preview (Per Unit)',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Taxable Base Price:',
                              style: TextStyle(fontSize: 13, color: Color(0xFF334155)),
                            ),
                            Text(
                              '₹${basePrice.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'CGST (${(_selectedGst / 2).toStringAsFixed(1)}%):',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                            ),
                            Text(
                              '₹${cgst.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'SGST (${(_selectedGst / 2).toStringAsFixed(1)}%):',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF334155)),
                            ),
                            Text(
                              '₹${sgst.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Price Incl. GST:',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E3A8A),
                              ),
                            ),
                            Text(
                              '₹${grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Modal Bottom Actions: Cancel & Save Product & GST
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (widget.existingProduct != null) ...[
                  OutlinedButton(
                    onPressed: () => _confirmDeleteProduct(context, widget.existingProduct!),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _nameCtrl.text.trim().isNotEmpty ? const Color(0xFFFFCC00) : const Color(0xFFF1F5F9),
                      foregroundColor: _nameCtrl.text.trim().isNotEmpty ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    onPressed: _nameCtrl.text.trim().isEmpty
                        ? null
                        : () {
                            final name = _nameCtrl.text.trim();
                            final variant = _variantCtrl.text.trim();
                            final cat = _categoryCtrl.text.trim().isNotEmpty ? _categoryCtrl.text.trim() : 'Home Cleaning';
                            final hsn = _hsnCtrl.text.trim();
                            final wsPrice = double.tryParse(_wholesalePriceCtrl.text.trim()) ?? (double.tryParse(_basePriceCtrl.text.trim()) ?? 0.0);
                            final retPrice = double.tryParse(_retailPriceCtrl.text.trim()) ?? wsPrice;
                            final custPrice = double.tryParse(_customerPriceCtrl.text.trim()) ?? retPrice;
                            final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
                            final alertQty = int.tryParse(_alertQtyCtrl.text.trim()) ?? 10;
                            final sku = _skuCtrl.text.trim();

                            final primaryUnit = _selectedUnit == 'Custom' ? _customUnitCtrl.text.trim() : _selectedUnit;
                            final primarySize = _sizeValueCtrl.text.trim().isNotEmpty ? _sizeValueCtrl.text.trim() : variant;

                            final primaryVariant = ProductVariant(
                              size: primarySize,
                              unit: primaryUnit.isNotEmpty ? primaryUnit : 'Standard',
                              wholesalePrice: wsPrice,
                              retailPrice: retPrice,
                              customerPrice: custPrice,
                              stockQuantity: stock,
                              sku: sku,
                            );

                            final List<ProductVariant> allVariants = [
                              primaryVariant,
                              ..._variants.where((v) => !(v.size == primaryVariant.size && v.unit == primaryVariant.unit)),
                            ];

                            final newProd = ProductModel(
                              productId: widget.existingProduct?.productId ?? 'prod_${DateTime.now().millisecondsSinceEpoch}',
                              name: name,
                              variant: variant,
                              size: variant,
                              variants: allVariants,
                              categoryId: cat,
                              sku: sku,
                              hsnSacCode: hsn,
                              basePrice: wsPrice,
                              wholesalePrice: wsPrice,
                              retailPrice: retPrice,
                              customerPrice: custPrice,
                              gstRate: _selectedGst,
                              stockQuantity: stock,
                              lowStockAlertQty: alertQty,
                              imageUrl: _imageDataUri,
                              isActive: true,
                            );

                            if (_isCustomGst && _selectedGst > 0) {
                              context.read<AppState>().addGstRate(_selectedGst);
                            }

                            if (widget.existingProduct == null) {
                              context.read<AppState>().addProduct(newProd);
                            } else {
                              context.read<AppState>().updateProduct(newProd);
                            }

                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Product "$name" saved successfully!'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          },
                    child: const Text(
                      'Save Product & GST',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Product?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text('Are you sure you want to permanently delete "${product.name}" from inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<AppState>().deleteProduct(product.productId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Product "${product.name}" deleted.'),
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
