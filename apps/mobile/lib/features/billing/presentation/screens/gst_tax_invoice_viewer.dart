import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/printer_service.dart';
import 'package:salesarmy/features/settings/presentation/screens/printer_settings_screen.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:salesarmy/core/utils/app_image_helper.dart';

class GstTaxInvoiceViewer extends StatelessWidget {
  final InvoiceModel invoice;

  const GstTaxInvoiceViewer({super.key, required this.invoice});

  static Future<void> show(BuildContext context, InvoiceModel invoice) {
    return showDialog(
      context: context,
      builder: (_) => GstTaxInvoiceViewer(invoice: invoice),
    );
  }

  void _confirmDeleteInvoice(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          scrollable: true,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Delete Bill?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A))),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete Invoice ${invoice.invoiceNumber}?',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 8),
              Text(
                'This will reverse ₹${invoice.grandTotal.toStringAsFixed(1)} from the shop ledger balance and restore ${invoice.items.length} item(s) back into inventory.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                final appState = Provider.of<AppState>(context, listen: false);
                await appState.deleteInvoice(invoice.invoiceId);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bill ${invoice.invoiceNumber} deleted and stock restored.'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                }
              },
              child: const Text('Delete Bill', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _showEditInvoiceDialog(BuildContext context) {
    String currentStatus = invoice.paymentStatus;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              scrollable: true,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Edit Bill Payment Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Invoice: ${invoice.invoiceNumber}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF64748B))),
                  const SizedBox(height: 12),
                  const Text('Payment Status:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: currentStatus.toLowerCase(),
                    decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    items: const [
                      DropdownMenuItem(value: 'paid', child: Text('PAID (Settled)')),
                      DropdownMenuItem(value: 'partial', child: Text('PARTIAL (Partially Paid)')),
                      DropdownMenuItem(value: 'unpaid', child: Text('UNPAID (Pending Due)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setDlgState(() => currentStatus = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final appState = Provider.of<AppState>(context, listen: false);
                    final updated = invoice.copyWith(
                      paymentStatus: currentStatus,
                      paidAmount: currentStatus == 'paid' ? invoice.grandTotal : (currentStatus == 'unpaid' ? 0.0 : invoice.paidAmount),
                      dueAmount: currentStatus == 'paid' ? 0.0 : (currentStatus == 'unpaid' ? invoice.grandTotal : invoice.dueAmount),
                      updatedAt: DateTime.now(),
                    );
                    await appState.updateInvoice(updated);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Invoice ${invoice.invoiceNumber} updated to ${currentStatus.toUpperCase()}!'),
                          backgroundColor: const Color(0xFF059669),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E56E2),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showThermalPrintPreview(BuildContext context) {
    final printerService = PrinterService.instance;
    final settings = printerService.settings;
    final receiptText = printerService.formatInvoiceReceipt(invoice);
    final isConnected = settings.isEnabled && settings.isConnected;

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420, maxHeight: 680),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                // Modal Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF60A5FA), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thermal Slip (${settings.paperSize.toUpperCase()})',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
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
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Color(0xFF94A3B8), size: 20),
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
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Simulated Thermal Paper Scroll
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: SingleChildScrollView(
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

                // Action Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
                          foregroundColor: const Color(0xFF94A3B8),
                          side: const BorderSide(color: Color(0xFF334155)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Configure', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await printerService.printInvoice(invoice, context: context);
                          },
                          icon: const Icon(Icons.print_rounded, size: 18),
                          label: Text(
                            'Print Slip (${settings.copiesCount} Copy)',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final buyerName = invoice.buyer['shopName'] ?? 'Shree Ganesh Kirana & General Store';
    final buyerGstin = invoice.buyer['gstin'] ?? 'Unregistered / B2C';
    final buyerAddress = invoice.buyer['address'] ?? 'Shop #4, Market Road, Near City Post Office';
    final buyerPhone = invoice.buyer['phone'] ?? '+91 98234 11223';

    final sellerFirm = invoice.seller['firmName'] ?? 'SalesArmy SaaS HQ';
    final sellerGstin = invoice.seller['gstin'] ?? '27ABCDE1234F1Z5';
    final sellerState = invoice.seller['state'] ?? '27 (Maharashtra)';
    final sellerAddress = invoice.seller['address'] ?? 'Plot 42, APMC Market Yard, Pune, Maharashtra - 411037';
    final sellerContact = 'Phone: ${invoice.seller['phone'] ?? "+91 98220 11223"} | Email: ${invoice.seller['email'] ?? "admin@salesarmy.app"}';

    AppState? appState;
    try {
      appState = Provider.of<AppState>(context, listen: true);
    } catch (_) {
      appState = null;
    }
    final tenant = appState?.tenant;
    final gw = tenant?.paymentGatewayConfig ?? {};
    final qrSource = gw['qrSource'] as String? ?? 'dynamic';
    final staticQrImage = gw['staticQrImage'] as String?;
    final vpa = tenant?.effectiveUpiId ?? '';
    final isStaticMode = (qrSource == 'static' || qrSource == 'standee');
    final hasStaticImage = isStaticMode && staticQrImage != null && staticQrImage.isNotEmpty;
    final hasDynamicUpi = !isStaticMode && vpa.isNotEmpty;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 460, maxHeight: 720),
        child: Column(
          children: [
            // Modal Header matching Screenshot 1
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF1D4ED8), size: 24),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'GST Tax Invoice',
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _showEditInvoiceDialog(context),
                    icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E56E2), size: 21),
                    tooltip: 'Edit Bill',
                    splashRadius: 20,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => _confirmDeleteInvoice(context),
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFDC2626), size: 21),
                    tooltip: 'Delete Bill',
                    splashRadius: 20,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF334155), size: 22),
                    splashRadius: 20,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),

            // Scrollable Receipt Body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header: TAX INVOICE
                      Center(
                        child: Text(
                          invoice.invoiceType == 'GST' ? 'TAX INVOICE' : 'BILL OF SUPPLY',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.0,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Center(
                        child: Text(
                          invoice.invoiceType == 'GST'
                              ? '(Under Section 31 of CGST Act, 2017)'
                              : '(Commercial Estimate / Bill of Supply)',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(height: 1.5, color: const Color(0xFF0F172A)),
                      const SizedBox(height: 10),

                      // Seller Section
                      Text(
                        sellerFirm,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'GSTIN: $sellerGstin | State: $sellerState',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sellerAddress,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        sellerContact,
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 10),

                      // Invoice Details & Bill To (Buyer) Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Invoice Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Invoice Details:',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'No: ${invoice.invoiceNumber}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Date: ${AppFormatters.date(invoice.invoiceDate)}, ${invoice.invoiceDate.hour > 12 ? (invoice.invoiceDate.hour - 12).toString().padLeft(2, '0') : (invoice.invoiceDate.hour == 0 ? 12 : invoice.invoiceDate.hour).toString().padLeft(2, '0')}:${invoice.invoiceDate.minute.toString().padLeft(2, '0')} ${invoice.invoiceDate.hour >= 12 ? 'pm' : 'am'}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Place of Supply: ${invoice.placeOfSupply.isNotEmpty ? invoice.placeOfSupply : "Maharashtra (27)"}',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Right Column: Bill To (Buyer)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  'Bill To (Buyer):',
                                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  buyerName,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  buyerGstin,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  buyerAddress,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Phone: $buyerPhone',
                                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // 7-Column Invoice Table with Horizontal Scroll & FittedBox Protection
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 480),
                          child: SizedBox(
                            width: 480,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Item Table Header Container matching Screenshot 1 & 2
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          '# Item Description',
                                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'HSN',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Qty',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Rate',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'Taxable',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Text(
                                            'GST%',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerRight,
                                          child: Text(
                                            'Total',
                                            textAlign: TextAlign.end,
                                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF1E3A8A)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),

                                // Item Rows matching Screenshot 2
                                ...invoice.items.asMap().entries.map((entry) {
                                  final idx = entry.key + 1;
                                  final item = entry.value;
                                  final shortName = item.productName.length > 20
                                      ? '${item.productName.substring(0, 18)}...'
                                      : item.productName;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 4,
                                          child: Text(
                                            '$idx. $shortName',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              item.hsnSacCode ?? '-',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${item.quantity}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${item.rate.toInt()}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '₹${item.taxableAmount.toInt()}',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF334155)),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 1,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              '${item.gstRate.toInt()}%',
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          flex: 2,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerRight,
                                            child: Text(
                                              '₹${item.total.toStringAsFixed(1)}',
                                              textAlign: TextAlign.end,
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Totals Card with border matching Screenshot 2
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Taxable Subtotal of Goods:',
                                    style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                  ),
                                ),
                                Text(
                                  '₹${invoice.taxableSubtotal.toStringAsFixed(2)}',
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                ),
                              ],
                            ),
                            if (invoice.igst > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Integrated GST (IGST):',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  Text(
                                    '₹${invoice.igst.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                                  ),
                                ],
                              ),
                            ] else if (invoice.cgst > 0 || invoice.sgst > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Central GST (CGST):',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  Text(
                                    '₹${invoice.cgst.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'State GST (SGST):',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF334155)),
                                    ),
                                  ),
                                  Text(
                                    '₹${invoice.sgst.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: const [
                                  Expanded(
                                    child: Text(
                                      'Tax Component:',
                                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                  Text(
                                    '₹0.00 (Exempt / Non-GST)',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ],
                            const Divider(height: 14, color: Color(0xFFE2E8F0)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'GRAND TOTAL (₹):',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                Text(
                                  '₹${invoice.grandTotal.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Payment Mode, Paid, Due Status
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Payment: ${invoice.paymentStatus.toUpperCase()}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                          Text(
                            'Status: ${invoice.paymentStatus.toLowerCase() == "paid" ? "Paid in Full" : (invoice.paymentStatus.toLowerCase() == "partial" ? "Partial" : "Credit Due")}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: invoice.paymentStatus.toLowerCase() == "paid" ? const Color(0xFF059669) : const Color(0xFFDC2626),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Paid: ₹${invoice.paidAmount.toInt()}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                            ),
                          ),
                          Text(
                            'Due Balance: ₹${invoice.dueAmount.toInt()}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // UPI Bill QR Block (Dynamic QR with Bill Amount or Static Standee)
                      if (hasDynamicUpi || hasStaticImage) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: Center(
                                  child: hasStaticImage
                                      ? AppImageHelper.buildImage(
                                          staticQrImage,
                                          width: 64,
                                          height: 64,
                                          fit: BoxFit.contain,
                                        )
                                      : QrImageView(
                                          data: 'upi://pay?pa=$vpa&pn=${Uri.encodeComponent(sellerFirm)}&am=${invoice.grandTotal.toStringAsFixed(2)}&cu=INR',
                                          version: QrVersions.auto,
                                          size: 64.0,
                                          gapless: true,
                                          errorCorrectionLevel: QrErrorCorrectLevel.M,
                                          backgroundColor: Colors.white,
                                          padding: const EdgeInsets.all(2),
                                        ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      hasStaticImage ? 'Scan Standee QR to Pay' : 'Scan to Pay: ₹${invoice.grandTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      hasStaticImage ? 'Static Standee QR Active' : 'UPI ID: $vpa',
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontFamily: 'monospace'),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'GPay • PhonePe • Paytm • BHIM',
                                      style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Terms & Conditions and Signatory matching Screenshot 3
                      const Text(
                        'Terms & Conditions:',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Expanded(
                            child: Text(
                              '1. Goods once sold will only be replaced for manufacturing defects.\n'
                              '2. Interest @18% p.a. will be charged on overdue payments.\n'
                              '3. Subject to local jurisdiction.',
                              style: TextStyle(fontSize: 9.5, color: Color(0xFF64748B), height: 1.3),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'For $sellerFirm',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'Authorized Signatory',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
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

            // Fixed Footer Action Buttons matching Screenshot 1, 2, 3
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1.2)),
              ),
              child: Row(
                children: [
                  // Copy button
                  InkWell(
                    onTap: () async {
                      final invoiceText = 'Invoice #${invoice.invoiceNumber}\n'
                          'Customer: ${invoice.shopName}\n'
                          'Date: ${Formatters.date(invoice.invoiceDate)}\n'
                          'Total: ₹${Formatters.currency(invoice.grandTotal)}\n'
                          'Paid: ₹${Formatters.currency(invoice.paidAmount)}\n'
                          'Due: ₹${Formatters.currency(invoice.dueAmount)}';
                      await Clipboard.setData(ClipboardData(text: invoiceText));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invoice details copied to clipboard!')),
                        );
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy_outlined, size: 16, color: Color(0xFF1D4ED8)),
                          SizedBox(width: 4),
                          Text(
                            'Copy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // WhatsApp Bill (Green Button)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Sending GST Tax Invoice ${invoice.invoiceNumber} to $buyerPhone...')),
                        );
                      },
                      icon: const Icon(Icons.near_me_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'WhatsApp\nBill',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Thermal Slip (Blue Button)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showThermalPrintPreview(context),
                      icon: const Icon(Icons.print_rounded, size: 16, color: Colors.white),
                      label: const Text(
                        'Thermal\nSlip',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white, height: 1.1),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
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
}
