import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/inventory/data/models/purchase_model.dart';

class RecordPurchaseScreen extends StatefulWidget {
  final PurchaseModel? existingPurchase;
  const RecordPurchaseScreen({super.key, this.existingPurchase});

  @override
  State<RecordPurchaseScreen> createState() => _RecordPurchaseScreenState();
}

class _RecordPurchaseScreenState extends State<RecordPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supplierCtrl = TextEditingController(text: 'Parle Products Pvt Ltd');
  final _billNumberCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime _purchaseDate = DateTime.now();
  String _paymentStatus = 'paid'; // 'paid', 'pending'
  String _paymentMode = 'Bank Transfer'; // 'Bank Transfer', 'UPI', 'Cash'

  final List<PurchaseItemModel> _items = [];

  final List<String> _popularSuppliers = [
    'Parle Products Pvt Ltd',
    'Britannia Industries',
    'Amul Dairy Union',
    'ITC Foods Limited',
    'Tata Consumer Products',
    'Nestlé India Depot',
    'Hindustan Unilever',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingPurchase != null) {
      final p = widget.existingPurchase!;
      _supplierCtrl.text = p.supplierName;
      _billNumberCtrl.text = p.billNumber;
      _notesCtrl.text = p.notes ?? '';
      _purchaseDate = p.purchaseDate;
      _paymentStatus = p.paymentStatus;
      _paymentMode = p.paymentMode;
      _items.addAll(p.items);
    } else {
      _billNumberCtrl.text = 'PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    _billNumberCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.total);
  }

  int get _totalUnits {
    return _items.fold(0, (sum, item) => sum + item.quantity);
  }

  void _addItem(ProductModel product) {
    HapticFeedback.lightImpact();
    final existingIndex = _items.indexWhere((i) => i.productId == product.productId);
    final unitPrice = product.wholesalePrice > 0 ? product.wholesalePrice : product.basePrice;

    setState(() {
      if (existingIndex != -1) {
        final existing = _items[existingIndex];
        final newQty = existing.quantity + 10;
        _items[existingIndex] = PurchaseItemModel(
          productId: existing.productId,
          productName: existing.productName,
          quantity: newQty,
          unitPrice: existing.unitPrice,
          total: newQty * existing.unitPrice,
        );
      } else {
        _items.add(
          PurchaseItemModel(
            productId: product.productId,
            productName: product.name,
            quantity: 20,
            unitPrice: unitPrice > 0 ? unitPrice : 100.0,
            total: (unitPrice > 0 ? unitPrice : 100.0) * 20,
          ),
        );
      }
    });
  }

  void _addCustomItemDialog(bool isDark) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '10');
    final rateCtrl = TextEditingController(text: '150');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Custom Goods / SKU',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
              decoration: InputDecoration(
                labelText: 'Item Name / Description',
                labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Quantity (Units)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: rateCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      labelText: 'Unit Rate (₹)',
                      labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final name = nameCtrl.text.trim();
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 1;
              final rate = double.tryParse(rateCtrl.text.trim()) ?? 0.0;
              if (name.isNotEmpty && qty > 0) {
                setState(() {
                  _items.add(
                    PurchaseItemModel(
                      productId: 'custom_${DateTime.now().millisecondsSinceEpoch}',
                      productName: name,
                      quantity: qty,
                      unitPrice: rate,
                      total: qty * rate,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add Item', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showProductPickerSheet(BuildContext context, AppState appState, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select Catalog Products',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Custom SKU'),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFF1D4ED8)),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _addCustomItemDialog(isDark);
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: appState.products.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      final prod = appState.products[idx];
                      final isSelected = _items.any((i) => i.productId == prod.productId);
                      final wholesale = prod.wholesalePrice > 0 ? prod.wholesalePrice : prod.basePrice;

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF2563EB)
                                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            width: isSelected ? 1.5 : 1.0,
                          ),
                        ),
                        tileColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D4ED8).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, color: Color(0xFF1D4ED8), size: 20),
                        ),
                        title: Text(
                          prod.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: Text(
                          'Current Stock: ${prod.stockQuantity} units • Rate: ₹${wholesale.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isSelected ? const Color(0xFF059669) : const Color(0xFF1D4ED8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () {
                            _addItem(prod);
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            isSelected ? '+ Add More' : 'Add to Bill',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _savePurchase(AppState appState) {
    if (!_formKey.currentState!.validate()) return;
    if (_items.isEmpty) {
      showAppError(context, 'Please add at least one product or item to the purchase bill.');
      return;
    }

    if (widget.existingPurchase != null) {
      final updated = widget.existingPurchase!.copyWith(
        supplierName: _supplierCtrl.text.trim(),
        billNumber: _billNumberCtrl.text.trim(),
        purchaseDate: _purchaseDate,
        itemsDescription: _items.map((i) => '${i.productName} (${i.quantity} pcs)').join(', '),
        totalUnits: _totalUnits,
        totalAmount: _totalAmount,
        paymentStatus: _paymentStatus,
        paymentMode: _paymentMode,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
        items: List.from(_items),
      );
      appState.updatePurchase(updated);
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase ${_billNumberCtrl.text.trim()} updated successfully!'),
          backgroundColor: const Color(0xFF059669),
        ),
      );
      Navigator.pop(context);
      return;
    }

    final purchase = PurchaseModel(
      id: 'pur_${DateTime.now().millisecondsSinceEpoch}',
      supplierName: _supplierCtrl.text.trim(),
      billNumber: _billNumberCtrl.text.trim(),
      purchaseDate: _purchaseDate,
      itemsDescription: _items.map((i) => '${i.productName} (${i.quantity} pcs)').join(', '),
      totalUnits: _totalUnits,
      totalAmount: _totalAmount,
      paymentStatus: _paymentStatus,
      paymentMode: _paymentMode,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
      createdAt: DateTime.now(),
      items: _items,
    );

    appState.addPurchase(purchase);

    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Purchase ${_billNumberCtrl.text.trim()} recorded! $_totalUnits units added to inventory.',
        ),
        backgroundColor: const Color(0xFF059669),
        duration: const Duration(seconds: 3),
      ),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.existingPurchase != null ? 'Edit Purchase Bill' : 'Record Purchase (Goods In)',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => _savePurchase(appState),
            child: const Text(
              'Save',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Supplier & Invoice Card
              _buildSectionCard(
                isDark: isDark,
                title: 'Supplier & Bill Details',
                icon: Icons.storefront_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _supplierCtrl,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontWeight: FontWeight.w700),
                      decoration: InputDecoration(
                        labelText: 'Supplier / Super-Stockist Name *',
                        labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        prefixIcon: const Icon(Icons.business_rounded, size: 20, color: Color(0xFF2563EB)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Supplier name is required' : null,
                    ),
                    const SizedBox(height: 10),
                    // Quick supplier chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _popularSuppliers.map((supplier) {
                          final isSelected = _supplierCtrl.text == supplier;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(supplier, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)))),
                              selected: isSelected,
                              selectedColor: const Color(0xFF1D4ED8),
                              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                              onSelected: (val) {
                                if (val) setState(() => _supplierCtrl.text = supplier);
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _billNumberCtrl,
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Invoice / Bill No. *',
                              labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            ),
                            validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 30)),
                              );
                              if (picked != null) {
                                setState(() => _purchaseDate = picked);
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      AppFormatters.date(_purchaseDate),
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 2. Purchased Goods / Items Card
              _buildSectionCard(
                isDark: isDark,
                title: 'Purchased Goods (Stock In)',
                icon: Icons.inventory_2_rounded,
                trailing: TextButton.icon(
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                  label: const Text('+ Add Goods'),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF2563EB)),
                  onPressed: () => _showProductPickerSheet(context, appState, isDark),
                ),
                child: Column(
                  children: [
                    if (_items.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.add_box_outlined, size: 36, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              'No products added yet',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select goods from catalog or add a custom SKU.',
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1D4ED8),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => _showProductPickerSheet(context, appState, isDark),
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Add Products to Bill', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (ctx, idx) {
                          final item = _items[idx];
                          final prodMatch = appState.products.where((p) => p.productId == item.productId).firstOrNull;
                          final currentStock = prodMatch?.stockQuantity;

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.productName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                                      onPressed: () {
                                        setState(() => _items.removeAt(idx));
                                      },
                                    ),
                                  ],
                                ),
                                if (currentStock != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Current Inventory: $currentStock → New Inventory: ${currentStock + item.quantity} units (+${item.quantity})',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                  ),
                                ],
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    // Quantity Stepper
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (item.quantity > 1) {
                                                setState(() {
                                                  final newQty = item.quantity - 1;
                                                  _items[idx] = PurchaseItemModel(
                                                    productId: item.productId,
                                                    productName: item.productName,
                                                    quantity: newQty,
                                                    unitPrice: item.unitPrice,
                                                    total: newQty * item.unitPrice,
                                                  );
                                                });
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(Icons.remove, size: 16),
                                            ),
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 10),
                                            child: Text(
                                              '${item.quantity}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                final newQty = item.quantity + 1;
                                                _items[idx] = PurchaseItemModel(
                                                  productId: item.productId,
                                                  productName: item.productName,
                                                  quantity: newQty,
                                                  unitPrice: item.unitPrice,
                                                  total: newQty * item.unitPrice,
                                                );
                                              });
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(6),
                                              child: Icon(Icons.add, size: 16),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text('×', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 8),
                                    // Rate field
                                    SizedBox(
                                      width: 80,
                                      child: TextFormField(
                                        initialValue: item.unitPrice.toStringAsFixed(0),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        decoration: InputDecoration(
                                          prefixText: '₹',
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (val) {
                                          final newRate = double.tryParse(val) ?? item.unitPrice;
                                          setState(() {
                                            _items[idx] = PurchaseItemModel(
                                              productId: item.productId,
                                              productName: item.productName,
                                              quantity: item.quantity,
                                              unitPrice: newRate,
                                              total: item.quantity * newRate,
                                            );
                                          });
                                        },
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      AppFormatters.currency(item.total),
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Payment & Settlement Card
              _buildSectionCard(
                isDark: isDark,
                title: 'Payment & Settlement',
                icon: Icons.payments_rounded,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('PAID (Settled)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ),
                            selected: _paymentStatus == 'paid',
                            selectedColor: const Color(0xFF059669),
                            labelStyle: TextStyle(color: _paymentStatus == 'paid' ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                            onSelected: (val) {
                              if (val) setState(() => _paymentStatus = 'paid');
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ChoiceChip(
                            label: const Center(
                              child: Text('PENDING (Credit)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                            ),
                            selected: _paymentStatus == 'pending',
                            selectedColor: const Color(0xFFD97706),
                            labelStyle: TextStyle(color: _paymentStatus == 'pending' ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155))),
                            onSelected: (val) {
                              if (val) setState(() => _paymentStatus = 'pending');
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode
                    Text(
                      'Payment Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Bank Transfer', 'UPI', 'Cash'].map((mode) {
                        final isSelected = _paymentMode == mode;
                        return ChoiceChip(
                          avatar: Icon(
                            mode == 'Cash'
                                ? Icons.money_rounded
                                : (mode == 'UPI' ? Icons.qr_code_rounded : Icons.account_balance_rounded),
                            size: 16,
                            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)),
                          ),
                          label: Text(mode, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF334155)))),
                          selected: isSelected,
                          selectedColor: const Color(0xFF1D4ED8),
                          backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) setState(() => _paymentMode = mode);
                          },
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 12),

                    // Live balance deduction alert indicator
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _paymentStatus == 'paid'
                            ? (_paymentMode == 'Cash'
                                ? const Color(0xFF059669).withValues(alpha: 0.1)
                                : const Color(0xFF2563EB).withValues(alpha: 0.1))
                            : const Color(0xFFD97706).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _paymentStatus == 'paid'
                              ? (_paymentMode == 'Cash' ? const Color(0xFF059669) : const Color(0xFF2563EB))
                              : const Color(0xFFD97706),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _paymentStatus == 'paid' ? Icons.info_outline_rounded : Icons.pending_actions_rounded,
                            size: 18,
                            color: _paymentStatus == 'paid'
                                ? (_paymentMode == 'Cash' ? const Color(0xFF059669) : const Color(0xFF2563EB))
                                : const Color(0xFFD97706),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _paymentStatus == 'paid'
                                  ? (_paymentMode == 'Cash'
                                      ? 'Will deduct ₹${_totalAmount.toStringAsFixed(0)} from In-Hand Cash (Current: ₹${appState.inHandCash.toStringAsFixed(0)})'
                                      : 'Will deduct ₹${_totalAmount.toStringAsFixed(0)} from Bank Account (Current: ₹${appState.inAccountBalance.toStringAsFixed(0)})')
                                  : 'Recorded under Supplier Pending Dues. No balance will be deducted immediately.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: _paymentStatus == 'paid'
                                    ? (_paymentMode == 'Cash' ? const Color(0xFF059669) : const Color(0xFF2563EB))
                                    : const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _notesCtrl,
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        labelText: 'Notes / Bay Location (Optional)',
                        labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_totalUnits units • ${_items.length} SKUs',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      AppFormatters.currency(_totalAmount),
                      style: TextStyle(
                        fontSize: 18.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => _savePurchase(appState),
                icon: const Icon(Icons.check_circle_rounded, size: 20, color: Colors.white),
                label: Text(
                  widget.existingPurchase != null ? 'Save Changes' : 'Save & Add to Stock',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required String title,
    required IconData icon,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D4ED8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFF1D4ED8), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
