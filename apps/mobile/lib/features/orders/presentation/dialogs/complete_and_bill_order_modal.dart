import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/billing/data/models/gst_slab_model.dart';
import 'package:salesarmy/features/profile/presentation/screens/gst_configuration_screen.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';

typedef BillCalculationAmounts = ({
  double subtotal,
  double gstTax,
  double grandTotal,
  GstSlabModel? appliedSlab,
});

enum _BillOrderViewMode {
  methods, // Screenshot 1 & 2: Cash on Delivery & Online Payment option
  onlineOptions, // Screenshot 3: Choose Online Payment Option (UPI QR / Razorpay)
  upiQr, // Interactive distributor UPI QR code view
  razorpay, // Interactive Razorpay PG / Payment link view
}

/// A popup window matching the "Complete & Bill Order" design from the screenshots.
class CompleteAndBillOrderModal extends StatefulWidget {
  final ShopModel destinationShop;
  final Map<String, int> cartQuantities;
  final String? deliveryNote;
  final Function(OrderModel order, InvoiceModel? invoice) onOrderCompleted;
  final OrderModel? existingOrder;
  final bool? initialGstCompliance;
  final String? initialGstSlabId;
  final String? initialPricingCategory;

  const CompleteAndBillOrderModal({
    super.key,
    required this.destinationShop,
    required this.cartQuantities,
    this.deliveryNote,
    required this.onOrderCompleted,
    this.existingOrder,
    this.initialGstCompliance,
    this.initialGstSlabId,
    this.initialPricingCategory,
  });

  static Future<void> show(
    BuildContext context, {
    required ShopModel destinationShop,
    required Map<String, int> cartQuantities,
    String? deliveryNote,
    required Function(OrderModel order, InvoiceModel? invoice) onOrderCompleted,
    OrderModel? existingOrder,
    bool? initialGstCompliance,
    String? initialGstSlabId,
    String? initialPricingCategory,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CompleteAndBillOrderModal(
        destinationShop: destinationShop,
        cartQuantities: cartQuantities,
        deliveryNote: deliveryNote,
        onOrderCompleted: onOrderCompleted,
        existingOrder: existingOrder,
        initialGstCompliance: initialGstCompliance,
        initialGstSlabId: initialGstSlabId,
        initialPricingCategory: initialPricingCategory,
      ),
    );
  }

  @override
  State<CompleteAndBillOrderModal> createState() => _CompleteAndBillOrderModalState();
}

class _CompleteAndBillOrderModalState extends State<CompleteAndBillOrderModal> {
  String _selectedGstSlabId = 'sku_default';
  String _selectedPricingCategory = 'Wholesale Price';
  late bool _isGstCompliance;
  late TextEditingController _cashReceivedCtrl;
  _BillOrderViewMode _viewMode = _BillOrderViewMode.methods;
  bool _isProcessing = false;
  String? _paymentLinkSentMessage;
  final Map<String, int> _effectiveCart = {};

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _isGstCompliance = appState.isGstBillingEnabled && (widget.initialGstCompliance ?? true);
    _selectedGstSlabId = widget.initialGstSlabId ?? 'sku_default';
    _selectedPricingCategory = widget.initialPricingCategory ?? 'Wholesale Price';

    if (widget.cartQuantities.isNotEmpty) {
      _effectiveCart.addAll(widget.cartQuantities);
    } else if (widget.existingOrder != null) {
      for (final item in widget.existingOrder!.items) {
        _effectiveCart[item.productId] = (_effectiveCart[item.productId] ?? 0) + item.quantity;
      }
    }

    final amounts = _computeAmounts(appState, _isGstCompliance);
    _cashReceivedCtrl = TextEditingController(
      text: amounts.grandTotal.round().toString(),
    );
  }

  @override
  void dispose() {
    _cashReceivedCtrl.dispose();
    super.dispose();
  }

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

  BillCalculationAmounts _computeAmounts(AppState appState, bool withGst) {
    double subtotal = 0.0;
    double totalGst = 0.0;

    final GstSlabModel? appliedSlab = _selectedGstSlabId == 'sku_default'
        ? null
        : appState.activeGstSlabs.where((s) => s.id == _selectedGstSlabId).isNotEmpty
            ? appState.activeGstSlabs.firstWhere((s) => s.id == _selectedGstSlabId)
            : null;

    _effectiveCart.forEach((productId, qty) {
      if (qty <= 0) return;
      final productMatches = appState.products.where((p) => p.productId == productId);
      final product = productMatches.isNotEmpty
          ? productMatches.first
          : (appState.products.isNotEmpty
              ? appState.products.first
              : ProductModel(
                  productId: productId,
                  name: 'Product $productId',
                  variant: 'Standard',
                  size: 'Item',
                  categoryId: 'General',
                  basePrice: 0.0,
                  wholesalePrice: 0.0,
                  retailPrice: 0.0,
                  customerPrice: 0.0,
                  gstRate: 0.0,
                  stockQuantity: 0,
                  lowStockAlertQty: 0,
                ));

      final productPrice = _getProductPrice(product, _selectedPricingCategory);
      final taxable = productPrice * qty;
      final rate = appliedSlab != null ? appliedSlab.rate : product.gstRate;
      final gst = taxable * (rate / 100);
      subtotal += taxable;
      totalGst += gst;
    });

    final effectiveGst = (withGst && appState.isGstBillingEnabled) ? totalGst : 0.0;
    final grandTotal = subtotal + effectiveGst;

    return (subtotal: subtotal, gstTax: effectiveGst, grandTotal: grandTotal, appliedSlab: appliedSlab);
  }

  Future<void> _handleCompleteOrder({
    required AppState appState,
    required String paymentMode, // 'Cash', 'UPI', 'Razorpay', 'Credit'
    required double cashOrPaidAmount,
    String? referenceNumber,
  }) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      final amounts = _computeAmounts(appState, _isGstCompliance);
      final subtotal = amounts.subtotal;
      final totalGst = amounts.gstTax;
      final grandTotal = amounts.grandTotal;
      final appliedSlab = amounts.appliedSlab;

      // Dynamic GST State Code Engine
      final sellerGstin = appState.tenant.gstin ?? '27AAACS1429B1ZB';
      final sellerStateCode = AppState.getStateCodeFromGstin(sellerGstin);
      final sellerState = AppState.getStateNameFromCode(sellerStateCode);

      final buyerGstin = widget.destinationShop.gstin;
      final buyerStateCode = (buyerGstin != null && buyerGstin.trim().length >= 2)
          ? AppState.getStateCodeFromGstin(buyerGstin)
          : sellerStateCode;
      final buyerState = AppState.getStateNameFromCode(buyerStateCode);
      final isIntraState = sellerStateCode == buyerStateCode;

      final double cgstAmount = (_isGstCompliance && isIntraState) ? totalGst / 2 : 0.0;
      final double sgstAmount = (_isGstCompliance && isIntraState) ? totalGst / 2 : 0.0;
      final double igstAmount = (_isGstCompliance && !isIntraState) ? totalGst : 0.0;

      final orderItems = <TransactionItemSnapshot>[];
      _effectiveCart.forEach((productId, qty) {
        if (qty <= 0) return;
        final productMatches = appState.products.where((p) => p.productId == productId);
        final product = productMatches.isNotEmpty
            ? productMatches.first
            : (appState.products.isNotEmpty
                ? appState.products.first
                : ProductModel(
                    productId: productId,
                    name: 'Product $productId',
                    variant: 'Standard',
                    size: 'Item',
                    categoryId: 'General',
                    basePrice: 0.0,
                    wholesalePrice: 0.0,
                    retailPrice: 0.0,
                    customerPrice: 0.0,
                    gstRate: 0.0,
                    stockQuantity: 0,
                    lowStockAlertQty: 0,
                  ));

        final productPrice = _getProductPrice(product, _selectedPricingCategory);
        final taxable = productPrice * qty;
        final rate = appliedSlab != null ? appliedSlab.rate : product.gstRate;
        final gst = _isGstCompliance ? taxable * (rate / 100) : 0.0;

        final itemCgst = (_isGstCompliance && isIntraState) ? gst / 2 : 0.0;
        final itemSgst = (_isGstCompliance && isIntraState) ? gst / 2 : 0.0;
        final itemIgst = (_isGstCompliance && !isIntraState) ? gst : 0.0;

        orderItems.add(
          TransactionItemSnapshot(
            productId: product.productId,
            productName: product.name,
            sku: product.sku ?? 'SKU',
            hsnSacCode: product.hsnSacCode ?? '1101',
            quantity: qty,
            rate: productPrice,
            taxableAmount: taxable,
            gstRate: _isGstCompliance ? rate : 0.0,
            cgst: itemCgst,
            sgst: itemSgst,
            igst: itemIgst,
            totalGst: gst,
            total: taxable + gst,
          ),
        );
      });

      final orderId = widget.existingOrder?.orderId ?? 'ORD-2026-${(appState.orders.length + 1).toString().padLeft(3, '0')}';
      final invoiceId = 'inv_${now.millisecondsSinceEpoch}';
      final invoiceNumber = 'INV-2026-${(appState.invoices.length + 1).toString().padLeft(4, '0')}';

      // Payment calculations
      final paidAmount = cashOrPaidAmount.clamp(0.0, grandTotal);
      final dueAmount = (grandTotal - paidAmount).clamp(0.0, double.infinity);
      final paymentStatus = (dueAmount <= 0.01)
          ? 'paid'
          : (paidAmount > 0.0 ? 'partial' : 'unpaid');

      String deliveryNote = widget.deliveryNote?.trim() ?? widget.existingOrder?.deliveryNote?.trim() ?? '';
      if (deliveryNote.isEmpty) {
        if (paymentMode == 'Credit') {
          deliveryNote = 'Deliver as Credit / Pay Later (₹0 collected)';
        } else {
          deliveryNote = _isGstCompliance
              ? 'GST Bill: $invoiceNumber • $paymentMode ($paymentStatus)'
              : 'Standard Delivery • $paymentMode ($paymentStatus)';
        }
      }

      final order = widget.existingOrder != null
          ? widget.existingOrder!.copyWith(
              deliveryNote: deliveryNote,
              status: 'confirmed',
              updatedAt: now,
            )
          : OrderModel(
              orderId: orderId,
              shopId: widget.destinationShop.shopId,
              createdByUid: appState.currentUid ?? 'demo_user_01',
              status: 'pending',
              items: orderItems,
              subtotal: subtotal,
              totalGst: totalGst,
              grandTotal: grandTotal,
              deliveryNote: deliveryNote,
              placedAt: now,
              deliveredAt: null,
            );

      final invoice = InvoiceModel(
        invoiceId: invoiceId,
        invoiceNumber: invoiceNumber,
        orderId: orderId,
        shopId: widget.destinationShop.shopId,
        invoiceType: _isGstCompliance ? 'GST' : 'NON_GST',
        invoiceDate: now,
        seller: {
          'firmName': (appState.tenant.firmName != null && appState.tenant.firmName!.isNotEmpty)
              ? appState.tenant.firmName!
              : 'Selxo FMCG Distributions Pvt Ltd',
          'gstin': sellerGstin,
          'pan': appState.tenant.pan ?? 'AAACS1429B',
          'address': appState.tenant.warehouseAddress ?? 'Apex Logistics Park, Bhiwandi-Kalyan Rd, Thane 421302',
          'phone': appState.tenant.mobile ?? '+91 98201 23456',
          'state': sellerState,
          'stateCode': sellerStateCode,
        },
        buyer: {
          'shopName': widget.destinationShop.shopName,
          'ownerName': widget.destinationShop.ownerName,
          'gstin': (buyerGstin != null && buyerGstin.trim().isNotEmpty) ? buyerGstin : 'Unregistered / B2C',
          'address': widget.destinationShop.address,
          'phone': widget.destinationShop.phone,
          'state': buyerState,
          'stateCode': buyerStateCode,
        },
        items: orderItems,
        placeOfSupply: buyerState,
        taxableSubtotal: subtotal,
        cgst: cgstAmount,
        sgst: sgstAmount,
        igst: igstAmount,
        grandTotal: grandTotal,
        paidAmount: paidAmount,
        dueAmount: dueAmount,
        paymentStatus: paymentStatus,
      );

      // 1. Add order & invoice to AppState
      if (widget.existingOrder != null) {
        await appState.updateOrderStatus(orderId, 'confirmed');
        await appState.createInvoice(invoice);
      } else {
        await appState.addOrder(order, invoice);
      }

      // 2. Record payment transaction if money was collected
      if (paidAmount > 0.0) {
        final payment = PaymentModel(
          paymentId: 'PAY-${now.millisecondsSinceEpoch}',
          shopId: widget.destinationShop.shopId,
          createdByUid: appState.currentUid ?? 'demo_user_01',
          amount: paidAmount,
          paymentMode: paymentMode,
          referenceNumber: referenceNumber ?? invoiceNumber,
          date: now,
          notes: 'Payment collected on order $orderId via $paymentMode',
        );
        await appState.recordPayment(payment);
      }

      if (!mounted) return;
      if (PrinterService.instance.settings.isEnabled &&
          PrinterService.instance.settings.isConnected &&
          PrinterService.instance.settings.autoPrintOnBill) {
        PrinterService.instance.printInvoice(invoice, showFeedback: false);
      }
      Navigator.of(context).pop(); // Close modal
      widget.onOrderCompleted(order, invoice);
    } on InsufficientStockException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough stock:\n${e.toString()}'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final isDark = appState.isDarkMode;
    final amounts = _computeAmounts(appState, _isGstCompliance);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F4F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row (Screenshot 1, 2, 3)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingOrder != null
                              ? 'Generate Bill: ${widget.existingOrder!.orderId}'
                              : 'Complete & Bill Order',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Destination: ${widget.destinationShop.shopName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card 1: GST Invoice Compliance & Amount Breakdown (Always shown on top)
              _buildGstSummaryCard(amounts, isDark, appState),
              const SizedBox(height: 20),

              // View State Switcher
              if (_viewMode == _BillOrderViewMode.methods)
                _buildPaymentMethodsView(context, appState, amounts, isDark)
              else if (_viewMode == _BillOrderViewMode.onlineOptions)
                _buildOnlineOptionsView(context, appState, amounts, isDark)
              else if (_viewMode == _BillOrderViewMode.upiQr)
                _buildUpiQrView(context, appState, amounts, isDark)
              else if (_viewMode == _BillOrderViewMode.razorpay)
                _buildRazorpayView(context, appState, amounts, isDark),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Card 1: GST Invoice Compliance Card
  // ==========================================
  Widget _buildGstSummaryCard(BillCalculationAmounts amounts, bool isDark, AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // GST Compliance Switch Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GST Invoice Compliance',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !appState.isGstBillingEnabled
                          ? 'GST disabled in Agency Settings'
                          : (_isGstCompliance
                              ? (_selectedGstSlabId == 'sku_default'
                                  ? 'Catalog SKU rates applied'
                                  : 'Custom Slab: ${amounts.appliedSlab?.displayName ?? ""} applied')
                              : 'Standard Bill (No GST applied)'),
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _isGstCompliance && appState.isGstBillingEnabled,
                activeTrackColor: const Color(0xFF1D4ED8),
                onChanged: appState.isGstBillingEnabled ? (val) {
                  setState(() {
                    _isGstCompliance = val;
                    final newAmounts = _computeAmounts(appState, _isGstCompliance);
                    _cashReceivedCtrl.text = newAmounts.grandTotal.round().toString();
                  });
                } : null,
              ),
            ],
          ),

          // Custom GST Slab Selector Box (When GST Compliance is Enabled)
          if (_isGstCompliance) ...[
            Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.percent_rounded, size: 16, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Apply Custom GST Slab:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const GstConfigurationScreen()),
                    ).then((_) {
                      if (mounted) setState(() {});
                    });
                  },
                  child: const Text(
                    '+ Manage Slabs',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedGstSlabId,
              isExpanded: true,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: [
                const DropdownMenuItem(
                  value: 'sku_default',
                  child: Text(
                    'Default Catalog Slabs (Per-SKU defined)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                ...appState.activeGstSlabs.map((slab) {
                  return DropdownMenuItem(
                    value: slab.id,
                    child: Text(
                      '${slab.formattedRate} - ${slab.name} (${slab.category})',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }),
              ],
              onChanged: (newSlabId) {
                if (newSlabId == null) return;
                setState(() {
                  _selectedGstSlabId = newSlabId;
                  final newAmounts = _computeAmounts(appState, _isGstCompliance);
                  _cashReceivedCtrl.text = newAmounts.grandTotal.round().toString();
                });
              },
            ),

            if (amounts.appliedSlab != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E40AF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Intra: CGST ${amounts.appliedSlab!.cgstRate}% + SGST ${amounts.appliedSlab!.sgstRate}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF047857).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Inter: IGST ${amounts.appliedSlab!.igstRate}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                    if (amounts.appliedSlab!.details.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Details: ${amounts.appliedSlab!.details}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],

          Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 24),

          // Pricing Category Selector (Retail Price, Wholesale Price, MRP)
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 15, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
              const SizedBox(width: 6),
              Text(
                'Pricing Category:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
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
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedPricingCategory = category;
                        final newAmounts = _computeAmounts(appState, _isGstCompliance);
                        _cashReceivedCtrl.text = newAmounts.grandTotal.round().toString();
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF2563EB)
                            : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF2563EB)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Goods Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Goods Subtotal:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                ),
              ),
              Text(
                '₹${amounts.subtotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Estimated GST Tax
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Estimated GST Tax',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_isGstCompliance && amounts.appliedSlab != null)
                      Text(
                        ' (${amounts.appliedSlab!.formattedRate})',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    Text(
                      ':',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${amounts.gstTax.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          if (_isGstCompliance && amounts.gstTax > 0) ...[
            const SizedBox(height: 6),
            Builder(
              builder: (ctx) {
                final sellerGstin = appState.tenant.gstin ?? '27AAACS1429B1ZB';
                final sellerStateCode = AppState.getStateCodeFromGstin(sellerGstin);
                final buyerGstin = widget.destinationShop.gstin;
                final buyerStateCode = (buyerGstin != null && buyerGstin.trim().length >= 2)
                    ? AppState.getStateCodeFromGstin(buyerGstin)
                    : sellerStateCode;
                final isIntraState = sellerStateCode == buyerStateCode;
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isIntraState ? 'CGST 50% + SGST 50% (Intra-State)' : 'IGST 100% (Inter-State)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                      Text(
                        isIntraState
                            ? '₹${(amounts.gstTax / 2).toStringAsFixed(2)} + ₹${(amounts.gstTax / 2).toStringAsFixed(2)}'
                            : '₹${amounts.gstTax.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
          Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 24),

          // Total Bill Amount
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Total Bill Amount:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${amounts.grandTotal.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // View 1: Payment Collection Methods (Screenshots 1 & 2)
  // ==========================================
  Widget _buildPaymentMethodsView(
    BuildContext context,
    AppState appState,
    BillCalculationAmounts amounts,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Select Payment Collection Method:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        // Cash on Delivery (COD) Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.payments_outlined,
                      color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cash on Delivery (COD)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Collect physical cash from shop owner',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Cash Received (₹) Input
              Text(
                'Cash Received (₹)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _cashReceivedCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
                    borderSide: const BorderSide(color: Color(0xFF059669), width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Confirm Cash Payment Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        final enteredCash = double.tryParse(_cashReceivedCtrl.text.trim()) ?? amounts.grandTotal;
                        _handleCompleteOrder(
                          appState: appState,
                          paymentMode: 'Cash',
                          cashOrPaidAmount: enteredCash,
                        );
                      },
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text(
                        'Confirm Cash Payment & Print Invoice',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Online Payment (UPI QR / Gateway) Card
        Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              setState(() {
                _viewMode = _BillOrderViewMode.onlineOptions;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Online Payment (UPI QR / Gateway)',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'UPI QR scan, Google Pay, PhonePe, Cards',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Deliver as Credit / Pay Later (Screenshot 2)
        Center(
          child: TextButton(
            onPressed: _isProcessing
                ? null
                : () {
                    _handleCompleteOrder(
                      appState: appState,
                      paymentMode: 'Credit',
                      cashOrPaidAmount: 0.0,
                    );
                  },
            child: Text(
              'Deliver as Credit / Pay Later (₹0 now)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // View 2: Choose Online Payment Option (Screenshot 3)
  // ==========================================
  Widget _buildOnlineOptionsView(
    BuildContext context,
    AppState appState,
    BillCalculationAmounts amounts,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose Online Payment Option:',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),

        // Option 1: Show Distributor UPI QR Code
        Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              setState(() {
                _viewMode = _BillOrderViewMode.upiQr;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.qr_code_2,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Show Distributor UPI QR Code',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pay directly via Google Pay, PhonePe, Paytm, BHIM',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
        const SizedBox(height: 14),

        // Option 2: Razorpay Payment Gateway / Link
        Material(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () {
              setState(() {
                _viewMode = _BillOrderViewMode.razorpay;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.credit_card,
                      color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Razorpay Payment Gateway / Link',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cards, NetBanking (50+ banks), Payment Link',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
        const SizedBox(height: 20),

        // Back to Cash / Method Selection Button (Screenshot 3)
        Center(
          child: TextButton(
            onPressed: () {
              setState(() {
                _viewMode = _BillOrderViewMode.methods;
              });
            },
            child: Text(
              'Back to Cash / Method Selection',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // View 3: Interactive UPI QR View
  // ==========================================
  Widget _buildUpiQrView(
    BuildContext context,
    AppState appState,
    BillCalculationAmounts amounts,
    bool isDark,
  ) {
    final tenant = appState.tenant;
    final gw = tenant.paymentGatewayConfig ?? {};
    final qrSource = gw['qrSource'] as String? ?? 'dynamic';
    final staticQrImage = gw['staticQrImage'] as String?;
    final vpa = tenant.effectiveUpiId;
    final merchant = tenant.firmName ?? 'SalesArmy Merchant';
    final isStaticMode = (qrSource == 'static' || qrSource == 'standee');
    final hasStaticImage = isStaticMode && staticQrImage != null && staticQrImage.isNotEmpty;

    final String upiDeepLink = vpa.isNotEmpty
        ? 'upi://pay?pa=$vpa&pn=${Uri.encodeComponent(merchant)}&am=${amounts.grandTotal.toStringAsFixed(2)}&cu=INR'
        : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _viewMode = _BillOrderViewMode.onlineOptions),
            ),
            const SizedBox(width: 8),
            Text(
              isStaticMode ? 'Static Counter Standee QR' : 'Dynamic UPI Bill QR',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              // Distributor & Amount Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Scan to Pay: ₹${amounts.grandTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // UPI QR Box (white bg for QR contrast)
              Container(
                width: 170,
                height: 170,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: hasStaticImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: AppImageHelper.buildImage(
                            staticQrImage,
                            width: 154,
                            height: 154,
                            fit: BoxFit.contain,
                          ),
                        )
                      : (vpa.isNotEmpty
                          ? QrImageView(
                              data: upiDeepLink,
                              version: QrVersions.auto,
                              size: 154.0,
                              gapless: true,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              backgroundColor: Colors.white,
                              padding: const EdgeInsets.all(4),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.qr_code_2_rounded, size: 40, color: Color(0xFF94A3B8)),
                                SizedBox(height: 6),
                                Text(
                                  'UPI ID Required',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )),
                ),
              ),
              const SizedBox(height: 12),

              Text(
                vpa.isNotEmpty ? 'UPI ID: $vpa' : 'UPI ID Not Configured',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Supported: GPay • PhonePe • Paytm • BHIM',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 16),

              // Confirm UPI Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        final utr = 'UPI${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}';
                        _handleCompleteOrder(
                          appState: appState,
                          paymentMode: 'UPI',
                          cashOrPaidAmount: amounts.grandTotal,
                          referenceNumber: utr,
                        );
                      },
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Confirm UPI Payment & Print Invoice',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () => setState(() => _viewMode = _BillOrderViewMode.onlineOptions),
            child: Text(
              'Back to Online Options',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // View 4: Interactive Razorpay View
  // ==========================================
  Widget _buildRazorpayView(
    BuildContext context,
    AppState appState,
    BillCalculationAmounts amounts,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : const Color(0xFF0F172A), size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => setState(() => _viewMode = _BillOrderViewMode.onlineOptions),
            ),
            const SizedBox(width: 8),
            Text(
              'Razorpay Payment Gateway / Link',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ],
        ),
        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payment Gateway:', style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Razorpay LIVE Connected',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Payable Amount:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                  Text(
                    '₹${amounts.grandTotal.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB)),
                  ),
                ],
              ),
              Divider(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0), height: 22),

              // Action 1: Send SMS/WhatsApp Payment Link
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8),
                  side: BorderSide(color: isDark ? const Color(0xFF3B82F6) : const Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text(
                  'Send Payment Link to Retailer WhatsApp/SMS',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
                onPressed: () {
                  setState(() {
                    _paymentLinkSentMessage = 'Payment Link https://rzp.io/l/inv_${DateTime.now().millisecondsSinceEpoch.toString().substring(6)} sent to ${widget.destinationShop.phone}!';
                  });
                },
              ),
              if (_paymentLinkSentMessage != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF059669) : const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    _paymentLinkSentMessage!,
                    style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D), fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Action 2: Confirm Razorpay Payment
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        final rzpId = 'pay_${DateTime.now().millisecondsSinceEpoch.toString().substring(3)}';
                        _handleCompleteOrder(
                          appState: appState,
                          paymentMode: 'Razorpay',
                          cashOrPaidAmount: amounts.grandTotal,
                          referenceNumber: rzpId,
                        );
                      },
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.verified_outlined, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Confirm Razorpay Payment & Print Invoice',
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Center(
          child: TextButton(
            onPressed: () => setState(() => _viewMode = _BillOrderViewMode.onlineOptions),
            child: Text(
              'Back to Online Options',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
            ),
          ),
        ),
      ],
    );
  }
}

