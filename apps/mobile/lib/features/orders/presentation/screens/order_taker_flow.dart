import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/theme/app_theme.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/product_image_helper.dart';
import 'package:salesarmy/core/utils/responsive_helper.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';
import 'package:salesarmy/features/billing/presentation/screens/estimated_bill_screen.dart';
import 'package:salesarmy/features/orders/presentation/dialogs/complete_and_bill_order_modal.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';

class OrderTakerFlow extends StatefulWidget {
  final ShopModel? initialShop;
  final Map<String, int>? initialCart;
  final VoidCallback onOrderCompleted;

  final bool isEmbedded;

  const OrderTakerFlow({
    super.key,
    this.initialShop,
    this.initialCart,
    required this.onOrderCompleted,
    this.isEmbedded = false,
  });

  @override
  State<OrderTakerFlow> createState() => _OrderTakerFlowState();
}

class _OrderTakerFlowState extends State<OrderTakerFlow> {
  ShopModel? _selectedShop;
  final Map<String, int> _cartQuantities = {};
  final TextEditingController _notesCtrl = TextEditingController();

  String _searchQuery = '';
  String _selectedCategory = 'All';
  final String _selectedPricingCategory = 'Wholesale Price'; // 'Retail Price', 'Wholesale Price', 'MRP'
  final String _billingGstMode = 'GST'; // 'GST' or 'NON_GST'
  final String _selectedGstSlabId = 'auto'; // 'auto', 'gst_0', 'gst_5', 'gst_12', 'gst_18', 'gst_28'

  double _getProductPrice(ProductModel product, String category) {
    switch (category) {
      case 'Retail Price':
        return product.retailPrice > 0 ? product.retailPrice : product.basePrice;
      case 'Wholesale Price':
        return product.wholesalePrice > 0 ? product.wholesalePrice : product.basePrice;
      case 'MRP':
        return product.customerPrice > 0
            ? product.customerPrice
            : (product.retailPrice > 0 ? product.retailPrice : product.basePrice);
      default:
        return product.basePrice;
    }
  }

  double? _getSlabRate(String slabId) {
    switch (slabId) {
      case 'gst_0':
        return 0.0;
      case 'gst_5':
        return 5.0;
      case 'gst_12':
        return 12.0;
      case 'gst_18':
        return 18.0;
      case 'gst_28':
        return 28.0;
      default:
        return null;
    }
  }

  final List<Map<String, String>> _categories = [
    {'name': 'All', 'icon': '🏷️'},
    {'name': 'Groceries', 'icon': '🌾'},
    {'name': 'Edible Oils', 'icon': '🌻'},
    {'name': 'Dairy', 'icon': '🥛'},
    {'name': 'Bakery', 'icon': '🍪'},
    {'name': 'Snacks', 'icon': '🥨'},
    {'name': 'Home Cleaning', 'icon': '🧴'},
  ];

  bool _matchesCategory(ProductModel p, String selected) {
    if (selected == 'All') return true;
    final cat = (p.categoryId ?? '').toLowerCase();
    final name = p.name.toLowerCase();

    switch (selected) {
      case 'Home Cleaning':
        return cat.contains('clean') || cat.contains('home') || name.contains('cleaner') || name.contains('harpic') || name.contains('lizol') || name.contains('vim');
      case 'Groceries':
        return cat.contains('grocer') || cat.contains('atta') || cat.contains('staple') || name.contains('atta') || name.contains('tea') || name.contains('salt') || name.contains('rice') || name.contains('sugar');
      case 'Edible Oils':
        return cat.contains('oil') || name.contains('oil') || name.contains('sunlite') || name.contains('saffola');
      case 'Dairy':
        return cat.contains('dairy') || cat.contains('milk') || name.contains('milk') || name.contains('butter');
      case 'Bakery':
        return cat.contains('bakery') || cat.contains('biscuit') || name.contains('biscuit') || name.contains('parle') || name.contains('good day') || name.contains('oreo');
      case 'Snacks':
        return cat.contains('snack') || cat.contains('namkeen') || name.contains('bhujia') || name.contains('silk');
      default:
        return cat == selected.toLowerCase();
    }
  }

  Widget _buildProductThumbnail(ProductModel product, {double size = 52}) {
    return ProductImageView(
      imageUrl: product.imageUrl,
      productName: product.name,
      categoryId: product.categoryId,
      width: size,
      height: size,
      borderRadius: BorderRadius.circular(14),
      fit: BoxFit.contain,
    );
  }

  @override
  void initState() {
    super.initState();
    _selectedShop = widget.initialShop;
    if (widget.initialCart != null) {
      _cartQuantities.addAll(widget.initialCart!);
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _bookOrderOnly(AppState appState, ShopModel targetShop) async {
    HapticFeedback.mediumImpact();
    final now = DateTime.now();
    final items = <TransactionItemSnapshot>[];
    double subtotal = 0.0;
    double totalGst = 0.0;

    final sellerGstin = appState.tenant.gstin ?? '27ABCDE1234F1Z5';
    final buyerGstin = targetShop.gstin?.trim() ?? '';

    _cartQuantities.forEach((prodId, qty) {
      if (qty <= 0) return;
      if (appState.products.isEmpty) return;
      final product = appState.products.firstWhere(
        (p) => p.productId == prodId,
        orElse: () => appState.products.first,
      );
      final productPrice = _getProductPrice(product, _selectedPricingCategory);
      final taxable = productPrice * qty;
      final effectiveGstRate = _billingGstMode == 'NON_GST'
          ? 0.0
          : (_selectedGstSlabId == 'auto' ? product.gstRate : (_getSlabRate(_selectedGstSlabId) ?? product.gstRate));

      final breakdown = appState.calculateGstBreakdown(
        taxableAmount: taxable,
        gstRate: effectiveGstRate,
        sellerGstin: sellerGstin,
        buyerGstin: buyerGstin,
        forceNonGst: _billingGstMode == 'NON_GST' || !appState.isGstBillingEnabled,
      );

      final gst = breakdown.totalGst;
      subtotal += taxable;
      totalGst += gst;
      items.add(
        TransactionItemSnapshot(
          productId: product.productId,
          productName: product.name,
          sku: product.sku ?? 'SKU',
          hsnSacCode: product.hsnSacCode ?? '1101',
          quantity: qty,
          rate: productPrice,
          taxableAmount: taxable,
          gstRate: breakdown.gstType == 'NON_GST' ? 0.0 : effectiveGstRate,
          cgst: breakdown.cgst,
          sgst: breakdown.sgst,
          igst: breakdown.igst,
          totalGst: breakdown.totalGst,
          total: taxable + gst,
        ),
      );
    });

    if (items.isEmpty) return;

    final orderId = 'ORD-2026-${(appState.orders.length + 1).toString().padLeft(3, '0')}';
    final note = _notesCtrl.text.trim().isNotEmpty
        ? _notesCtrl.text.trim()
        : 'Booked via Billing Desk (${_billingGstMode == "GST" ? "GST Tax Invoice" : "Rough Estimate"})';

    final order = OrderModel(
      orderId: orderId,
      shopId: targetShop.shopId,
      createdByUid: appState.currentUid ?? 'sales_rep',
      status: 'pending',
      items: items,
      subtotal: subtotal,
      totalGst: totalGst,
      grandTotal: subtotal + totalGst,
      deliveryNote: note,
      placedAt: now,
      createdAt: now,
      updatedAt: now,
    );

    // Submit with stock guard. If any item overshoots live inventory,
    // AppState throws InsufficientStockException and we show a short-items
    // list rather than silently clamping stock to zero.
    try {
      await appState.addOrder(order);
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough stock:\n${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order $orderId booked for ${targetShop.shopName}!'),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _cartQuantities.clear();
      _notesCtrl.clear();
    });

    widget.onOrderCompleted();
  }



  void _showVariantAndQuantityModal(ProductModel product, int currentQty) {
    // Generate or fetch variants for this product
    List<ProductVariant> variants = [];
    if (product.variants != null && product.variants!.isNotEmpty) {
      variants = List.from(product.variants!);
    } else {
      final nameLower = product.name.toLowerCase();
      if (nameLower.contains('atta') || nameLower.contains('chakki') || nameLower.contains('flour')) {
        variants = [
          const ProductVariant(size: '1 Kg Pouch', unit: 'kg', wholesalePrice: 52.0, retailPrice: 58.0, stockQuantity: 50),
          const ProductVariant(size: '5 Kg Bag', unit: 'kg', wholesalePrice: 240.0, retailPrice: 260.0, stockQuantity: 25),
          const ProductVariant(size: '10 Kg Bag', unit: 'kg', wholesalePrice: 460.0, retailPrice: 500.0, stockQuantity: 15),
        ];
      } else if (nameLower.contains('oil') || nameLower.contains('sunlite') || nameLower.contains('saffola')) {
        variants = [
          const ProductVariant(size: '500 ml Pouch', unit: 'ml', wholesalePrice: 78.0, retailPrice: 85.0, stockQuantity: 30),
          const ProductVariant(size: '1 Litre Pouch', unit: 'L', wholesalePrice: 145.0, retailPrice: 158.0, stockQuantity: 50),
          const ProductVariant(size: '5 Litre Jar', unit: 'L', wholesalePrice: 710.0, retailPrice: 775.0, stockQuantity: 20),
          const ProductVariant(size: '15 Litre Tin', unit: 'L', wholesalePrice: 2100.0, retailPrice: 2280.0, stockQuantity: 10),
        ];
      } else if (nameLower.contains('cleaner') || nameLower.contains('harpic') || nameLower.contains('spray') || nameLower.contains('lizol')) {
        variants = [
          const ProductVariant(size: '250 ml Bottle', unit: 'ml', wholesalePrice: 55.0, retailPrice: 62.0, stockQuantity: 25),
          const ProductVariant(size: '500 ml Bottle', unit: 'ml', wholesalePrice: 110.0, retailPrice: 125.0, stockQuantity: 30),
          const ProductVariant(size: '1 Litre Economy', unit: 'L', wholesalePrice: 195.0, retailPrice: 220.0, stockQuantity: 15),
        ];
      } else if (nameLower.contains('biscuit') || nameLower.contains('parle') || nameLower.contains('cookie')) {
        variants = [
          const ProductVariant(size: '100g Pocket Pack', unit: 'g', wholesalePrice: 10.0, retailPrice: 12.0, stockQuantity: 100),
          const ProductVariant(size: '250g Regular Pack', unit: 'g', wholesalePrice: 25.0, retailPrice: 30.0, stockQuantity: 60),
          const ProductVariant(size: '1kg Family Pack', unit: 'kg', wholesalePrice: 120.0, retailPrice: 130.0, stockQuantity: 25),
        ];
      } else {
        variants = [
          ProductVariant(size: product.variant ?? product.size ?? 'Standard (1 Unit)', unit: 'pcs', wholesalePrice: product.wholesalePrice, retailPrice: product.retailPrice, stockQuantity: product.stockQuantity),
          ProductVariant(size: 'Pack of 2 (${product.variant ?? 'Units'})', unit: 'pcs', wholesalePrice: (product.wholesalePrice * 1.95).roundToDouble(), retailPrice: (product.retailPrice * 1.95).roundToDouble(), stockQuantity: 20),
          ProductVariant(size: 'Carton / Bulk Case (10 Units)', unit: 'case', wholesalePrice: (product.wholesalePrice * 9.2).roundToDouble(), retailPrice: (product.retailPrice * 9.5).roundToDouble(), stockQuantity: 10),
        ];
      }
    }

    int selectedVariantIndex = 0;
    for (int i = 0; i < variants.length; i++) {
      if (variants[i].size == product.variant) {
        selectedVariantIndex = i;
        break;
      }
    }

    final qtyCtrl = TextEditingController(text: currentQty > 0 ? '$currentQty' : '1');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = ctx.watch<AppState>().isDarkMode;
        return StatefulBuilder(
          builder: (context, setModalState) {
            final selectedVariant = variants[selectedVariantIndex];
            final currentNumQty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
            final double subtotal = (selectedVariant.wholesalePrice ?? 0.0) * currentNumQty;

            return Container(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          _buildProductThumbnail(product, size: 48),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Choose variant size & order quantity',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                      Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

                      // Variant Selector Label
                      Text(
                        'SELECT SIZE / VARIANT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Variants Cards List
                      ...List.generate(variants.length, (idx) {
                        final v = variants[idx];
                        final isSel = selectedVariantIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setModalState(() => selectedVariantIndex = idx);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                                    : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSel
                                      ? const Color(0xFF3B82F6)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: isSel ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSel ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                                    color: isSel
                                        ? const Color(0xFF3B82F6)
                                        : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          v.size,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w700,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'WS: ${AppFormatters.currency(v.wholesalePrice)} • Ret: ₹${(v.retailPrice ?? 0.0).toStringAsFixed(0)}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isSel
                                          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFDCFCE7))
                                          : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Stock: ${v.stockQuantity}',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: isSel
                                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF15803D))
                                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 16),

                      // Quantity Stepper
                      Text(
                        'SELECT QUANTITY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.remove_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
                              onPressed: () {
                                final cur = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                                if (cur > 1) {
                                  HapticFeedback.lightImpact();
                                  setModalState(() => qtyCtrl.text = '${cur - 1}');
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E56E2),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                              onPressed: () {
                                final cur = int.tryParse(qtyCtrl.text.trim()) ?? 1;
                                HapticFeedback.lightImpact();
                                setModalState(() => qtyCtrl.text = '${cur + 1}');
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Quick Qty Pills (+5, +10, +25, +50)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [5, 10, 25, 50].map((inc) {
                          return InkWell(
                            onTap: () {
                              final cur = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                              HapticFeedback.selectionClick();
                              setModalState(() => qtyCtrl.text = '${cur + inc}');
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE),
                                ),
                              ),
                              child: Text(
                                '+$inc',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Dynamic Subtotal & Confirm Button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Item Subtotal:',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                            Text(
                              AppFormatters.currency(subtotal),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      Row(
                        children: [
                          if (currentQty > 0) ...[
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  setState(() => _cartQuantities.remove(product.productId));
                                  Navigator.pop(ctx);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFEF4444),
                                  side: BorderSide(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECDD3)),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                final newQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                                final available = product.stockQuantity;
                                if (newQty > available) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Only $available ${product.name} in stock. Cannot add $newQty.'),
                                      backgroundColor: const Color(0xFFDC2626),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }
                                setState(() {
                                  if (newQty > 0) {
                                    _cartQuantities[product.productId] = newQty;
                                  } else {
                                    _cartQuantities.remove(product.productId);
                                  }
                                });
                                Navigator.pop(ctx);
                              },
                              icon: const Icon(Icons.check_rounded, size: 18, color: Colors.white),
                              label: const Text('Confirm & Add to Order', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQuickQuantityDialog(ProductModel product, int currentQty) {
    _showVariantAndQuantityModal(product, currentQty);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final products = appState.products;
    final shops = appState.shops;

    final targetShop = _selectedShop ??
        (shops.isNotEmpty
            ? shops.first
            : ShopModel(shopId: 'shop_default', shopName: 'Retail Counter Customer', ownerName: 'Walk-in Retailer'));

    final allAvailableShops = List<ShopModel>.from(shops);
    if (!allAvailableShops.any((s) => s.shopId == targetShop.shopId)) {
      allAvailableShops.insert(0, targetShop);
    }

    double subtotal = 0.0;
    double liveTotalTax = 0.0;
    double liveCgst = 0.0;
    double liveSgst = 0.0;
    double liveIgst = 0.0;
    int totalCartItems = 0;

    final sellerGstin = appState.tenant.gstin ?? '27ABCDE1234F1Z5';
    final buyerGstin = targetShop.gstin?.trim() ?? '';
    final sellerStateCode = AppState.getStateCodeFromGstin(sellerGstin);
    final buyerStateCode = AppState.getStateCodeFromGstin(buyerGstin);
    final isIntraState = sellerStateCode == buyerStateCode;

    _cartQuantities.forEach((prodId, qty) {
      if (qty <= 0) return;
      final matches = products.where((p) => p.productId == prodId);
      if (matches.isEmpty) return;
      final product = matches.first;
      totalCartItems += qty;
      final taxable = _getProductPrice(product, _selectedPricingCategory) * qty;
      subtotal += taxable;

      final effectiveGstRate = _billingGstMode == 'NON_GST'
          ? 0.0
          : (_selectedGstSlabId == 'auto' ? product.gstRate : (_getSlabRate(_selectedGstSlabId) ?? product.gstRate));

      final breakdown = appState.calculateGstBreakdown(
        taxableAmount: taxable,
        gstRate: effectiveGstRate,
        sellerGstin: sellerGstin,
        buyerGstin: buyerGstin,
        forceNonGst: _billingGstMode == 'NON_GST' || !appState.isGstBillingEnabled,
      );

      liveCgst += breakdown.cgst;
      liveSgst += breakdown.sgst;
      liveIgst += breakdown.igst;
      liveTotalTax += breakdown.totalGst;
    });

    final liveGrandTotal = subtotal + liveTotalTax;

    final filteredProducts = products.where((p) {
      final matchesQuery = _searchQuery.isEmpty ||
          p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.sku ?? '').toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (p.hsnSacCode ?? '').toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _matchesCategory(p, _selectedCategory);
      return matchesQuery && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Orders & Billing',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: 'Estimate',
                  icon: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.receipt_long_rounded, size: 15, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                        const SizedBox(width: 4),
                        Text(
                          'Rough Quote',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EstimatedBillScreen(initialShop: targetShop),
                      ),
                    );
                  },
                ),
                if (totalCartItems > 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE)),
                        ),
                        child: Text(
                          '$totalCartItems in Cart',
                          style: TextStyle(
                            color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: () async {
          HapticFeedback.lightImpact();
          await Future.delayed(const Duration(milliseconds: 500));
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 110),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [




            // 1. Select Retail Outlet (Party) Dropdown Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Target Retail Outlet',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey(targetShop.shopId),
                    initialValue: allAvailableShops.any((s) => s.shopId == targetShop.shopId)
                        ? targetShop.shopId
                        : (allAvailableShops.isNotEmpty ? allAvailableShops.first.shopId : null),
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    icon: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    items: allAvailableShops.map((s) {
                      final title = s.shopName.isNotEmpty ? s.shopName : 'Unnamed Shop';
                      final subtitle = s.ownerName.isNotEmpty ? ' (${s.ownerName})' : '';
                      return DropdownMenuItem<String>(
                        value: s.shopId,
                        child: Text(
                          '$title$subtitle',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (newShopId) {
                      if (newShopId != null) {
                        HapticFeedback.selectionClick();
                        final match = allAvailableShops.firstWhere(
                          (s) => s.shopId == newShopId,
                          orElse: () => targetShop,
                        );
                        setState(() => _selectedShop = match);
                      }
                    },
                  ),
                  if (targetShop.ownerName.isNotEmpty || (targetShop.phone != null && targetShop.phone!.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (targetShop.ownerName.isNotEmpty)
                          Text(
                            targetShop.ownerName,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (targetShop.phone != null && targetShop.phone!.isNotEmpty) ...[
                          Text(
                            ' • ',
                            style: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          ),
                          Text(
                            targetShop.phone!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

              // 2. Catalog & Search Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Product Catalog (${filteredProducts.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
                if (totalCartItems > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF059669).withValues(alpha: 0.5) : const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      'Subtotal: ${AppFormatters.currency(subtotal)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Elevated Search Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                onChanged: (val) => setState(() => _searchQuery = val),
                style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search items by name, SKU or HSN...',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13.5),
                  prefixIcon: Icon(Icons.search_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 18),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Category Chips Row with Emojis
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _categories.map((catMap) {
                  final cat = catMap['name']!;
                  final icon = catMap['icon']!;
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _selectedCategory = cat);
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7.5),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF1E293B) : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF0F172A))
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: (isDark ? const Color(0xFF2563EB) : const Color(0xFF0F172A)).withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(icon, style: const TextStyle(fontSize: 13)),
                            const SizedBox(width: 6),
                            Text(
                              cat,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Products List or Empty Search State
            if (filteredProducts.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    const SizedBox(height: 12),
                    Text(
                      'No products found',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try searching for another keyword or change category',
                      style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => setState(() {
                        _searchQuery = '';
                        _selectedCategory = 'All';
                      }),
                      child: const Text('Reset Search & Filters'),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredProducts.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final product = filteredProducts[index];
                  final qty = _cartQuantities[product.productId] ?? 0;
                  // Live stock cap — the + button, 6/12/24 pills and quick
                  // qty dialog all respect this ceiling so a cart can never
                  // overshoot inventory. Zero stock means the item is
                  // out-of-stock and must stay out of the cart.
                  final maxQty = product.stockQuantity;
                  final atStockCap = qty >= maxQty;

                  return Container(
                    decoration: BoxDecoration(
                      color: qty > 0
                          ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.25) : const Color(0xFFF8FAFF))
                          : (isDark ? const Color(0xFF1E293B) : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: qty > 0 ? const Color(0xFF3B82F6) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        width: qty > 0 ? 1.5 : 1.0,
                      ),
                      boxShadow: isDark ? null : AppTheme.softShadow(blur: 14, dy: 4),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showVariantAndQuantityModal(product, qty);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                        // Product visual thumbnail with authentic imagery
                        _buildProductThumbnail(product),
                        const SizedBox(width: 12),

                        // Product details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Line 1: Name
                              Text(
                                product.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.2,
                                  height: 1.22,
                                ),
                              ),
                              const SizedBox(height: 3),

                              // Line 2: Pricing & Ret / Margin
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    AppFormatters.currency(product.wholesalePrice),
                                    style: TextStyle(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Flexible(
                                    child: Text(
                                      '(Ret: ₹${product.retailPrice.toStringAsFixed(0)})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                  if (product.retailPrice > product.wholesalePrice) ...[
                                    const SizedBox(width: 5),
                                    Text(
                                      '${(((product.retailPrice - product.wholesalePrice) / product.retailPrice) * 100).round()}% Margin',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 5),

                              // Line 3: Spec Badges (GST Pill + Variant/Packaging + Stock)
                              Wrap(
                                spacing: 5,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (appState.isGstBillingEnabled)
                                    _buildGstBadge(
                                      _billingGstMode == 'NON_GST'
                                          ? 0.0
                                          : (_selectedGstSlabId == 'auto' ? product.gstRate : (_getSlabRate(_selectedGstSlabId) ?? product.gstRate)),
                                      isDark: isDark,
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(5),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), width: 0.8),
                                    ),
                                    constraints: const BoxConstraints(maxWidth: 130),
                                    child: Text(
                                      product.variant ?? product.size ?? 'Std',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: product.stockQuantity > 20
                                          ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.35) : const Color(0xFFDCFCE7))
                                          : (product.stockQuantity > 0
                                              ? (isDark ? const Color(0xFF78350F).withValues(alpha: 0.35) : const Color(0xFFFEF3C7))
                                              : (isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.35) : const Color(0xFFFEE2E2))),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: Text(
                                      product.stockQuantity > 20
                                          ? 'Stock: ${product.stockQuantity}'
                                          : (product.stockQuantity > 0 ? 'Low: ${product.stockQuantity}' : 'Out of stock'),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: product.stockQuantity > 20
                                            ? const Color(0xFF15803D)
                                            : (product.stockQuantity > 0 ? const Color(0xFFB45309) : const Color(0xFFDC2626)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (qty > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [6, 12, 24].map((multiplier) {
                                    final wouldOvershoot = (qty + multiplier) > maxQty;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: InkWell(
                                        onTap: wouldOvershoot
                                            ? () {
                                                HapticFeedback.vibrate();
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Only $maxQty ${product.name} in stock.'),
                                                    backgroundColor: const Color(0xFFDC2626),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            : () {
                                                HapticFeedback.selectionClick();
                                                setState(() => _cartQuantities[product.productId] = qty + multiplier);
                                              },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.4) : const Color(0xFFBFDBFE),
                                              width: 0.8,
                                            ),
                                          ),
                                          child: Text(
                                            '+$multiplier pcs',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Tactile Stepper (Compact & responsive with Royal Blue Accent)
                        if (qty == 0)
                          InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              _showVariantAndQuantityModal(product, 0);
                            },
                            customBorder: const CircleBorder(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.5) : const Color(0xFFBFDBFE),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isDark ? Colors.black : const Color(0xFF1E56E2)).withValues(alpha: 0.12),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(Icons.add_rounded, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2), size: 24),
                            ),
                          )
                        else
                          Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: const Color(0xFF3B82F6), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? Colors.black : const Color(0xFF1E56E2)).withValues(alpha: 0.12),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setState(() {
                                      if (qty > 1) {
                                        _cartQuantities[product.productId] = qty - 1;
                                      } else {
                                        _cartQuantities.remove(product.productId);
                                      }
                                    });
                                  },
                                  borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                                  child: Container(
                                    width: 36,
                                    height: 42,
                                    alignment: Alignment.center,
                                    child: Icon(Icons.remove_rounded, size: 18, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showQuickQuantityDialog(product, qty);
                                  },
                                  child: Container(
                                    constraints: const BoxConstraints(minWidth: 32),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    alignment: Alignment.center,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$qty',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            height: 1.1,
                                          ),
                                        ),
                                        Text(
                                          'EDIT',
                                          style: TextStyle(
                                            fontSize: 7.5,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                                            letterSpacing: 0.4,
                                            height: 1.1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: atStockCap
                                      ? () {
                                          HapticFeedback.vibrate();
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                  'Only $maxQty ${product.name} in stock.'),
                                              backgroundColor: const Color(0xFFDC2626),
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      : () {
                                          HapticFeedback.lightImpact();
                                          setState(() => _cartQuantities[product.productId] = qty + 1);
                                        },
                                  borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                                  child: Container(
                                    width: 36,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: atStockCap ? const Color(0xFF94A3B8) : const Color(0xFF1E56E2),
                                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
            ),
            // Live Bill Summary Card (visible when items in cart)
            if (totalCartItems > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.receipt_long_rounded, size: 16, color: Color(0xFF2563EB)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Live Bill Calculation',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _billingGstMode == 'GST'
                                ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7))
                                : (isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _billingGstMode == 'GST' ? 'GST Tax Invoice' : 'Commercial Estimate',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: _billingGstMode == 'GST' ? const Color(0xFF15803D) : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Taxable Goods Subtotal:', style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(AppFormatters.currency(subtotal), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    if (_billingGstMode == 'GST') ...[
                      const SizedBox(height: 6),
                      if (liveIgst > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Integrated GST (IGST):', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            Text(AppFormatters.currency(liveIgst), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Central GST (CGST 50%):', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            Text(AppFormatters.currency(liveCgst), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('State GST (SGST 50%):', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            Text(AppFormatters.currency(liveSgst), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                          ],
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Tax Applied:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          Text('₹0.00 (Non-GST)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                    Divider(height: 18, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Net Payable (₹):', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        Text(
                          AppFormatters.currency(liveGrandTotal),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Place of Supply: ${AppState.getStateNameFromCode(buyerStateCode)} ($buyerStateCode) • ${isIntraState ? "Intra-State Supply" : "Inter-State Supply"}',
                      style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 3. Delivery Notes
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
                    '3. Special Instructions / Delivery Notes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _notesCtrl,
                    style: TextStyle(fontSize: 13.5, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Deliver before 2 PM, urgent replenishment...',
                      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
      bottomNavigationBar: totalCartItems > 0
          ? SafeArea(
              child: Builder(
                builder: (context) {
                  final bookOrderBtn = Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _bookOrderOnly(appState, targetShop),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.bookmark_add_outlined,
                              size: 16,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Book Order',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );

                  final reviewAndBillBtn = Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1D4ED8).withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          CompleteAndBillOrderModal.show(
                            context,
                            destinationShop: targetShop,
                            cartQuantities: _cartQuantities,
                            deliveryNote: _notesCtrl.text.trim(),
                            initialGstCompliance: _billingGstMode == 'GST',
                            initialGstSlabId: _selectedGstSlabId,
                            initialPricingCategory: _selectedPricingCategory,
                            onOrderCompleted: (order, invoice) {
                              widget.onOrderCompleted();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(invoice != null
                                      ? 'Order ${order.orderId} created & billed (${invoice.invoiceNumber})!'
                                      : 'Order ${order.orderId} created successfully!'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                              if (invoice != null) {
                                GstTaxInvoiceViewer.show(context, invoice);
                              }
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Review & Bill', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.2)),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );

                  return ResponsiveContainer(
                    maxWidth: 720,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                            offset: const Offset(0, 6),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: context.screenWidth < 420
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.4) : const Color(0xFFDBEAFE)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.shopping_bag_outlined, size: 12, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$totalCartItems item${totalCartItems > 1 ? 's' : ''}',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              targetShop.shopName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          AppFormatters.currency(liveGrandTotal),
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w900,
                                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        if (_billingGstMode == 'GST' && liveTotalTax > 0)
                                          Text(
                                            'Incl. ${AppFormatters.currency(liveTotalTax)} GST',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(child: bookOrderBtn),
                                    const SizedBox(width: 8),
                                    Expanded(child: reviewAndBillBtn),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isDark ? const Color(0xFF2563EB).withValues(alpha: 0.4) : const Color(0xFFDBEAFE)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.shopping_bag_outlined, size: 12.5, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '$totalCartItems item${totalCartItems > 1 ? 's' : ''}',
                                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Flexible(
                                            child: Text(
                                              targetShop.shopName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        AppFormatters.currency(liveGrandTotal),
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      if (_billingGstMode == 'GST' && liveTotalTax > 0)
                                        Text(
                                          'Incl. ${AppFormatters.currency(liveTotalTax)} GST',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                bookOrderBtn,
                                const SizedBox(width: 8),
                                reviewAndBillBtn,
                              ],
                            ),
                    ),
                  );
                },
              ),
            )
          : null,
    );
  }

  Widget _buildGstBadge(double gstRate, {bool isDark = false}) {
    Color bg;
    Color border;
    Color text;

    if (isDark) {
      if (gstRate == 0.0) {
        bg = const Color(0xFF334155);
        border = const Color(0xFF475569);
        text = const Color(0xFFCBD5E1);
      } else if (gstRate == 5.0) {
        bg = const Color(0xFF064E3B).withValues(alpha: 0.4);
        border = const Color(0xFF059669).withValues(alpha: 0.5);
        text = const Color(0xFF34D399);
      } else if (gstRate == 12.0) {
        bg = const Color(0xFF0C4A6E).withValues(alpha: 0.4);
        border = const Color(0xFF0284C7).withValues(alpha: 0.5);
        text = const Color(0xFF38BDF8);
      } else if (gstRate == 18.0) {
        bg = const Color(0xFF581C87).withValues(alpha: 0.4);
        border = const Color(0xFF9333EA).withValues(alpha: 0.5);
        text = const Color(0xFFC084FC);
      } else if (gstRate == 28.0) {
        bg = const Color(0xFF881337).withValues(alpha: 0.4);
        border = const Color(0xFFE11D48).withValues(alpha: 0.5);
        text = const Color(0xFFFB7185);
      } else {
        bg = const Color(0xFF1E3A8A).withValues(alpha: 0.4);
        border = const Color(0xFF2563EB).withValues(alpha: 0.5);
        text = const Color(0xFF93C5FD);
      }
    } else {
      if (gstRate == 0.0) {
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFE2E8F0);
        text = const Color(0xFF475569);
      } else if (gstRate == 5.0) {
        bg = const Color(0xFFDCFCE7);
        border = const Color(0xFFBBF7D0);
        text = const Color(0xFF15803D);
      } else if (gstRate == 12.0) {
        bg = const Color(0xFFE0F2FE);
        border = const Color(0xFFBAE6FD);
        text = const Color(0xFF0369A1);
      } else if (gstRate == 18.0) {
        bg = const Color(0xFFF3E8FF);
        border = const Color(0xFFE9D5FF);
        text = const Color(0xFF7E22CE);
      } else if (gstRate == 28.0) {
        bg = const Color(0xFFFFE4E6);
        border = const Color(0xFFFECDD3);
        text = const Color(0xFFBE123C);
      } else {
        bg = const Color(0xFFEFF6FF);
        border = const Color(0xFFDBEAFE);
        text = const Color(0xFF1D4ED8);
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Text(
        gstRate == 0.0 ? '0% GST' : 'GST ${gstRate.toInt()}%',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
