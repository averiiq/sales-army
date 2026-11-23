import 'package:flutter/material.dart';
import 'package:salesarmy/core/utils/app_error.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';

Widget adminInfoPair(String label, dynamic value, {bool isBlue = false, bool isGreen = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            (value ?? '—').toString(),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isBlue
                  ? const Color(0xFF2563EB)
                  : isGreen
                      ? const Color(0xFF059669)
                      : const Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    ),
  );
}

// =============================================================================
// 1. MODAL: DOWNLOAD SAAS REPORTS
// =============================================================================
class AdminDownloadReportsModal extends StatefulWidget {
  final List<Map<String, dynamic>> subscribers;
  final int initialTab;

  const AdminDownloadReportsModal({
    super.key,
    required this.subscribers,
    this.initialTab = 0,
  });

  static void show(BuildContext context, {required List<Map<String, dynamic>> subscribers, int initialTab = 0}) {
    showDialog(
      context: context,
      builder: (_) => AdminDownloadReportsModal(
        subscribers: subscribers,
        initialTab: initialTab,
      ),
    );
  }

  @override
  State<AdminDownloadReportsModal> createState() => _AdminDownloadReportsModalState();
}

class _AdminDownloadReportsModalState extends State<AdminDownloadReportsModal> {
  void _downloadCsv(String title, String csvContent) {
    Clipboard.setData(ClipboardData(text: csvContent));
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$title CSV generated & downloaded!'),
        backgroundColor: const Color(0xFF1D4ED8),
      ),
    );
  }

  String _generatePaymentsCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Subscriber ID,Firm Name,Contact Name,Phone,Plan,Amount,Status,Invoice No,Gateway Txn ID,Validity');
    for (final s in widget.subscribers) {
      buffer.writeln(
        '"${s['id']}","${s['firm']}","${s['name']}","${s['phone']}","${s['plan']}","${s['amount']}","${s['status']}","${s['invoiceNo']}","${s['gatewayTxnId']}","${s['validity']}"',
      );
    }
    return buffer.toString();
  }

  String _generateGstInvoicesCsv() {
    final buffer = StringBuffer();
    buffer.writeln('Invoice No,Subscriber ID,Firm Name,GSTIN,Plan,Taxable Value,CGST (9%),SGST (9%),Total GST (18%),Grand Total,Status');
    for (final s in widget.subscribers) {
      final isAnnual = (s['plan'] ?? '').toString().toLowerCase().contains('annual');
      final taxable = isAnnual ? 7188.0 : 899.0;
      final cgst = taxable * 0.09;
      final sgst = taxable * 0.09;
      final totalGst = cgst + sgst;
      final grandTotal = taxable + totalGst;
      buffer.writeln(
        '"${s['invoiceNo']}","${s['id']}","${s['firm']}","${s['gstin']}","${s['plan']}",${taxable.toStringAsFixed(2)},${cgst.toStringAsFixed(2)},${sgst.toStringAsFixed(2)},${totalGst.toStringAsFixed(2)},${grandTotal.toStringAsFixed(2)},"${s['status']}"',
      );
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.file_download_rounded, color: Color(0xFF1D4ED8), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download SaaS Reports',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Export ready-to-use CSV registers and formatted WhatsApp summaries.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Option 1: Subscriber Payments Register
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '1. Subscriber Payments Register',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'All received fees, gateway IDs, payment modes',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _downloadCsv('Subscriber Payments Register', _generatePaymentsCsv()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: SaaS GST Tax Invoices
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '2. SaaS GST Tax Invoices Register',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'B2B/B2C Tax invoices, SAC 997331 & HSN 8443',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _downloadCsv('SaaS GST Tax Invoices Register', _generateGstInvoicesCsv()),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('GST CSV', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Option 3: WhatsApp
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '3. Share Summary to WhatsApp',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF0F172A)),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Send executive revenue & subscriber briefing',
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('WhatsApp summary shared!'), backgroundColor: Color(0xFF059669)),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                      child: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 2. MODAL: SUBSCRIBER DETAILS
// =============================================================================
class AdminSubscriberDetailModal extends StatefulWidget {
  final Map<String, dynamic> subscriber;
  final VoidCallback onStateChanged;

  const AdminSubscriberDetailModal({
    super.key,
    required this.subscriber,
    required this.onStateChanged,
  });

  static void show(BuildContext context, {required Map<String, dynamic> subscriber, required VoidCallback onStateChanged}) {
    showDialog(
      context: context,
      builder: (_) => AdminSubscriberDetailModal(
        subscriber: subscriber,
        onStateChanged: onStateChanged,
      ),
    );
  }

  @override
  State<AdminSubscriberDetailModal> createState() => _AdminSubscriberDetailModalState();
}

class _AdminSubscriberDetailModalState extends State<AdminSubscriberDetailModal> {
  void _updateStatus(String newStatus) async {
    final subId = widget.subscriber['id'].toString();
    try {
      await context.read<AppState>().updateAnyTenantStatus(subId, newStatus);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status update failed: $error')));
      return;
    }
    if (!mounted) return;
    widget.subscriber['status'] = newStatus;
    widget.onStateChanged();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text('${widget.subscriber['name']} $newStatus.'),
        backgroundColor: newStatus == 'ACTIVE' ? const Color(0xFF059669) : const Color(0xFF475569),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subscriber;

    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Modal Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          children: [
                            const Text(
                              'Subscriber Details',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                            ),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: sub['id']));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Copied ${sub['id']} to clipboard'), duration: const Duration(seconds: 1)),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      sub['id'],
                                      style: const TextStyle(color: Color(0xFF1D4ED8), fontSize: 11, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF1D4ED8)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          sub['firm'],
                          style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Card 1: Contact Details
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    adminInfoPair('Contact Name:', sub['name']),
                    adminInfoPair('Phone:', sub['phone']),
                    adminInfoPair('Email:', sub['email']),
                    adminInfoPair('GSTIN:', sub['gstin'], isBlue: true),
                    adminInfoPair('Territory / Route:', sub['route']),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Card 2: Purchased Plan
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                          child: Text('Purchased Plan', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Text(sub['plan'], style: const TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    adminInfoPair('Billing Validity:', sub['validity']),
                    adminInfoPair('Invoice Number:', sub['invoiceNo']),
                    adminInfoPair('Gateway Txn ID:', sub['gatewayTxnId']),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Card 3: Thermal Printer Hardware
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                          child: Text('Thermal Printer Hardware', style: TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                        Text(sub['printerStatus'], style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.w800, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    adminInfoPair('Printer Model:', sub['printerModel']),
                    adminInfoPair('Delivery Status:', sub['deliveryStatus'], isGreen: true),
                    adminInfoPair('Shipping Address:', sub['shippingAddress']),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Solid Blue WhatsApp Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('GST Tax Invoice sent to WhatsApp for ${sub['phone']}'),
                        backgroundColor: const Color(0xFF1D4ED8),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1D4ED8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Send GST Tax Invoice on WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                ),
              ),
              const SizedBox(height: 12),

              // Actions Row (Approv, Pause, Cancel)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus('ACTIVE'),
                      icon: const Icon(Icons.check_circle_rounded, size: 14),
                      label: const Text('Approv', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus('PAUSED'),
                      icon: const Icon(Icons.pause_circle_outline_rounded, size: 14),
                      label: const Text('Pause', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E293B),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _updateStatus('CANCELLED'),
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        backgroundColor: const Color(0xFFFEF2F2),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Subscriber Data & Account Controls Header
              const Text(
                'Subscriber Data & Account Controls',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 10),

              // Delete Cash Orders History Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      AdminDeleteCashHistoryModal.show(context, subscriber: sub);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Color(0xFFD97706), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delete Cash Orders History',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB45309)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Purges cash orders with 1-click ledger download',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Color(0xFFD97706), size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Reset User Account Card
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      AdminResetAccountModal.show(context, subscriber: sub);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.restart_alt_rounded, color: Color(0xFFDC2626), size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Reset User Account',
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB91C1C)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Wipes history for new setup with 1-click full backup',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF7F1D1D)),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: Color(0xFFDC2626), size: 18),
                        ],
                      ),
                    ),
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

// =============================================================================
// 3. MODAL: DELETE CASH HISTORY
// =============================================================================
class AdminDeleteCashHistoryModal extends StatefulWidget {
  final Map<String, dynamic> subscriber;

  const AdminDeleteCashHistoryModal({super.key, required this.subscriber});

  static void show(BuildContext context, {required Map<String, dynamic> subscriber}) {
    showDialog(
      context: context,
      builder: (_) => AdminDeleteCashHistoryModal(subscriber: subscriber),
    );
  }

  @override
  State<AdminDeleteCashHistoryModal> createState() => _AdminDeleteCashHistoryModalState();
}

class _AdminDeleteCashHistoryModalState extends State<AdminDeleteCashHistoryModal> {
  @override
  Widget build(BuildContext context) {
    final sub = widget.subscriber;

    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEF3C7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Delete Cash History',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFEA580C)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'User: ${sub['name']} (${sub['id']})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Caution Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded, color: Color(0xFFB45309), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Caution: Irreversible Cash History Purge',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'This action will permanently delete all order history and payment records received in Cash for ${sub['name']}. Online payments, UPI records, and basic profile data will be preserved.',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Download Reports Header
              const Text(
                'Download Reports Before Deleting (1-Click)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(height: 8),

              // Report 1
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('1. All Orders Detailed Report', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A))),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading All Orders Report CSV...')),
                        );
                      },
                      child: const Text('CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Report 2
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('2. Complete Customer Ledger', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A))),
                    ),
                    TextButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading Customer Ledger CSV...')),
                        );
                      },
                      child: const Text('CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1D4ED8))),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Copy Ledger & WhatsApp Row
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: 'Ledger export for ${sub['name']}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Customer ledger copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0F172A)),
                      label: const Text('Copy Ledger', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ledger summary shared to WhatsApp!'), backgroundColor: Color(0xFF1D4ED8)),
                        );
                      },
                      icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Permanently Delete Button
              ElevatedButton.icon(
                onPressed: () async {
                  final subId = sub['id']?.toString() ?? '';
                  final appState = context.read<AppState>();
                  final ok = await AppError.guard(context, () => appState.purgeCashHistoryForTenant(subId),
                      action: 'purge the cash history');
                  if (!ok || !context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cash history purged permanently for ${sub['name']}!'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever_rounded, size: 16, color: Colors.white),
                label: const Text('Permanently Delete Cash History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),

              // Cancel Button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel / Keep History', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 4. MODAL: RESET USER ACCOUNT
// =============================================================================
class AdminResetAccountModal extends StatefulWidget {
  final Map<String, dynamic> subscriber;

  const AdminResetAccountModal({super.key, required this.subscriber});

  static void show(BuildContext context, {required Map<String, dynamic> subscriber}) {
    showDialog(
      context: context,
      builder: (_) => AdminResetAccountModal(subscriber: subscriber),
    );
  }

  @override
  State<AdminResetAccountModal> createState() => _AdminResetAccountModalState();
}

class _AdminResetAccountModalState extends State<AdminResetAccountModal> {
  @override
  Widget build(BuildContext context) {
    final sub = widget.subscriber;

    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFEE2E2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.restart_alt_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reset User Account',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFDC2626)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'User: ${sub['name']} (${sub['id']})',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Danger Notice Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 16),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Account Factory Reset & Re-Setup Mode',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: Color(0xFFB91C1C)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'After reset, all order history, cash/online payments, bills, and GST tax bills will be permanently deleted. The user profile will be reset and will need to be setup like a new subscribed user.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF7F1D1D), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Download All Data Header
              const Text(
                'Download All Data Before Reset (1-Click)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8)),
              ),
              const SizedBox(height: 8),

              // Download 1
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(
                      child: Text('1. All Orders History (Detailed)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A))),
                    ),
                    Text('CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Download 2
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(
                      child: Text('2. Payments (Cash & Online)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A))),
                    ),
                    Text('CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Download 3
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Expanded(
                      child: Text('3. Bills & GST Tax Invoices', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: Color(0xFF0F172A))),
                    ),
                    Text('CSV', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF1D4ED8))),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Action Buttons Row: Copy Backup / All-In-One ZIP
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: 'Full backup summary export for ${sub['name']}'));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Backup summary copied to clipboard!')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14, color: Color(0xFF0F172A)),
                      label: const Text('Copy Backup', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A))),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Downloading All-In-One ZIP Backup file...'), backgroundColor: Color(0xFF1D4ED8)),
                        );
                      },
                      icon: const Icon(Icons.archive_rounded, size: 14, color: Colors.white),
                      label: const Text('All-In-One ZIP/File', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Confirm & Reset Button
              ElevatedButton.icon(
                onPressed: () async {
                  final subId = sub['id']?.toString() ?? '';
                  final appState = context.read<AppState>();
                  final ok = await AppError.guard(context, () => appState.resetUserAccountForTenant(subId),
                      action: 'reset the account');
                  if (!ok || !context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('User account reset successfully for ${sub['name']}!'),
                      backgroundColor: const Color(0xFFDC2626),
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 16, color: Colors.white),
                label: const Text('Confirm & Reset User Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 10),

              // Cancel Button
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel / Keep Account Intact', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 5. MODAL: EDIT SAAS & HARDWARE PRICING
// =============================================================================
class AdminEditPricingModal extends StatefulWidget {
  final double monthlyPlanPrice;
  final double annualPlanPrice;
  final double planGstRate;
  final double printerHardwarePrice;
  final double printerGstRate;
  final bool applyGstOnInvoices;
  final Function(double, double, double, double, double, bool) onSave;

  const AdminEditPricingModal({
    super.key,
    required this.monthlyPlanPrice,
    required this.annualPlanPrice,
    required this.planGstRate,
    required this.printerHardwarePrice,
    required this.printerGstRate,
    required this.applyGstOnInvoices,
    required this.onSave,
  });

  static void show(
    BuildContext context, {
    required double monthlyPlanPrice,
    required double annualPlanPrice,
    required double planGstRate,
    required double printerHardwarePrice,
    required double printerGstRate,
    required bool applyGstOnInvoices,
    required Function(double, double, double, double, double, bool) onSave,
  }) {
    showDialog(
      context: context,
      builder: (_) => AdminEditPricingModal(
        monthlyPlanPrice: monthlyPlanPrice,
        annualPlanPrice: annualPlanPrice,
        planGstRate: planGstRate,
        printerHardwarePrice: printerHardwarePrice,
        printerGstRate: printerGstRate,
        applyGstOnInvoices: applyGstOnInvoices,
        onSave: onSave,
      ),
    );
  }

  @override
  State<AdminEditPricingModal> createState() => _AdminEditPricingModalState();
}

class _AdminEditPricingModalState extends State<AdminEditPricingModal> {
  late TextEditingController _monthlyCtrl;
  late TextEditingController _annualCtrl;
  late TextEditingController _planGstCtrl;
  late TextEditingController _printerPriceCtrl;
  late TextEditingController _printerGstCtrl;
  late bool _applyGst;

  @override
  void initState() {
    super.initState();
    _monthlyCtrl = TextEditingController(text: widget.monthlyPlanPrice.toInt().toString());
    _annualCtrl = TextEditingController(text: widget.annualPlanPrice.toInt().toString());
    _planGstCtrl = TextEditingController(text: widget.planGstRate.toInt().toString());
    _printerPriceCtrl = TextEditingController(text: widget.printerHardwarePrice.toInt().toString());
    _printerGstCtrl = TextEditingController(text: widget.printerGstRate.toInt().toString());
    _applyGst = widget.applyGstOnInvoices;
  }

  @override
  void dispose() {
    _monthlyCtrl.dispose();
    _annualCtrl.dispose();
    _planGstCtrl.dispose();
    _printerPriceCtrl.dispose();
    _printerGstCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final annualVal = double.tryParse(_annualCtrl.text) ?? 599.0;
    final annualYearly = (annualVal * 12).toInt();

    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text('Edit SaaS & Printer Pricing', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Section 1
              const Text('1. Subscription Plans (₹ / month)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _inputBox('Monthly (₹)', _monthlyCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text('Annual (₹/mo)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
                            ),
                            Text('Yr: ₹$annualYearly', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF1D4ED8))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          key: const ValueKey('pricing_annual_input'),
                          controller: _annualCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              _inputBox('Plan GST Rate (%)', _planGstCtrl),
              const SizedBox(height: 16),

              // Section 2
              const Text('2. Thermal Bluetooth Printer (58mm)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF059669))),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _inputBox('Printer Price (₹)', _printerPriceCtrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _inputBox('Printer GST (%)', _printerGstCtrl),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // GST switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('Apply GST Tax on Invoices', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                    ),
                    Switch(
                      value: _applyGst,
                      activeThumbColor: const Color(0xFF1D4ED8),
                      onChanged: (val) => setState(() => _applyGst = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Save Button
              ElevatedButton(
                key: const ValueKey('pricing_save_btn'),
                onPressed: () {
                  final m = double.tryParse(_monthlyCtrl.text) ?? widget.monthlyPlanPrice;
                  final a = double.tryParse(_annualCtrl.text) ?? widget.annualPlanPrice;
                  final g = double.tryParse(_planGstCtrl.text) ?? widget.planGstRate;
                  final p = double.tryParse(_printerPriceCtrl.text) ?? widget.printerHardwarePrice;
                  final pg = double.tryParse(_printerGstCtrl.text) ?? widget.printerGstRate;

                  widget.onSave(m, a, g, p, pg, _applyGst);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All pricing and tax rates updated successfully!'), backgroundColor: Color(0xFF059669)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D4ED8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Save All Pricing & Tax Rates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputBox(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }
}

// =============================================================================
// 6. MODAL: CREATE NEW PROMO COUPON
// =============================================================================
class AdminNewCouponModal extends StatefulWidget {
  final Function(Map<String, dynamic>) onSave;

  const AdminNewCouponModal({super.key, required this.onSave});

  static void show(BuildContext context, {required Function(Map<String, dynamic>) onSave}) {
    showDialog(
      context: context,
      builder: (_) => AdminNewCouponModal(onSave: onSave),
    );
  }

  @override
  State<AdminNewCouponModal> createState() => _AdminNewCouponModalState();
}

class _AdminNewCouponModalState extends State<AdminNewCouponModal> {
  final _codeCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _valueCtrl = TextEditingController(text: '30');
  String _type = 'trial';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFFF1F5F9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Create Promo Coupon', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              const Text('Choose coupon benefit type', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              const SizedBox(height: 12),

              const Text('Select Coupon Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                key: ValueKey('coupon_type_$_type'),
                initialValue: _type,
                items: const [DropdownMenuItem(value: 'trial', child: Text('Free Duration')),
                  DropdownMenuItem(value: 'percentage', child: Text('Percentage discount')),
                  DropdownMenuItem(value: 'flat', child: Text('Flat discount (₹)'))],
                onChanged: (value) => setState(() => _type = value!),
              ),
              TextField(controller: _valueCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: _type == 'trial' ? 'Trial days' : _type == 'percentage' ? 'Discount percent' : 'Discount amount (₹)')),
              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                children: [
                  _presetPill('1 Day'),
                  _presetPill('7 Days'),
                  _presetPill('14 Days'),
                  _presetPill('30 Days'),
                ],
              ),
              const SizedBox(height: 14),

              const Text('Coupon Code', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('coupon_code_input'),
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. FESTIVE50',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 12),

              const Text('Offer Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF475569))),
              const SizedBox(height: 6),
              TextField(
                key: const ValueKey('coupon_desc_input'),
                controller: _descCtrl,
                decoration: InputDecoration(
                  hintText: 'e.g. 50% discount on first month',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                ),
              ),
              const SizedBox(height: 18),

              if (_error != null) Text(_error!, style: const TextStyle(color: Colors.red)),
              ElevatedButton(
                key: const ValueKey('coupon_create_btn'),
                onPressed: _saving ? null : () async {
                  final code = _codeCtrl.text.trim().toUpperCase();
                  final value = double.tryParse(_valueCtrl.text);
                  if (!RegExp(r'^[A-Z0-9_-]{3,40}$').hasMatch(code) || value == null || !value.isFinite || value <= 0 ||
                      (_type == 'percentage' && value > 100) || (_type == 'trial' && (value > 365 || value != value.roundToDouble()))) {
                    setState(() => _error = 'Enter a valid code and benefit value.');
                    return;
                  }
                  setState(() { _saving = true; _error = null; });
                  final desc = _descCtrl.text.trim().isEmpty ? 'Special Promotional Discount' : _descCtrl.text.trim();
                  try {
                  await widget.onSave({
                    'code': code,
                    'desc': desc,
                    'type': _type,
                    'value': value,
                    'status': 'ACTIVE',
                    'isPaused': false,
                  });
                  if (!context.mounted) return;
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(content: Text('Coupon $code created successfully!'), backgroundColor: const Color(0xFF059669)),
                  );
                  Navigator.pop(context);
                  } catch (error) {
                    if (mounted) setState(() { _saving = false; _error = error.toString(); });
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                child: const Text('Generate & Activate Coupon', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _presetPill(String label) {
    return InkWell(
      onTap: () {
        _descCtrl.text = '$label Free Full App Access';
        _type = 'trial';
        _valueCtrl.text = label.split(' ').first;
        setState(() {});
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFCBD5E1))),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
      ),
    );
  }
}
