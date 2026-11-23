// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/collections/data/models/ledger_entry_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';

/// Helper utility to generate comprehensive, RFC-4180 compliant CSV files
/// for Ledger, Orders, Inventory, and Sales reports with full line-by-line depth.
class CsvReportHelper {
  /// Escapes CSV cells to properly handle commas, quotes, and newlines.
  static String _escape(dynamic val) {
    if (val == null) return '""';
    final s = val.toString()
        .replaceAll('"', '""')
        .replaceAll('\r\n', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ');
    return '"$s"';
  }

  static String _formatTime(DateTime? dt) {
    if (dt == null) return '00:00';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  /// Saves the CSV file to the device's public Downloads directory,
  /// with automatic fallbacks to Documents and external storage.
  static Future<File?> saveCsvFile({
    required String fileName,
    required String csvContent,
  }) async {
    final sanitizedFileName = fileName.endsWith('.csv') ? fileName : '$fileName.csv';
    Directory? targetDir;

    // 1. On Android, check the primary public Download directory (/storage/emulated/0/Download)
    if (Platform.isAndroid) {
      try {
        final publicDownload = Directory('/storage/emulated/0/Download');
        if (await publicDownload.exists()) {
          targetDir = publicDownload;
        } else {
          final altDownload = Directory('/storage/emulated/0/Downloads');
          if (await altDownload.exists()) {
            targetDir = altDownload;
          }
        }
      } catch (e) {
        debugPrint('[CsvReportHelper] Android public Download access: $e');
      }
    }

    // 2. Try getDownloadsDirectory() (Desktop, macOS, Windows, Android supported)
    if (targetDir == null) {
      try {
        targetDir = await getDownloadsDirectory();
      } catch (_) {}
    }

    // 3. Fallback to Android external storage directory
    if (targetDir == null && Platform.isAndroid) {
      try {
        targetDir = await getExternalStorageDirectory();
      } catch (_) {}
    }

    // 4. Fallback to Documents directory
    if (targetDir == null) {
      try {
        targetDir = await getApplicationDocumentsDirectory();
      } catch (_) {}
    }

    // 5. Ultimate fallback to Temporary directory
    targetDir ??= await getTemporaryDirectory();

    try {
      final file = File('${targetDir.path}/$sanitizedFileName');
      // Prepend UTF-8 BOM for Excel compatibility
      final contentWithBom = '\uFEFF$csvContent';
      await file.writeAsString(contentWithBom, flush: true);
      return file;
    } catch (e) {
      debugPrint('[CsvReportHelper] Failed writing to ${targetDir.path}: $e');
      try {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final file = File('${fallbackDir.path}/$sanitizedFileName');
        final contentWithBom = '\uFEFF$csvContent';
        await file.writeAsString(contentWithBom, flush: true);
        return file;
      } catch (_) {
        final temp = await getTemporaryDirectory();
        final file = File('${temp.path}/$sanitizedFileName');
        final contentWithBom = '\uFEFF$csvContent';
        await file.writeAsString(contentWithBom, flush: true);
        return file;
      }
    }
  }

  /// Exports generated CSV by writing to a physical file and presenting the native share sheet.
  static Future<void> downloadOrCopyCsv(
    BuildContext context, {
    required String reportTitle,
    required String fileName,
    required String csvContent,
    required int totalRows,
  }) async {
    HapticFeedback.mediumImpact();

    final exportedFile = await saveCsvFile(
      fileName: fileName,
      csvContent: csvContent,
    );

    if (!context.mounted) return;

    final isPublicDownload = exportedFile?.path != null && exportedFile!.path.contains('/Download');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          exportedFile != null
              ? (isPublicDownload
                  ? 'Downloaded: $fileName (Saved to Downloads)'
                  : 'Downloaded: $fileName')
              : 'CSV file generated ($totalRows rows)',
        ),
        backgroundColor: const Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.file_download_done_rounded, color: Color(0xFF059669), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$reportTitle Exported',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$fileName ($totalRows rows)',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Structured CSV Generated & Saved',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Ready to share to WhatsApp, save to device, or import directly into Excel, Google Sheets, or Tally.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.3),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  if (exportedFile != null)
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: const Text('Share File / WhatsApp'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await Share.shareXFiles(
                              [XFile(exportedFile.path, name: fileName, mimeType: 'text/csv')],
                              subject: reportTitle,
                              text: '$reportTitle export ($totalRows rows)',
                            );
                          } catch (_) {
                            await Share.share(csvContent, subject: reportTitle);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E56E2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  if (exportedFile != null) const SizedBox(width: 10),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy'),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: csvContent));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('CSV copied to clipboard!')),
                        );
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F172A),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
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
  }

  /// Real WhatsApp report export with structured text summary.
  static Future<void> shareViaWhatsApp({
    required BuildContext context,
    required String message,
  }) async {
    HapticFeedback.lightImpact();
    final encoded = Uri.encodeComponent(message);
    final waUri = Uri.parse('https://wa.me/?text=$encoded');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else {
        await Share.share(message);
      }
    } catch (_) {
      await Share.share(message);
    }
  }

  // =========================================================================
  // 1. LEDGER CSV (Deep Transaction Log)
  // =========================================================================
  static String generateLedgerCsv({
    required List<LedgerEntryModel> entries,
    required List<ShopModel> shops,
  }) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln([
      'Entry ID',
      'Date',
      'Time',
      'Shop / Party Name',
      'Shop ID',
      'Party Phone',
      'Transaction Type',
      'Debit (INR)',
      'Credit (INR)',
      'Net Amount (INR)',
      'Balance After (INR)',
      'Reference / Bill No',
      'Description / Remarks',
    ].map(_escape).join(','));

    for (final e in entries) {
      final shop = shops.firstWhere(
        (s) => s.shopId == e.shopId,
        orElse: () => ShopModel(shopId: e.shopId, shopName: 'Shop ${e.shopId}', ownerName: 'Store Manager'),
      );
      final isDebit = e.amount > 0;
      final debit = isDebit ? e.amount.toStringAsFixed(2) : '0.00';
      final credit = !isDebit ? e.amount.abs().toStringAsFixed(2) : '0.00';
      final dStr = AppFormatters.date(e.createdAt ?? e.date);
      final tStr = _formatTime(e.createdAt ?? e.date);

      buffer.writeln([
        e.ledgerId,
        dStr,
        tStr,
        shop.shopName,
        e.shopId,
        shop.phone ?? '',
        e.type,
        debit,
        credit,
        e.amount.toStringAsFixed(2),
        e.balanceAfter.toStringAsFixed(2),
        e.referenceId,
        e.description,
      ].map(_escape).join(','));
    }

    return buffer.toString();
  }

  // =========================================================================
  // 2. ORDERS CSV (Deep Line-By-Line Items Register)
  // =========================================================================
  static String generateOrdersCsv({
    required List<OrderModel> orders,
    required List<ShopModel> shops,
  }) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln([
      'Order ID',
      'Order Date',
      'Order Time',
      'Retailer Shop Name',
      'Shop ID',
      'Contact Name',
      'Phone Number',
      'Item SKU',
      'Item Description',
      'Quantity Ordered',
      'Unit Rate (INR)',
      'Taxable Value (INR)',
      'GST Slab %',
      'CGST (INR)',
      'SGST (INR)',
      'Item Total Tax (INR)',
      'Item Grand Total (INR)',
      'Order Overall Status',
      'Delivery Notes',
    ].map(_escape).join(','));

    for (final o in orders) {
      final shop = shops.firstWhere(
        (s) => s.shopId == o.shopId,
        orElse: () => ShopModel(shopId: o.shopId, shopName: 'Shop ${o.shopId}', ownerName: 'Store Manager'),
      );
      final oDate = AppFormatters.date(o.createdAt);
      final oTime = _formatTime(o.createdAt);

      if (o.items.isEmpty) {
        // Still output row for order summary
        buffer.writeln([
          o.orderId,
          oDate,
          oTime,
          shop.shopName,
          o.shopId,
          shop.ownerName,
          shop.phone ?? '',
          'N/A',
          'Empty Order Container',
          '0',
          '0.00',
          '0.00',
          '0',
          '0.00',
          '0.00',
          '0.00',
          o.grandTotal.toStringAsFixed(2),
          o.status.toUpperCase(),
          o.deliveryNote ?? '',
        ].map(_escape).join(','));
      } else {
        for (final item in o.items) {
          final gstRate = item.gstRate;
          final taxable = item.taxableAmount;
          final itemGst = item.totalGst;

          buffer.writeln([
            o.orderId,
            oDate,
            oTime,
            shop.shopName,
            o.shopId,
            shop.ownerName,
            shop.phone ?? '',
            item.productId,
            item.productName,
            item.quantity.toString(),
            item.rate.toStringAsFixed(2),
            taxable.toStringAsFixed(2),
            gstRate.toStringAsFixed(1),
            item.cgst.toStringAsFixed(2),
            item.sgst.toStringAsFixed(2),
            itemGst.toStringAsFixed(2),
            item.total.toStringAsFixed(2),
            o.status.toUpperCase(),
            o.deliveryNote ?? '',
          ].map(_escape).join(','));
        }
      }
    }

    return buffer.toString();
  }

  // =========================================================================
  // 3. INVENTORY CSV (Detailed SKU Valuation & Stock Health)
  // =========================================================================
  static String generateInventoryCsv({
    required List<ProductModel> products,
  }) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln([
      'SKU Code',
      'Product Name',
      'Pack / Variant',
      'Category',
      'HSN/SAC Code',
      'Base Purchase Rate (INR)',
      'Wholesale Rate (INR)',
      'Retail Rate (INR)',
      'Customer Rate (INR)',
      'Margin % (Wholesale)',
      'GST Tax Slab %',
      'Current In-Hand Stock',
      'Total Stock Valuation (INR)',
      'Low Stock Reorder Threshold',
      'Stock Health Status',
    ].map(_escape).join(','));

    for (final p in products) {
      final stockValuation = p.stockQuantity * p.basePrice;
      final marginPct = p.basePrice > 0
          ? (((p.wholesalePrice - p.basePrice) / p.basePrice) * 100).toStringAsFixed(1)
          : '0.0';
      final status = p.stockQuantity <= 0
          ? 'OUT OF STOCK'
          : p.stockQuantity <= p.lowStockAlertQty
              ? 'LOW STOCK ALERT'
              : 'HEALTHY IN-STOCK';

      buffer.writeln([
        p.sku,
        p.name,
        p.variant ?? p.size ?? 'Standard',
        p.categoryId ?? 'General',
        p.hsnSacCode ?? 'N/A',
        p.basePrice.toStringAsFixed(2),
        p.wholesalePrice.toStringAsFixed(2),
        p.retailPrice.toStringAsFixed(2),
        p.customerPrice.toStringAsFixed(2),
        marginPct,
        p.gstRate.toStringAsFixed(1),
        p.stockQuantity.toString(),
        stockValuation.toStringAsFixed(2),
        p.lowStockAlertQty.toString(),
        status,
      ].map(_escape).join(','));
    }

    return buffer.toString();
  }

  // =========================================================================
  // 4. SALES & GST TAX REGISTER CSV
  // =========================================================================
  static String generateSalesCsv({
    required List<InvoiceModel> invoices,
    required List<OrderModel> orders,
  }) {
    final buffer = StringBuffer();
    // Headers
    buffer.writeln([
      'Invoice Number',
      'Invoice Date',
      'Customer Trade Name',
      'Customer GSTIN',
      'Billing Address',
      'State Code',
      'Payment Status',
      'Total Line Items',
      'Subtotal / Taxable Value (INR)',
      'CGST Amount (INR)',
      'SGST Amount (INR)',
      'IGST Amount (INR)',
      'Total GST Tax (INR)',
      'Invoice Grand Total (INR)',
    ].map(_escape).join(','));

    for (final inv in invoices) {
      final buyer = inv.buyer;
      final bName = buyer['businessName'] ?? buyer['shopName'] ?? 'Counter Sale';
      final bGstin = buyer['gstin'] ?? 'URP / Consumer';
      final bAddr = buyer['address'] ?? '';
      final bState = buyer['stateCode'] ?? '27';
      final iDate = AppFormatters.date(inv.invoiceDate);

      buffer.writeln([
        inv.invoiceNumber,
        iDate,
        bName,
        bGstin,
        bAddr,
        bState,
        inv.paymentStatus.toUpperCase(),
        inv.items.length.toString(),
        inv.taxableSubtotal.toStringAsFixed(2),
        inv.cgst.toStringAsFixed(2),
        inv.sgst.toStringAsFixed(2),
        inv.igst.toStringAsFixed(2),
        inv.totalGst.toStringAsFixed(2),
        inv.grandTotal.toStringAsFixed(2),
      ].map(_escape).join(','));
    }

    return buffer.toString();
  }
}
