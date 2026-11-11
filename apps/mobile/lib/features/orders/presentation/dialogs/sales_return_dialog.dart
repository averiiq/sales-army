import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/data/models/sales_return_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/core/utils/formatters.dart';

Future<void> showSalesReturnDialog(BuildContext context, {ShopModel? preselectedShop}) {
  return showDialog(
    context: context,
    builder: (ctx) => _SalesReturnDialogContent(preselectedShop: preselectedShop),
  );
}

class _SalesReturnDialogContent extends StatefulWidget {
  final ShopModel? preselectedShop;

  const _SalesReturnDialogContent({this.preselectedShop});

  @override
  State<_SalesReturnDialogContent> createState() => _SalesReturnDialogContentState();
}

class _SalesReturnDialogContentState extends State<_SalesReturnDialogContent> {
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
    final unitPrice = _selectedProduct?.basePrice ?? 0.0;
    final returnAmount = unitPrice * _returnQty;
    final projectedStock = currentStock + _returnQty;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dialog Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(Icons.assignment_return_rounded, color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Process Sales Return',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Restock items & credit retailer dues',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

              // 1. Retailer / Shop Selector
              Text(
                'Select Retailer / Outlet *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ShopModel>(
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    value: _selectedShop,
                    items: shops.map((s) {
                      return DropdownMenuItem<ShopModel>(
                        value: s,
                        child: Text(
                          '${s.shopName} (${s.ownerName})',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedShop = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Product Selector
              Text(
                'Select Product to Return *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ProductModel>(
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    value: _selectedProduct,
                    items: products.map((p) {
                      return DropdownMenuItem<ProductModel>(
                        value: p,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Stock: ${p.stockQuantity}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedProduct = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Return Quantity Stepper & Price
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Return Quantity *',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.remove_circle_outline_rounded,
                                  size: 22,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                onPressed: _returnQty > 1 ? () {
                                  HapticFeedback.selectionClick();
                                  setState(() => _returnQty--);
                                } : null,
                              ),
                              Text(
                                '$_returnQty',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.add_circle_outline_rounded,
                                  size: 22,
                                  color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Credit Amount',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.25) : const Color(0xFFEFFBF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? const Color(0xFF059669).withValues(alpha: 0.4) : const Color(0xFFBBF7D0),
                            ),
                          ),
                          child: Text(
                            AppFormatters.currency(returnAmount),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. Return Reason
              Text(
                'Return Reason *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    value: _selectedReason,
                    items: _reasons.map((r) {
                      return DropdownMenuItem<String>(
                        value: r,
                        child: Text(
                          r,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedReason = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 5. Notes / Remarks
              TextField(
                controller: _notesCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Remarks / Batch Number (Optional)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  hintText: 'e.g. Batch #B402 expiry verified',
                  hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.edit_note_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 6. Real-Time Restock Preview Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.5) : const Color(0xFFDBEAFE),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_mode_rounded,
                          size: 18,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Automatic Inventory Restock Preview',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Current Stock: $currentStock units',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            size: 14,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Projected: $projectedStock (+$_returnQty)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A),
                              fontWeight: FontWeight.w800,
                            ),
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Submit Button
              ElevatedButton(
                onPressed: _isSubmitting || _selectedShop == null || _selectedProduct == null
                    ? null
                    : () async {
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
                          returnNumber: 'RET-${now.year}-${(now.millisecondsSinceEpoch % 10000).toString().padLeft(4, '0')}',
                          shopId: _selectedShop!.shopId,
                          shopName: _selectedShop!.shopName,
                          date: now,
                          items: [returnItem],
                          totalAmount: returnAmount,
                          reason: _selectedReason,
                          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
                          createdAt: now,
                        );

                        await context.read<AppState>().processSalesReturn(returnModel);

                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Confirm Return & Restock Inventory',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
