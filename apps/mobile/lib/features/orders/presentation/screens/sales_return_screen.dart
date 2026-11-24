import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/data/models/sales_return_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/feature_gate.dart';

/// Opens the Sales Return page.
Future<void> openSalesReturnScreen(
  BuildContext context, {
  ShopModel? preselectedShop,
}) {
  return Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => SalesReturnScreen(preselectedShop: preselectedShop),
    ),
  );
}

/// Dedicated full-screen Sales Return page (was a popup dialog). Same
/// behaviour: pick party + product, quantity, reason; restocks inventory and
/// credits the party's dues via [AppState.processSalesReturn].
class SalesReturnScreen extends StatefulWidget {
  final ShopModel? preselectedShop;

  const SalesReturnScreen({super.key, this.preselectedShop});

  @override
  State<SalesReturnScreen> createState() => _SalesReturnScreenState();
}

class _SalesReturnScreenState extends State<SalesReturnScreen> {
  ShopModel? _selectedShop;
  ProductModel? _selectedProduct;
  int _returnQty = 1;
  final TextEditingController _notesCtrl = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Damaged Goods',
    'Expired Goods',
    'Excess Stock / Unsold',
    'Wrong Item Delivered',
    'Customer Return',
  ];
  String _selectedReason = 'Damaged Goods';

  @override
  void initState() {
    super.initState();
    _selectedShop = widget.preselectedShop;
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final shops = appState.shops;
    final products = appState.products;

    if (_selectedShop == null && shops.isNotEmpty) {
      _selectedShop = shops.first;
    }
    if (_selectedProduct == null && products.isNotEmpty) {
      _selectedProduct = products.first;
    }

    final currentStock = _selectedProduct?.stockQuantity ?? 0;
    // Use retailPrice (typical sale price) for credit calculation, not basePrice
    final unitPrice = _selectedProduct != null
        ? (_selectedProduct!.retailPrice > 0
              ? _selectedProduct!.retailPrice
              : _selectedProduct!.basePrice)
        : 0.0;
    final returnAmount = unitPrice * _returnQty;
    final projectedStock = currentStock + _returnQty;

    final textMain = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final fieldFill = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);
    const accent = Color(0xFF1E56E2);

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: textMuted,
        ),
      ),
    );

    Widget fieldBox(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: fieldFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: child,
    );

    Widget card(List<Widget> children) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0F172A)
          : const Color(0xFFF1F5F9),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                // Compact header (replaces the tall two-line app bar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 4, 16, 6),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Back',
                        icon: Icon(Icons.arrow_back_rounded, color: textMain),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sales Return',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: textMain,
                              ),
                            ),
                            Text(
                              'Restock items & credit party dues',
                              style: TextStyle(fontSize: 12, color: textMuted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: isDark ? 0.25 : 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.assignment_return_rounded,
                          size: 20,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card 1: who & what
                        card([
                          label('Select Party *'),
                          fieldBox(
                            DropdownButtonHideUnderline(
                              child: DropdownButton<ShopModel>(
                                isExpanded: true,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                value: _selectedShop,
                                hint: Text(
                                  'No parties yet',
                                  style: TextStyle(color: textMuted),
                                ),
                                items: shops.map((s) {
                                  return DropdownMenuItem<ShopModel>(
                                    value: s,
                                    child: Text(
                                      '${s.shopName} (${s.ownerName})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: textMain,
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _selectedShop = val);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          label('Select Product to Return *'),
                          fieldBox(
                            DropdownButtonHideUnderline(
                              child: DropdownButton<ProductModel>(
                                isExpanded: true,
                                dropdownColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : Colors.white,
                                value: _selectedProduct,
                                hint: Text(
                                  'No products yet',
                                  style: TextStyle(color: textMuted),
                                ),
                                items: products.map((p) {
                                  return DropdownMenuItem<ProductModel>(
                                    value: p,
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            p.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: textMain,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF1E3A8A)
                                                      .withValues(alpha: 0.4)
                                                : const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Stock: ${p.stockQuantity}',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: isDark
                                                  ? const Color(0xFF60A5FA)
                                                  : accent,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null)
                                    setState(() => _selectedProduct = val);
                                },
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // Card 2: how many, how much, why
                        card([
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label('Return Quantity *'),
                                    Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: fieldFill,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: border),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: Icon(
                                              Icons
                                                  .remove_circle_outline_rounded,
                                              size: 22,
                                              color: textMuted,
                                            ),
                                            onPressed: _returnQty > 1
                                                ? () {
                                                    HapticFeedback.selectionClick();
                                                    setState(
                                                      () => _returnQty--,
                                                    );
                                                  }
                                                : null,
                                          ),
                                          Text(
                                            '$_returnQty',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: textMain,
                                            ),
                                          ),
                                          IconButton(
                                            visualDensity:
                                                VisualDensity.compact,
                                            icon: Icon(
                                              Icons.add_circle_outline_rounded,
                                              size: 22,
                                              color: isDark
                                                  ? const Color(0xFF60A5FA)
                                                  : accent,
                                            ),
                                            onPressed: () {
                                              HapticFeedback.selectionClick();
                                              setState(() => _returnQty++);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    label('Credit Amount'),
                                    Container(
                                      height: 48,
                                      alignment: Alignment.centerLeft,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF064E3B)
                                                  .withValues(alpha: 0.25)
                                            : const Color(0xFFEFFBF4),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF059669)
                                                    .withValues(alpha: 0.4)
                                              : const Color(0xFFBBF7D0),
                                        ),
                                      ),
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          AppFormatters.currency(returnAmount),
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? const Color(0xFF34D399)
                                                : const Color(0xFF16A34A),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          label('Return Reason *'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _reasons.map((r) {
                              final selected = r == _selectedReason;
                              return ChoiceChip(
                                label: Text(r),
                                selected: selected,
                                showCheckmark: false,
                                onSelected: (_) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _selectedReason = r);
                                },
                                labelStyle: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? Colors.white : textMain,
                                ),
                                selectedColor: accent,
                                backgroundColor: fieldFill,
                                side: BorderSide(
                                  color: selected ? accent : border,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                visualDensity: VisualDensity.compact,
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _notesCtrl,
                            style: TextStyle(color: textMain, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Remarks / Batch Number (Optional)',
                              labelStyle: TextStyle(
                                color: textMuted,
                                fontSize: 13,
                              ),
                              hintText: 'e.g. Batch #B402 expiry verified',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8),
                              ),
                              prefixIcon: Icon(
                                Icons.edit_note_rounded,
                                color: textMuted,
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: fieldFill,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: border),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: border),
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 12),

                        // Live restock preview
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E3A8A)
                                      .withValues(alpha: 0.25)
                                : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF1E3A8A)
                                        .withValues(alpha: 0.5)
                                  : const Color(0xFFDBEAFE),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.auto_mode_rounded,
                                size: 20,
                                color: isDark
                                    ? const Color(0xFF60A5FA)
                                    : accent,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Automatic Inventory Restock Preview',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? const Color(0xFF93C5FD)
                                            : accent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Stock $currentStock → $projectedStock (+$_returnQty)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFF16A34A),
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
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
          ),
          child: // Submit Button
          ElevatedButton(
            onPressed:
                _isSubmitting ||
                    _selectedShop == null ||
                    _selectedProduct == null
                ? null
                : () async {
                    if (!FeatureGate.allowWrite(
                      context,
                      feature: 'sales_returns',
                    ))
                      return;
                    setState(() => _isSubmitting = true);
                    HapticFeedback.mediumImpact();

                    final now = DateTime.now();
                    final returnItem = TransactionItemSnapshot(
                      productId: _selectedProduct!.productId,
                      productName: _selectedProduct!.name,
                      quantity: _returnQty,
                      unitPrice: unitPrice,
                      itemSubtotal: returnAmount,
                      total: returnAmount,
                    );

                    final returnModel = SalesReturnModel(
                      returnId: 'ret_${now.millisecondsSinceEpoch}',
                      returnNumber:
                          'RET-${now.year}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}',
                      shopId: _selectedShop!.shopId,
                      shopName: _selectedShop!.shopName,
                      date: now,
                      items: [returnItem],
                      totalAmount: returnAmount,
                      reason: _selectedReason,
                      notes: _notesCtrl.text.trim().isNotEmpty
                          ? _notesCtrl.text.trim()
                          : null,
                      createdAt: now,
                    );

                    await context.read<AppState>().processSalesReturn(
                      returnModel,
                    );

                    if (context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.pop(context);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            'Sales Return processed! Restocked $_returnQty units of ${_selectedProduct!.name} into inventory.',
                          ),
                          backgroundColor: const Color(0xFF16A34A),
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E56E2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Confirm Return & Restock Inventory',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
          ),
        ),
      ),
    );
  }
}
