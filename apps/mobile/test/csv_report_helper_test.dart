import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/utils/csv_report_helper.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/collections/data/models/ledger_entry_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
  });

  group('CsvReportHelper Download & File Persistence Tests', () {
    test('saveCsvFile writes a proper physical file to disk', () async {
      const fileName = 'test_report_download.csv';
      const content = 'Header1,Header2\nValue1,Value2\n';

      final file = await CsvReportHelper.saveCsvFile(
        fileName: fileName,
        csvContent: content,
      );

      expect(file, isNotNull);
      expect(await file!.exists(), isTrue);
      expect(file.path.endsWith('.csv'), isTrue);

      final readBack = await file.readAsString();
      expect(readBack, equals(content));

      // Cleanup
      if (await file.exists()) {
        await file.delete();
      }
    });

    test('generateLedgerCsv generates valid structured CSV with proper headers', () {
      final sampleShop = ShopModel(
        shopId: 'shop_001',
        shopName: 'Sharma General Store',
        ownerName: 'Ramesh Sharma',
        phone: '9876543210',
        address: 'MG Road, Pune',
        businessType: 'Kirana',
        createdAt: DateTime.now(),
      );

      final sampleEntry = LedgerEntryModel(
        ledgerId: 'entry_001',
        shopId: 'shop_001',
        createdByUid: 'agent_1',
        type: 'INVOICE',
        referenceId: 'INV-001',
        amount: 5400.0,
        balanceAfter: 5400.0,
        description: 'Invoice #INV-2026-001',
        date: DateTime(2026, 10, 31, 10, 30),
      );

      final csv = CsvReportHelper.generateLedgerCsv(
        entries: [sampleEntry],
        shops: [sampleShop],
      );

      expect(csv, contains('Entry ID'));
      expect(csv, contains('Sharma General Store'));
      expect(csv, contains('5400'));
      expect(csv, contains('INVOICE'));
    });

    test('generateOrdersCsv generates valid structured CSV with order details', () {
      final sampleShop = ShopModel(
        shopId: 'shop_001',
        shopName: 'Apex Kirana',
        ownerName: 'Sunil',
        phone: '9876543210',
        address: 'Station Road',
        businessType: 'Retail',
        createdAt: DateTime.now(),
      );

      final sampleOrder = OrderModel(
        orderId: 'ORD-999',
        shopId: 'shop_001',
        createdByUid: 'agent_1',
        status: 'Delivered',
        createdAt: DateTime(2026, 10, 30),
        items: [],
        subtotal: 3000.0,
        totalGst: 200.0,
        grandTotal: 3200.0,
      );

      final csv = CsvReportHelper.generateOrdersCsv(
        orders: [sampleOrder],
        shops: [sampleShop],
      );

      expect(csv, contains('Order ID'));
      expect(csv, contains('ORD-999'));
      expect(csv, contains('Apex Kirana'));
      expect(csv, contains('3200'));
    });

    test('generateInventoryCsv formats product catalog stock properly', () {
      final sampleProduct = ProductModel(
        productId: 'prod_1',
        name: 'Basmati Rice 5kg',
        categoryId: 'Grains',
        wholesalePrice: 450.0,
        retailPrice: 520.0,
        gstRate: 5.0,
        stockQuantity: 40,
        sku: 'RICE-5KG',
      );

      final csv = CsvReportHelper.generateInventoryCsv(
        products: [sampleProduct],
      );

      expect(csv, contains('Product Name'));
      expect(csv, contains('Basmati Rice 5kg'));
      expect(csv, contains('450'));
      expect(csv, contains('40'));
    });
  });
}
