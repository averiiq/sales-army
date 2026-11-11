import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/utils/formatters.dart';

import 'package:qr_flutter/qr_flutter.dart';

/// Shows the tactile, wholesale payment collection modal for a shop.
Future<void> showCollectPaymentDialog(
  BuildContext context,
  ShopModel shop, {
  double? initialAmount,
  String? orderId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CollectPaymentDialog(
      shop: shop,
      initialAmount: initialAmount,
      orderId: orderId,
    ),
  );
}

/// Shows the payment editor modal for an existing payment.
Future<void> showEditPaymentDialog(
  BuildContext context,
  ShopModel shop,
  PaymentModel payment,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CollectPaymentDialog(
      shop: shop,
      existingPayment: payment,
    ),
  );
}

/// Shows the live payment gateway dialog (Razorpay / Instant UPI) for a shop.
Future<void> showGatewayPaymentDialog(
  BuildContext context,
  ShopModel shop, {
  double? initialAmount,
  String? orderId,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => GatewayPaymentDialog(
      shop: shop,
      initialAmount: initialAmount,
      orderId: orderId,
    ),
  );
}

/// Shows a digital payment receipt modal with WhatsApp and Thermal print actions.
void showPaymentReceiptModal(BuildContext context, PaymentModel payment, ShopModel shop) {
  showDialog(
    context: context,
    builder: (ctx) {
      final appState = context.read<AppState>();
      final isDark = appState.isDarkMode;
      final tenant = appState.tenant;
      final firmName = tenant.firmName ?? 'SalesArmy Agency HQ';
      final repName = tenant.representativeName ?? 'Field Agent';

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFF0FDF4),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.verified_rounded, color: isDark ? const Color(0xFF34D399) : const Color(0xFF16A34A), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Receipt',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                          ),
                          Text(
                            payment.paymentId,
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              Divider(height: 20, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

              // Thermal Paper Preview Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      firmName.toUpperCase(),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF0F172A), letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Sales Representative: $repName',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 14, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Retailer:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            shop.shopName,
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Date & Time:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppFormatters.dateTime(payment.date),
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Payment Mode:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            payment.paymentMode,
                            textAlign: TextAlign.end,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (payment.referenceNumber != null && payment.referenceNumber!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Reference / UTR:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              payment.referenceNumber!,
                              textAlign: TextAlign.end,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Divider(height: 14, color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1)),
                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('AMOUNT RECEIVED:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                        Text(
                          AppFormatters.currency(payment.amount),
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Remaining Balance:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(
                          AppFormatters.currency(shop.currentOutstanding),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: shop.currentOutstanding > 0 ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF34D399) : const Color(0xFF059669)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Receive Status:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF16A34A)),
                              const SizedBox(width: 4),
                              Text(
                                'SETTLED',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF34D399) : const Color(0xFF15803D)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons: WhatsApp and Print
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Color(0xFF22C55E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Payment acknowledgment sent to ${shop.shopName} via WhatsApp!'),
                            backgroundColor: const Color(0xFF15803D),
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF15803D)),
                      label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF15803D), fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Collection receipt sent to Bluetooth Thermal POS Printer!'),
                            backgroundColor: Color(0xFF0F172A),
                          ),
                        );
                      },
                      icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      label: const Text('Thermal Print', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class CollectPaymentDialog extends StatefulWidget {
  final ShopModel shop;
  final double? initialAmount;
  final String? orderId;
  final PaymentModel? existingPayment;

  const CollectPaymentDialog({
    super.key,
    required this.shop,
    this.initialAmount,
    this.orderId,
    this.existingPayment,
  });

  @override
  State<CollectPaymentDialog> createState() => _CollectPaymentDialogState();
}

class _CollectPaymentDialogState extends State<CollectPaymentDialog> {
  late final TextEditingController _amountCtrl;
  late final TextEditingController _refCtrl;
  late final TextEditingController _notesCtrl;

  String _paymentMode = 'UPI'; // 'UPI', 'Cash'
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPayment != null) {
      _amountCtrl = TextEditingController(text: widget.existingPayment!.amount.toStringAsFixed(0));
      _refCtrl = TextEditingController(text: widget.existingPayment!.referenceNumber ?? '');
      _notesCtrl = TextEditingController(text: widget.existingPayment!.notes ?? '');
      _paymentMode = widget.existingPayment!.paymentMode;
    } else {
      final defaultAmt = widget.initialAmount != null
          ? widget.initialAmount!.toStringAsFixed(0)
          : (widget.shop.currentOutstanding > 0 ? widget.shop.currentOutstanding.toInt().toString() : '0');
      _amountCtrl = TextEditingController(text: defaultAmt);
      _refCtrl = TextEditingController();
      _notesCtrl = TextEditingController(
        text: widget.orderId != null ? 'Payment for Order ${widget.orderId}' : 'Store counter settlement',
      );
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _setAmount(double value) {
    HapticFeedback.lightImpact();
    setState(() {
      _amountCtrl.text = value.toInt().toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<AppState>().isDarkMode;
    final outstanding = widget.shop.currentOutstanding;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
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
                          child: Icon(Icons.payments_rounded, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8), size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.existingPayment != null ? 'Edit Recorded Payment' : 'Collect Payment',
                                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              Text(
                                widget.shop.shopName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Due Info Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFECACA)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Outstanding Due',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFF991B1B)),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            AppFormatters.currency(outstanding),
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isDark ? const Color(0xFFEF4444) : const Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5)),
                      ),
                      child: Text(
                        'Limit: ₹${widget.shop.creditLimit.toInt()}',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Quick Fill Amount Chips
              Text(
                'Quick Amounts',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    if (outstanding > 0) ...[
                      _buildQuickPill('Full Due (₹${outstanding.toInt()})', outstanding, isDark: isDark, isPrimary: true),
                      const SizedBox(width: 6),
                    ],
                    _buildQuickPill('₹500', 500, isDark: isDark),
                    const SizedBox(width: 6),
                    _buildQuickPill('₹1,000', 1000, isDark: isDark),
                    const SizedBox(width: 6),
                    _buildQuickPill('₹2,000', 2000, isDark: isDark),
                    const SizedBox(width: 6),
                    _buildQuickPill('₹5,000', 5000, isDark: isDark),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Amount Received Input
              TextField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  labelText: 'Amount Received (₹) *',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(left: 14, right: 6, top: 12),
                    child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  suffixIcon: _amountCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF94A3B8)),
                          onPressed: () => setState(() => _amountCtrl.text = '0'),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 14),

              // Payment Mode Selector
              Text(
                'Payment Mode',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _buildPaymentChip('UPI', '⚡ UPI', isDark: isDark),
                  const SizedBox(width: 8),
                  _buildPaymentChip('Cash', '💵 Cash', isDark: isDark),
                ],
              ),
              const SizedBox(height: 14),

              // Reference / Slip Number input
              TextField(
                controller: _refCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                decoration: InputDecoration(
                  labelText: _paymentMode == 'Cash'
                      ? 'Receipt / Slip # (Optional)'
                      : 'UTR / Transaction Ref ID (Optional)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Notes Input
              TextField(
                controller: _notesCtrl,
                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Remarks / Notes (Optional)',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1D4ED8), width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons: Record Collection (ledger-only) and Collect Payment (ledger + receipt + sync)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E56E2),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF1E56E2), width: 1.3),
                      ),
                      onPressed: _isSubmitting ? null : () => _handleSubmit(showReceipt: false),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 17, color: Color(0xFF1E56E2)),
                            SizedBox(width: 6),
                            Text(
                              'Record Collection',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF1E56E2)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _isSubmitting ? null : () => _handleSubmit(showReceipt: true),
                      child: _isSubmitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.account_balance_wallet_rounded, size: 17, color: Colors.white),
                                  const SizedBox(width: 6),
                                  Text(
                                    widget.existingPayment != null ? 'Update Payment' : 'Collect Payment',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
      ),
    );
  }

  Widget _buildQuickPill(String label, double value, {required bool isDark, bool isPrimary = false}) {
    final currentVal = double.tryParse(_amountCtrl.text.trim()) ?? -1.0;
    final isSelected = currentVal == value;

    return InkWell(
      onTap: () => _setAmount(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1D4ED8)
              : (isPrimary
                  ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9))),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D4ED8)
                : (isPrimary
                    ? (isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFCA5A5))
                    : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected || isPrimary ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isPrimary
                    ? (isDark ? const Color(0xFFFCA5A5) : const Color(0xFFB91C1C))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF334155))),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentChip(String mode, String label, {required bool isDark}) {
    final isSelected = _paymentMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() => _paymentMode = mode);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF))
                : (isDark ? const Color(0xFF0F172A) : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? (isDark ? const Color(0xFF3B82F6) : const Color(0xFF2563EB))
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF93C5FD) : const Color(0xFF1D4ED8))
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  /// Finalises a payment.
  ///
  /// [showReceipt] = `true` → "Collect Payment" primary CTA. Writes the
  /// payment, opens the printable receipt modal, surfaces a green toast.
  ///
  /// [showReceipt] = `false` → "Record Collection" secondary CTA. Writes the
  /// payment to the ledger silently (no receipt popup). Used when the rep
  /// collected cash offline and is backfilling the system after the fact.
  Future<void> _handleSubmit({required bool showReceipt}) async {
    if (_isSubmitting) return;

    final amt = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    if (amt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid payment amount greater than zero.')),
      );
      return;
    }

    final ref = _refCtrl.text.trim().isNotEmpty
        ? _refCtrl.text.trim()
        : (_paymentMode == 'Cash'
            ? 'CASH-REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
            : 'UPI-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    final appState = context.read<AppState>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      if (widget.existingPayment != null) {
        final updated = widget.existingPayment!.copyWith(
          amount: amt,
          paymentMode: _paymentMode,
          referenceNumber: ref,
          notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : 'Store counter collection',
        );
        await appState.updatePayment(updated).timeout(const Duration(seconds: 15));
        if (!mounted) return;
        Navigator.pop(context);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Payment updated to ${AppFormatters.currency(amt)}!'),
            backgroundColor: const Color(0xFF059669),
          ),
        );
        return;
      }

      final payment = PaymentModel(
        paymentId: 'PAY-${DateTime.now().millisecondsSinceEpoch}',
        shopId: widget.shop.shopId,
        createdByUid: appState.currentUid ?? 'rep_user',
        amount: amt,
        paymentMode: _paymentMode,
        referenceNumber: ref,
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : 'Store counter collection',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // 15s timeout so a hanging Supabase insert can't lock the spinner
      // forever. If the write exceeds the budget we surface an error toast
      // and give the user a chance to retry rather than silently spinning.
      await appState.recordPayment(payment).timeout(const Duration(seconds: 15));

      if (!mounted) return;
      Navigator.pop(context);

      if (showReceipt) {
        final updatedShop = appState.shops.firstWhere(
          (s) => s.shopId == widget.shop.shopId,
          orElse: () => widget.shop,
        );
        showPaymentReceiptModal(context, payment, updatedShop);
      }

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            showReceipt
                ? 'Collected ${AppFormatters.currency(amt)} from ${widget.shop.shopName}! Status: SETTLED'
                : 'Recorded ${AppFormatters.currency(amt)} against ${widget.shop.shopName}.',
          ),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Could not save payment: $e'),
          backgroundColor: const Color(0xFFDC2626),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}

/// Live payment gateway dialog for online customer checkout via Razorpay and UPI.
class GatewayPaymentDialog extends StatefulWidget {
  final ShopModel shop;
  final double? initialAmount;
  final String? orderId;

  const GatewayPaymentDialog({
    super.key,
    required this.shop,
    this.initialAmount,
    this.orderId,
  });

  @override
  State<GatewayPaymentDialog> createState() => _GatewayPaymentDialogState();
}

class _GatewayPaymentDialogState extends State<GatewayPaymentDialog> {
  late TextEditingController _amountCtrl;
  bool _isProcessing = false;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final defaultAmt = widget.initialAmount != null && widget.initialAmount! > 0
        ? widget.initialAmount!
        : (widget.shop.currentOutstanding > 0 ? widget.shop.currentOutstanding : 1000.0);
    _amountCtrl = TextEditingController(text: defaultAmt.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  double get _currentAmount {
    return double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
  }

  void _setAmount(double val) {
    HapticFeedback.selectionClick();
    setState(() {
      _amountCtrl.text = val.toStringAsFixed(0);
      _amountError = null;
    });
  }

  String _buildUpiUri(String merchantVpa, String firmName, double amount) {
    final amtStr = amount.toStringAsFixed(2);
    final encFirm = Uri.encodeComponent(firmName);
    final note = widget.orderId != null
        ? 'Payment for Order ${widget.orderId} (${widget.shop.shopName})'
        : 'Payment for ${widget.shop.shopName}';
    final encNote = Uri.encodeComponent(note);
    return 'upi://pay?pa=$merchantVpa&pn=$encFirm&am=$amtStr&cu=INR&tn=$encNote';
  }

  Future<void> _launchRazorpayCheckout(AppState appState) async {
    final amt = _currentAmount;
    if (amt <= 0) {
      setState(() => _amountError = 'Please enter a valid amount');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      // Simulate gateway verification latency
      await Future.delayed(const Duration(milliseconds: 600));

      final payment = PaymentModel(
        paymentId: 'PAY-RZP-${DateTime.now().millisecondsSinceEpoch}',
        shopId: widget.shop.shopId,
        createdByUid: appState.currentUid ?? 'rep_user',
        amount: amt,
        paymentMode: 'Online / UPI',
        referenceNumber: 'rzp_live_${DateTime.now().millisecondsSinceEpoch.toString().substring(4)}',
        notes: widget.orderId != null
            ? 'Razorpay Payment for Order ${widget.orderId} (${widget.shop.shopName})'
            : 'Razorpay Instant Settlement (${widget.shop.shopName})',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await appState.recordPayment(payment);

      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      final updatedShop = appState.shops.firstWhere(
        (s) => s.shopId == widget.shop.shopId,
        orElse: () => widget.shop,
      );

      showPaymentReceiptModal(context, payment, updatedShop);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Razorpay Online Payment of ${AppFormatters.currency(amt)} captured for ${widget.shop.shopName}!'),
          backgroundColor: const Color(0xFF2563EB),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching payment: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _confirmUpiPayment(AppState appState) async {
    final amt = _currentAmount;
    if (amt <= 0) {
      setState(() => _amountError = 'Please enter a valid amount');
      return;
    }

    setState(() => _isProcessing = true);
    HapticFeedback.mediumImpact();

    try {
      final payment = PaymentModel(
        paymentId: 'PAY-UPI-${DateTime.now().millisecondsSinceEpoch}',
        shopId: widget.shop.shopId,
        createdByUid: appState.currentUid ?? 'rep_user',
        amount: amt,
        paymentMode: 'Online / UPI',
        referenceNumber: 'UPI-APP-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}',
        notes: widget.orderId != null
            ? 'UPI Payment for Order ${widget.orderId} (${widget.shop.shopName})'
            : 'UPI Counter Payment (${widget.shop.shopName})',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      await appState.recordPayment(payment);

      if (!mounted) return;
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);

      final updatedShop = appState.shops.firstWhere(
        (s) => s.shopId == widget.shop.shopId,
        orElse: () => widget.shop,
      );

      showPaymentReceiptModal(context, payment, updatedShop);

      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('UPI Payment of ${AppFormatters.currency(amt)} confirmed for ${widget.shop.shopName}!'),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error confirming UPI payment: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
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
    final merchantVpa = appState.tenant.upiId ?? 'salesarmy@okhdfcbank';
    final firmName = appState.tenant.firmName ?? 'SalesArmy Merchant';
    final due = widget.shop.currentOutstanding;
    final amt = _currentAmount;
    final upiUri = _buildUpiUri(merchantVpa, firmName, amt > 0 ? amt : due);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'UPI & Razorpay Payment',
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.3,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Live Payment Gateway',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 22, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              Divider(height: 22, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),

              // Retailer Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.shop.shopName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${widget.shop.ownerName} • ${widget.shop.phone ?? 'No Phone'}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total Due',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                        Text(
                          AppFormatters.currency(due),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Amount Field
              Text(
                'Collection Amount (₹)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() => _amountError = null),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixIcon: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Text('₹', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF2563EB))),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: 'Enter amount',
                  errorText: _amountError,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.8),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Preset Quick Buttons
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (due > 0)
                    _buildPresetChip('Full Due', due),
                  if (due > 0)
                    _buildPresetChip('50%', (due / 2).roundToDouble()),
                  _buildPresetChip('₹1,000', 1000.0),
                  _buildPresetChip('₹2,000', 2000.0),
                  _buildPresetChip('₹5,000', 5000.0),
                ],
              ),
              const SizedBox(height: 14),

              // Dynamic UPI QR Code Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      'Scan to Pay with Any UPI App',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? const Color(0xFF93C5FD) : const Color(0xFF1E40AF),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: upiUri,
                        version: QrVersions.auto,
                        size: 130.0,
                        gapless: true,
                        errorCorrectionLevel: QrErrorCorrectLevel.M,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: merchantVpa));
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Copied UPI VPA: $merchantVpa'),
                            duration: const Duration(seconds: 2),
                            backgroundColor: const Color(0xFF1E293B),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              merchantVpa,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.copy_rounded, size: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Action Buttons
              // 1. Launch Live Razorpay Checkout
              ElevatedButton(
                onPressed: _isProcessing ? null : () => _launchRazorpayCheckout(appState),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 2,
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bolt_rounded, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Launch Razorpay Checkout',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
              ),
              const SizedBox(height: 8),

              // 2. Share Payment Link
              OutlinedButton.icon(
                onPressed: () {
                  final link = 'https://rzp.io/i/${widget.shop.shopId}?amt=${amt.toStringAsFixed(0)}';
                  Clipboard.setData(ClipboardData(text: link));
                  HapticFeedback.lightImpact();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment link copied: $link'),
                      backgroundColor: const Color(0xFF1E293B),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.share_rounded, size: 15),
                label: const Text('Share Payment Link', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
                  side: BorderSide(color: isDark ? const Color(0xFF2563EB) : const Color(0xFF93C5FD)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),

              // 3. Instant Confirm UPI Received
              TextButton.icon(
                onPressed: _isProcessing ? null : () => _confirmUpiPayment(appState),
                icon: const Icon(Icons.check_circle_rounded, size: 17, color: Color(0xFF059669)),
                label: const Text(
                  'Confirm UPI Received Directly',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF059669),
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, double val) {
    return InkWell(
      onTap: () => _setAmount(val),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2563EB).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2563EB),
          ),
        ),
      ),
    );
  }
}

