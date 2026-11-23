import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:salesarmy/core/widgets/billing_error_dialog.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/settings/presentation/screens/printer_settings_screen.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/utils/product_image_helper.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';

class EstimatedBillScreen extends StatefulWidget {
  final ShopModel? initialShop;

  const EstimatedBillScreen({super.key, this.initialShop});

  @override
  State<EstimatedBillScreen> createState() => _EstimatedBillScreenState();
}

class _EstimateLineItem {
  final ProductModel product;
  int quantity;
  double customRate;

  _EstimateLineItem({
    required this.product,
    required this.quantity,
    required this.customRate,
  });

  double get lineTotal => quantity * customRate;
}

class _EstimatedBillScreenState extends State<EstimatedBillScreen> {
  bool _isCustomBuyer = false;
  ShopModel? _selectedShop;
  bool _isGenerating = false;
  String _selectedPricingCategory = 'Wholesale Price'; // 'Retail Price', 'Wholesale Price', 'MRP'
  bool _isGstEnabled = false;

  final TextEditingController _buyerNameCtrl = TextEditingController(text: 'Walk-in Cash Customer');
  final TextEditingController _buyerPhoneCtrl = TextEditingController();
  final TextEditingController _buyerAddressCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();
  final TextEditingController _discountCtrl = TextEditingController();
  final TextEditingController _searchCtrl = TextEditingController();

  final Map<String, _EstimateLineItem> _lineItems = {};
  late final String _quotationNumber;

  final List<String> _categories = [
    'All',
    'Groceries',
    'Edible Oils',
    'Dairy',
    'Bakery',
    'Snacks',
    'Home Cleaning',
  ];

  @override
  void initState() {
    super.initState();
    _selectedShop = widget.initialShop;
    _quotationNumber = 'EST-${DateTime.now().year}-${(DateTime.now().millisecondsSinceEpoch % 90000 + 10000)}';

    final appState = Provider.of<AppState>(context, listen: false);
    _isGstEnabled = appState.isGstBillingEnabled;
    if (_selectedShop == null && appState.shops.isNotEmpty) {
      _selectedShop = appState.shops.first;
    }

    // Seed first product with qty 1 for instantaneous preview
    if (appState.products.isNotEmpty) {
      final firstProd = appState.products.first;
      _lineItems[firstProd.productId] = _EstimateLineItem(
        product: firstProd,
        quantity: 1,
        customRate: _getProductPrice(firstProd, _selectedPricingCategory),
      );
    }
  }

  double _getProductPrice(ProductModel p, String category) {
    switch (category) {
      case 'Retail Price':
        return p.retailPrice > 0 ? p.retailPrice : p.basePrice;
      case 'Wholesale Price':
        return p.wholesalePrice > 0 ? p.wholesalePrice : p.basePrice;
      case 'MRP':
        return p.customerPrice > 0 ? p.customerPrice : (p.retailPrice > 0 ? p.retailPrice : p.basePrice);
      default:
        return p.wholesalePrice > 0 ? p.wholesalePrice : p.basePrice;
    }
  }

  void _onPricingCategoryChanged(String newCategory) {
    if (_selectedPricingCategory == newCategory) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedPricingCategory = newCategory;
      for (final item in _lineItems.values) {
        item.customRate = _getProductPrice(item.product, newCategory);
      }
    });
  }

  @override
  void dispose() {
    _buyerNameCtrl.dispose();
    _buyerPhoneCtrl.dispose();
    _buyerAddressCtrl.dispose();
    _notesCtrl.dispose();
    _discountCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  double get _itemsSubtotal {
    return _lineItems.values.fold(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get _discountAmount {
    final raw = double.tryParse(_discountCtrl.text.trim()) ?? 0.0;
    return raw.clamp(0.0, _itemsSubtotal);
  }

  double get _totalGstAmount {
    if (!_isGstEnabled) return 0.0;
    final appState = Provider.of<AppState>(context, listen: false);
    final buyerGstin = _isCustomBuyer ? null : _selectedShop?.gstin;
    double sumGst = 0.0;
    for (final item in _lineItems.values) {
      if (item.quantity > 0) {
        final b = appState.calculateGstBreakdown(
          taxableAmount: item.lineTotal,
          gstRate: item.product.gstRate,
          sellerGstin: appState.tenant.gstin,
          buyerGstin: buyerGstin,
        );
        sumGst += b.totalGst;
      }
    }
    return sumGst;
  }

  double get _estimatedGrandTotal {
    return ((_itemsSubtotal - _discountAmount) + _totalGstAmount).clamp(0.0, double.infinity);
  }

  String get _buyerDisplayName {
    if (_isCustomBuyer) {
      return _buyerNameCtrl.text.trim().isNotEmpty ? _buyerNameCtrl.text.trim() : 'Walk-in Cash Customer';
    }
    return _selectedShop?.shopName ?? 'Walk-in Cash Customer';
  }

  String get _buyerPhoneDisplay {
    if (_isCustomBuyer) {
      return _buyerPhoneCtrl.text.trim();
    }
    return _selectedShop?.phone ?? '';
  }

  void _shareViaWhatsApp() {
    final total = _estimatedGrandTotal;
    final items = _lineItems.values.where((item) => item.quantity > 0).toList();

    final buffer = StringBuffer();
    buffer.writeln('📋 *ESTIMATE / QUOTATION*');
    buffer.writeln('Quotation No: $_quotationNumber');
    buffer.writeln('Pricing Category: $_selectedPricingCategory');
    buffer.writeln('Date: ${AppFormatters.date(DateTime.now())} • ${TimeOfDay.now().format(context)}');
    buffer.writeln('-----------------------------------');
    buffer.writeln('Customer: $_buyerDisplayName');
    if (_buyerPhoneDisplay.isNotEmpty) {
      buffer.writeln('Phone: $_buyerPhoneDisplay');
    }
    if (!_isCustomBuyer && _selectedShop?.address != null) {
      buffer.writeln('Address: ${_selectedShop!.address}');
    }
    buffer.writeln('-----------------------------------');
    buffer.writeln('*ITEMS & SPOT RATES ($_selectedPricingCategory):*');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      buffer.writeln('${i + 1}. ${item.product.name}');
      buffer.writeln('   ${item.quantity} units @ ₹${item.customRate.toStringAsFixed(2)} = ₹${item.lineTotal.toStringAsFixed(2)}');
    }

    buffer.writeln('-----------------------------------');
    buffer.writeln('Items Subtotal: ₹${_itemsSubtotal.toStringAsFixed(2)}');
    if (_discountAmount > 0) {
      buffer.writeln('Special Spot Discount: -₹${_discountAmount.toStringAsFixed(2)}');
    }
    if (_isGstEnabled) {
      buffer.writeln('Total GST: +₹${_totalGstAmount.toStringAsFixed(2)}');
    }
    buffer.writeln('*ESTIMATED TOTAL: ₹${total.toStringAsFixed(2)}*');
    if (_notesCtrl.text.trim().isNotEmpty) {
      buffer.writeln('Remarks / Schemes: ${_notesCtrl.text.trim()}');
    }
    buffer.writeln('-----------------------------------');
    buffer.writeln(_isGstEnabled
        ? '_Note: This is a commercial estimate including GST tax breakdown._'
        : '_Note: This is an estimated rough quote for internal agreement. Official tax invoice issued upon dispatch._');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Estimate summary copied to clipboard! Ready to paste in WhatsApp.'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showThermalPrinterPreview() {
    HapticFeedback.lightImpact();
    final items = _lineItems.values.where((item) => item.quantity > 0).toList();
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    final printerService = PrinterService.instance;
    final settings = printerService.settings;
    final isConnected = settings.isEnabled && settings.isConnected;

    final itemsList = items.map((it) => {
      'name': it.product.name,
      'quantity': it.quantity,
      'rate': it.customRate,
      'total': it.lineTotal,
    }).toList();

    final receiptText = printerService.formatEstimateReceipt(
      quotationNumber: _quotationNumber,
      buyerName: _buyerDisplayName,
      buyerPhone: _buyerPhoneDisplay,
      items: itemsList,
      grandTotal: _estimatedGrandTotal,
      discount: _discountAmount,
      notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: const BoxConstraints(maxWidth: 620),
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.print_rounded, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thermal Estimate Slip (${settings.paperSize.toUpperCase()})',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isConnected ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  isConnected ? '${settings.printerName} • Online' : 'Printer Offline',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isConnected ? const Color(0xFF34D399) : const Color(0xFFF87171),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.settings_outlined, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), size: 20),
                          tooltip: 'Printer Settings',
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                            );
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Center(
                    child: Container(
                      width: settings.paperSize == '80mm' ? 360 : 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAFAFA),
                        border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: SelectableText(
                        receiptText,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          height: 1.35,
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Configure', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E56E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 1,
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await printerService.printEstimateReceipt(
                            quotationNumber: _quotationNumber,
                            buyerName: _buyerDisplayName,
                            buyerPhone: _buyerPhoneDisplay,
                            items: itemsList,
                            grandTotal: _estimatedGrandTotal,
                            discount: _discountAmount,
                            notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
                            context: context,
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                        label: Text(
                          'Print Estimate Slip (${settings.copiesCount} Copy)',
                          style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _convertToOfficialBill() {
    final cart = <String, int>{};
    for (final entry in _lineItems.entries) {
      if (entry.value.quantity > 0) {
        cart[entry.key] = entry.value.quantity;
      }
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderTakerFlow(
          initialShop: _isCustomBuyer ? null : _selectedShop,
          initialCart: cart.isNotEmpty ? cart : null,
          onOrderCompleted: () {
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  Future<void> _generateEstimatedBill() async {
    final activeItems = _lineItems.values.where((item) => item.quantity > 0).toList();
    if (activeItems.isEmpty) {
      showAppError(context, 'Please add at least one product with quantity greater than 0.');
      return;
    }

    setState(() => _isGenerating = true);
    HapticFeedback.mediumImpact();

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      final now = DateTime.now();
      final orderId = 'ORD-$_quotationNumber';
      final shopId = _selectedShop?.shopId ?? 'walk_in_customer';
      final createdByUid = appState.currentUid ?? 'owner_admin';

      final orderItems = activeItems.map((item) {
        final b = _isGstEnabled
            ? appState.calculateGstBreakdown(
                taxableAmount: item.lineTotal,
                gstRate: item.product.gstRate,
                sellerGstin: appState.tenant.gstin,
                buyerGstin: _isCustomBuyer ? null : _selectedShop?.gstin,
              )
            : null;
        final itemGst = b?.totalGst ?? 0.0;
        return TransactionItemSnapshot(
          productId: item.product.productId,
          productName: item.product.name,
          sku: item.product.sku ?? '',
          quantity: item.quantity,
          rate: item.customRate,
          taxableAmount: item.lineTotal,
          gstRate: _isGstEnabled ? item.product.gstRate : 0.0,
          cgst: b?.cgst ?? 0.0,
          sgst: b?.sgst ?? 0.0,
          igst: b?.igst ?? 0.0,
          totalGst: itemGst,
          total: item.lineTotal + itemGst,
        );
      }).toList();

      final totalGst = _totalGstAmount;
      final cgstTotal = orderItems.fold(0.0, (sum, it) => sum + it.cgst);
      final sgstTotal = orderItems.fold(0.0, (sum, it) => sum + it.sgst);
      final igstTotal = orderItems.fold(0.0, (sum, it) => sum + it.igst);

      final order = OrderModel(
        orderId: orderId,
        shopId: shopId,
        createdByUid: createdByUid,
        status: 'pending',
        items: orderItems,
        subtotal: _itemsSubtotal,
        totalGst: totalGst,
        grandTotal: _estimatedGrandTotal,
        deliveryNote: _notesCtrl.text.trim().isNotEmpty
            ? _notesCtrl.text.trim()
            : 'Estimate / Spot Quotation',
        placedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      final invoiceId = 'INV-$_quotationNumber';
      final invoice = InvoiceModel(
        invoiceId: invoiceId,
        invoiceNumber: _quotationNumber,
        orderId: orderId,
        shopId: shopId,
        invoiceType: _isGstEnabled ? 'GST' : 'NON_GST',
        invoiceDate: now,
        seller: {
          'firmName': appState.tenant.firmName ?? 'SalesArmy SaaS HQ',
          'gstin': appState.tenant.gstin ?? '',
          'address': appState.tenant.warehouseAddress ?? '',
          'phone': appState.tenant.mobile ?? '',
          'email': appState.tenant.email ?? '',
          'state': 'Maharashtra',
          'stateCode': '27',
        },
        buyer: {
          'shopName': _buyerDisplayName,
          'ownerName': _isCustomBuyer ? _buyerDisplayName : (_selectedShop?.ownerName ?? 'Valued Customer'),
          'gstin': _isCustomBuyer ? 'Unregistered / B2C' : (_selectedShop?.gstin ?? 'Unregistered / B2C'),
          'address': _isCustomBuyer ? _buyerAddressCtrl.text.trim() : (_selectedShop?.address ?? ''),
          'phone': _buyerPhoneDisplay,
          'state': 'Maharashtra',
          'stateCode': '27',
        },
        placeOfSupply: 'Maharashtra',
        items: orderItems,
        taxableSubtotal: _itemsSubtotal,
        cgst: cgstTotal,
        sgst: sgstTotal,
        igst: igstTotal,
        grandTotal: _estimatedGrandTotal,
        paidAmount: 0.0,
        dueAmount: _estimatedGrandTotal,
        paymentStatus: 'unpaid',
        createdAt: now,
        updatedAt: now,
      );

      await appState.addOrder(order, invoice);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Estimate $_quotationNumber generated successfully!'),
          backgroundColor: const Color(0xFF059669),
          behavior: SnackBarBehavior.floating,
        ),
      );

      _showGeneratedBillSuccessDialog(invoice);
    } catch (e) {
      if (mounted) await showBillingErrorDialog(context, e, action: 'generate the estimate');
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  void _showGeneratedBillSuccessDialog(InvoiceModel invoice) {
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 24),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Estimate Generated!',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimate No:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(invoice.invoiceNumber, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Customer:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _buyerDisplayName,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Items Count:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text('${invoice.items.length} product(s)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                    const Divider(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        Text('₹${invoice.grandTotal.toInt()}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1E56E2))),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    _shareViaWhatsApp();
                  },
                  icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
                  label: const Text('Share Estimate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    side: const BorderSide(color: Color(0xFF1E56E2)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showThermalPrinterPreview();
                  },
                  icon: const Icon(Icons.print_rounded, size: 16, color: Color(0xFF1E56E2)),
                  label: const Text('Thermal Print Estimate', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E56E2))),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E56E2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        );
      },
    );
  }



  void _showAddProductsModal(List<ProductModel> products) {
    final isDark = Provider.of<AppState>(context, listen: false).isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String query = '';
        String cat = 'All';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = products.where((p) {
              final matchesQuery = query.isEmpty ||
                  p.name.toLowerCase().contains(query.toLowerCase()) ||
                  (p.sku ?? '').toLowerCase().contains(query.toLowerCase());
              final matchesCat = cat == 'All' || (p.categoryId ?? '').toLowerCase().contains(cat.toLowerCase());
              return matchesQuery && matchesCat;
            }).toList();

            return Container(
              constraints: const BoxConstraints(maxWidth: 620),
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add Products to Quotation',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      onChanged: (val) => setModalState(() => query = val),
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search product by name or SKU...',
                        hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                        focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12)), borderSide: BorderSide(color: Color(0xFF1E56E2), width: 1.5)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: _categories.map((c) {
                        final isSel = cat == c;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(c),
                            selected: isSel,
                            onSelected: (val) {
                              if (val) setModalState(() => cat = c);
                            },
                            backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            selectedColor: const Color(0xFF1E56E2),
                            side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF3B82F6)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            ),
                            labelStyle: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  Divider(height: 16, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(child: Text('No products found', style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final p = filtered[i];
                              final currentItem = _lineItems[p.productId];
                              final inQuote = currentItem != null && currentItem.quantity > 0;

                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: inQuote
                                      ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                                      : (isDark ? const Color(0xFF0F172A) : Colors.white),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: inQuote
                                        ? const Color(0xFF3B82F6)
                                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    ProductImageView(
                                      imageUrl: p.imageUrl,
                                      productName: p.name,
                                      categoryId: p.categoryId,
                                      width: 44,
                                      height: 44,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Base Rate: ₹${p.basePrice.toInt()} • MRP: ₹${p.retailPrice.toInt()}',
                                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (inQuote)
                                      Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 22),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                if (currentItem.quantity > 1) {
                                                  currentItem.quantity--;
                                                } else {
                                                  _lineItems.remove(p.productId);
                                                }
                                              });
                                              setModalState(() {});
                                            },
                                          ),
                                          Text(
                                            '${currentItem.quantity}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_circle, color: Color(0xFF1E56E2), size: 22),
                                            onPressed: () {
                                              HapticFeedback.lightImpact();
                                              setState(() {
                                                currentItem.quantity++;
                                              });
                                              setModalState(() {});
                                            },
                                          ),
                                        ],
                                      )
                                    else
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF1E56E2),
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () {
                                          HapticFeedback.mediumImpact();
                                          setState(() {
                                            _lineItems[p.productId] = _EstimateLineItem(
                                              product: p,
                                              quantity: 1,
                                              customRate: _getProductPrice(p, _selectedPricingCategory),
                                            );
                                          });
                                          setModalState(() {});
                                        },
                                        child: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final products = appState.products;
    final shops = appState.shops;

    final items = _lineItems.values.toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Bill',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
            Text(
              'Rough Quotation & Spot Rate Estimator',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.print_outlined, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
            tooltip: 'Thermal Print Preview',
            onPressed: _showThermalPrinterPreview,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: Color(0xFF059669)),
            tooltip: 'Share on WhatsApp',
            onPressed: _shareViaWhatsApp,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Watermark Notice Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.6) : const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF92400E) : const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isGstEnabled
                          ? 'Commercial estimate with GST tax calculation enabled.'
                          : 'Draft estimate for spot rate negotiation. Unofficial quote without GST.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. Quotation Header Card
            Container(
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
                            child: Icon(Icons.receipt_rounded, size: 18, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E56E2)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _quotationNumber,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.5,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          AppFormatters.date(DateTime.now()),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  // Buyer Selector Switcher
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isCustomBuyer = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !_isCustomBuyer
                                  ? const Color(0xFF1E56E2)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Registered Retailer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: !_isCustomBuyer
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setState(() => _isCustomBuyer = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: _isCustomBuyer
                                  ? const Color(0xFF1E56E2)
                                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              'Walk-in / Custom',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _isCustomBuyer
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Buyer Form / Details
                  if (!_isCustomBuyer) ...[
                    DropdownButtonFormField<String>(
                      key: ValueKey(_selectedShop?.shopId),
                      initialValue: shops.any((s) => s.shopId == _selectedShop?.shopId)
                          ? _selectedShop?.shopId
                          : (shops.isNotEmpty ? shops.first.shopId : null),
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
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                        ),
                      ),
                      items: shops.map((s) {
                        final title = s.shopName.isNotEmpty ? s.shopName : 'Unnamed Shop';
                        final subtitle = s.ownerName.isNotEmpty ? ' (${s.ownerName})' : '';
                        return DropdownMenuItem<String>(
                          value: s.shopId,
                          child: Text(
                            '$title$subtitle',
                            style: TextStyle(
                              fontSize: 13,
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
                          final found = shops.firstWhere((s) => s.shopId == newShopId);
                          setState(() => _selectedShop = found);
                        }
                      },
                    ),
                    if (_selectedShop != null && (_selectedShop!.ownerName.isNotEmpty || (_selectedShop!.phone != null && _selectedShop!.phone!.isNotEmpty))) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Text(
                          '${_selectedShop!.ownerName}${_selectedShop!.phone != null && _selectedShop!.phone!.isNotEmpty ? " • ${_selectedShop!.phone}" : ""}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _buyerNameCtrl,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Customer Name',
                              labelStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _buyerPhoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            decoration: InputDecoration(
                              labelText: 'Mobile Phone',
                              labelStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              filled: true,
                              fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Pricing Category & GST Option Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'PRICING CATEGORY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        _selectedPricingCategory,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E56E2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: ['Retail Price', 'Wholesale Price', 'MRP'].map((category) {
                      final isSelected = _selectedPricingCategory == category;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            onTap: () => _onPricingCategoryChanged(category),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E56E2)
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1E56E2)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.receipt_long_rounded,
                            size: 18,
                            color: _isGstEnabled ? const Color(0xFF059669) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Apply GST (Tax Breakdown)',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                !appState.isGstBillingEnabled
                                    ? 'GST disabled in Agency Settings'
                                    : (_isGstEnabled ? 'Calculates CGST/SGST/IGST tax' : 'Tax disabled (Non-GST estimate)'),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch.adaptive(
                        value: _isGstEnabled && appState.isGstBillingEnabled,
                        activeTrackColor: const Color(0xFF059669),
                        onChanged: appState.isGstBillingEnabled ? (val) {
                          HapticFeedback.lightImpact();
                          setState(() => _isGstEnabled = val);
                        } : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 3. Line Items Section
            Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estimate Items (${items.length})',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E56E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: () => _showAddProductsModal(products),
                        icon: const Icon(Icons.add_rounded, size: 16, color: Colors.white),
                        label: const Text('Add Items', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),

                  if (items.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(Icons.shopping_bag_outlined, size: 40, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                            const SizedBox(height: 8),
                            Text('No items added yet', style: TextStyle(fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _showAddProductsModal(products),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                              ),
                              child: const Text('Browse Product Catalog'),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...items.map((it) {
                      final rateCtrl = TextEditingController(text: it.customRate.toInt().toString());
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                ProductImageView(
                                  imageUrl: it.product.imageUrl,
                                  productName: it.product.name,
                                  categoryId: it.product.categoryId,
                                  width: 42,
                                  height: 42,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        it.product.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'MRP: ₹${it.product.retailPrice.toInt()} • Base: ₹${it.product.basePrice.toInt()}',
                                        style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 20),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    setState(() => _lineItems.remove(it.product.productId));
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                            const SizedBox(height: 8),

                            // Rate & Qty Stepper
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text('Rate: ₹', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155))),
                                    SizedBox(
                                      width: 65,
                                      height: 32,
                                      child: TextField(
                                        controller: rateCtrl,
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                        ),
                                        onChanged: (val) {
                                          final newR = double.tryParse(val.trim());
                                          if (newR != null && newR >= 0) {
                                            setState(() => it.customRate = newR);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),

                                // Qty Stepper
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          if (it.quantity > 1) {
                                            it.quantity--;
                                          } else {
                                            _lineItems.remove(it.product.productId);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(Icons.remove, size: 16, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10),
                                      child: Text(
                                        '${it.quantity}',
                                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() => it.quantity++);
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(color: const Color(0xFF1E56E2), borderRadius: BorderRadius.circular(6)),
                                        child: const Icon(Icons.add, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),

                                // Line Total
                                Text(
                                  '₹${it.lineTotal.toInt()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                    color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 4. Financial Calculations Card
            Container(
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Items Subtotal:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      Text('₹${_itemsSubtotal.toInt()}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Spot Discount Input
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Spot Discount (₹):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669))),
                      SizedBox(
                        width: 90,
                        height: 32,
                        child: TextField(
                          controller: _discountCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.end,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                          decoration: InputDecoration(
                            hintText: '0',
                            filled: true,
                            fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                  if (_isGstEnabled) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('GST Tax:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
                        Text('₹${_totalGstAmount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  const SizedBox(height: 12),

                  // Grand Estimated Total
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'ESTIMATED TOTAL',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                      Text(
                        '₹${_estimatedGrandTotal.toInt()}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 22,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF1E56E2),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Remarks & Scheme notes
                  TextField(
                    controller: _notesCtrl,
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                    decoration: InputDecoration(
                      hintText: 'Add remarks, payment terms, or promotional scheme notes...',
                      hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          border: Border(top: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Convert to Bill Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E56E2),
                    side: const BorderSide(color: Color(0xFF1E56E2), width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _convertToOfficialBill,
                  icon: const Icon(Icons.sync_alt_rounded, size: 16, color: Color(0xFF1E56E2)),
                  label: const Text(
                    'Convert to Bill',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF1E56E2)),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Generate Estimated Bill Button (Primary Action)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  onPressed: _isGenerating ? null : _generateEstimatedBill,
                  icon: _isGenerating
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.receipt_long_rounded, size: 18, color: Colors.white),
                  label: Text(
                    _isGenerating ? 'Generating...' : 'Generate Estimated Bill',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14.5, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
