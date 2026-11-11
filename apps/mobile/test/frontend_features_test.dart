import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/billing/data/services/gst_engine.dart';
import 'package:salesarmy/core/utils/formatters.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';

void main() {
  group('SalesArmy GST Engine Tests', () {
    test('Intra-state GST calculation (CGST + SGST split)', () {
      final gst = GstEngine.calculateGst(
        taxableAmount: 1000.0,
        gstRate: 18.0,
        sellerState: 'Maharashtra',
        buyerState: 'Maharashtra',
      );

      expect(gst['taxableAmount'], 1000.0);
      expect(gst['totalGst'], 180.0);
      expect(gst['cgst'], 90.0);
      expect(gst['sgst'], 90.0);
      expect(gst['igst'], 0.0);
      expect(gst['grandTotal'], 1180.0);
    });

    test('Inter-state GST calculation (IGST only)', () {
      final gst = GstEngine.calculateGst(
        taxableAmount: 2000.0,
        gstRate: 12.0,
        sellerState: 'Maharashtra',
        buyerState: 'Gujarat',
      );

      expect(gst['taxableAmount'], 2000.0);
      expect(gst['totalGst'], 240.0);
      expect(gst['cgst'], 0.0);
      expect(gst['sgst'], 0.0);
      expect(gst['igst'], 240.0);
      expect(gst['grandTotal'], 2240.0);
    });
  });

  group('SalesArmy AppFormatters Tests', () {
    test('Indian currency formatting with comma separation', () {
      expect(AppFormatters.currency(14250.0), '₹14,250');
      expect(AppFormatters.currency(14250.0, trimZeroDecimals: false), '₹14,250.00');
      expect(AppFormatters.currency(1250000.5), '₹12,50,000.50');
      expect(AppFormatters.compactCurrency(150000.0), '₹1.5L');
      expect(AppFormatters.compactCurrency(2500.0), '₹2.5K');
    });

    test('Number to words converter for compliant GST invoices', () {
      final words = AppFormatters.numberToWords(4514.0);
      expect(words, contains('Four Thousand Five Hundred Fourteen Rupees Only'));
    });
  });

  group('SalesArmy AppState Business Logic Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('Registering new shop increases count and updates state', () async {
      final initialCount = appState.shops.length;
      final newShop = ShopModel(
        shopId: 'shop_test_99',
        shopName: 'Test Retail Mart',
        ownerName: 'Test Owner',
        visitFrequency: 'weekly',
        currentOutstanding: 5000.0,
      );

      await appState.addShop(newShop);
      expect(appState.shops.length, initialCount + 1);
      expect(appState.shops.first.shopName, 'Test Retail Mart');
    });

    test('Adding product updates product catalog and low stock count', () async {
      final initialProdCount = appState.products.length;
      final newProd = ProductModel(
        productId: 'prod_test_01',
        name: 'Test Wafer Biscuits',
        basePrice: 50.0,
        gstRate: 18.0,
        stockQuantity: 4, // Below alert qty 10
        lowStockAlertQty: 10,
      );

      await appState.addProduct(newProd);
      expect(appState.products.length, initialProdCount + 1);
      expect(appState.lowStockCount, greaterThanOrEqualTo(1));
    });

    test('Recording payment reduces shop outstanding and creates ledger entry', () async {
      final targetShop = appState.shops.first;
      final initialDue = targetShop.currentOutstanding;
      final initialLedgerCount = appState.ledgerEntries.length;

      final payment = PaymentModel(
        paymentId: 'pay_test_01',
        shopId: targetShop.shopId,
        createdByUid: 'demo_user',
        amount: 2000.0,
        paymentMode: 'UPI',
        date: DateTime.now(),
      );

      await appState.recordPayment(payment);

      final updatedShop = appState.shops.firstWhere((s) => s.shopId == targetShop.shopId);
      expect(updatedShop.currentOutstanding, (initialDue - 2000.0).clamp(0.0, double.infinity));
      expect(appState.ledgerEntries.length, initialLedgerCount + 1);
      expect(appState.ledgerEntries.first.type, 'PAYMENT');
      expect(appState.ledgerEntries.first.amount, -2000.0);
    });
  });
}
