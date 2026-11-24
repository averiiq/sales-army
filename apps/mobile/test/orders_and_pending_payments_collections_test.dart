import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Orders and Pending Payments on Collections Page Tests', () {
    test('1. addOrder without invoice increments shop outstanding and adds ORDER ledger entry', () async {
      final appState = AppState();
      
      final testShop = ShopModel(
        shopId: 'shop_test_coll_1',
        shopName: 'Balaji Provisions',
        ownerName: 'Ramesh Balaji',
        phone: '9876543210',
        businessType: 'Kirana Store',
        currentOutstanding: 0.0,
      );
      await appState.addShop(testShop);

      final initialDue = appState.getShopOutstandingDue(testShop);
      expect(initialDue, 0.0);

      final order = OrderModel(
        orderId: 'ORD-COLL-TEST-1',
        shopId: testShop.shopId,
        createdByUid: 'sales_rep_1',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: 'p_coll_1',
            productName: 'Surf Excel Quick Wash 1kg',
            quantity: 5,
            unitPrice: 200.0,
            gstRate: 18.0,
            itemSubtotal: 1000.0,
            itemGst: 180.0,
            itemGrandTotal: 1180.0,
          ),
        ],
        subtotal: 1000.0,
        totalGst: 180.0,
        grandTotal: 1180.0,
        placedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add standalone order booked on field without immediate tax invoice
      await appState.addOrder(order);

      // Verify shop currentOutstanding was incremented
      final updatedShop = appState.shops.firstWhere((s) => s.shopId == testShop.shopId);
      expect(updatedShop.currentOutstanding, 1180.0);

      // Verify getShopOutstandingDue returns 1180.0
      expect(appState.getShopOutstandingDue(updatedShop), 1180.0);

      // Verify ledger entry of type 'ORDER' was recorded
      final ledgerEntries = appState.ledgerEntries.where((l) => l.referenceId == order.orderId).toList();
      expect(ledgerEntries.isNotEmpty, isTrue);
      expect(ledgerEntries.first.type, 'ORDER');
      expect(ledgerEntries.first.amount, 1180.0);
    });

    test('2. getShopOutstandingDue computes pending orders even if shop currentOutstanding is 0', () async {
      final appState = AppState();
      
      final testShop = ShopModel(
        shopId: 'shop_test_coll_2',
        shopName: 'Om Sai Supermarket',
        ownerName: 'Suresh Patil',
        phone: '9811122233',
        businessType: 'Supermarket',
        currentOutstanding: 0.0, // cached as 0
      );
      await appState.addShop(testShop);

      // Create an order directly in orders list without updating shop
      final order = OrderModel(
        orderId: 'ORD-COLL-TEST-2',
        shopId: testShop.shopId,
        createdByUid: 'sales_rep_2',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: 'p_coll_2',
            productName: 'Tata Salt 1kg',
            quantity: 10,
            unitPrice: 28.0,
            gstRate: 0.0,
            itemSubtotal: 280.0,
            itemGst: 0.0,
            itemGrandTotal: 280.0,
          ),
        ],
        subtotal: 280.0,
        totalGst: 0.0,
        grandTotal: 280.0,
        placedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await appState.createOrder(order);

      // Effective due should be at least 280.0 despite shop.currentOutstanding being 0.0
      final effectiveDue = appState.getShopOutstandingDue(testShop);
      expect(effectiveDue, 280.0);
    });

    test('3. recordPayment reconciles matching order and reduces shop balance', () async {
      final appState = AppState();
      
      final testShop = ShopModel(
        shopId: 'shop_test_coll_3',
        shopName: 'Krishna General Stores',
        ownerName: 'Krishna Das',
        phone: '9844455566',
        businessType: 'General Store',
        currentOutstanding: 0.0,
      );
      await appState.addShop(testShop);

      final order = OrderModel(
        orderId: 'ORD-COLL-TEST-3',
        shopId: testShop.shopId,
        createdByUid: 'sales_rep_1',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: 'p_coll_3',
            productName: 'Fortune Sunlite Oil 1L',
            quantity: 4,
            unitPrice: 150.0,
            gstRate: 5.0,
            itemSubtotal: 600.0,
            itemGst: 30.0,
            itemGrandTotal: 630.0,
          ),
        ],
        subtotal: 600.0,
        totalGst: 30.0,
        grandTotal: 630.0,
        placedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await appState.addOrder(order);

      expect(appState.getShopOutstandingDue(testShop), 630.0);

      // Record payment with reference to the order
      final payment = PaymentModel(
        paymentId: 'PAY-COLL-TEST-1',
        shopId: testShop.shopId,
        createdByUid: 'sales_rep_1',
        amount: 630.0,
        paymentMode: 'Cash',
        notes: 'Payment for Order ORD-COLL-TEST-3',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );
      await appState.recordPayment(payment);

      // Verify shop balance is cleared
      final updatedShop = appState.shops.firstWhere((s) => s.shopId == testShop.shopId);
      expect(updatedShop.currentOutstanding, 0.0);

      // Verify matching order status updated to confirmed
      final updatedOrder = appState.orders.firstWhere((o) => o.orderId == order.orderId);
      expect(updatedOrder.status, 'confirmed');
    });

    testWidgets('4. CollectionsTab renders 2 tabs (Retailer Dues & Ledger) and Pending Orders is removed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();

      final shop = ShopModel(
        shopId: 'shop_widget_test',
        shopName: 'Ambika Traders',
        ownerName: 'Mahesh Ambika',
        phone: '9822233344',
        businessType: 'Wholesale',
        currentOutstanding: 560.0,
      );
      await appState.addShop(shop);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: CollectionsTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Pending Orders is removed and exactly 2 tabs are present
      expect(find.widgetWithText(Tab, 'Pending Orders'), findsNothing);
      expect(find.widgetWithText(Tab, 'Dues'), findsOneWidget);
      expect(find.widgetWithText(Tab, 'Ledger'), findsOneWidget);

      // Verify Ambika Traders appears in retailer dues with action buttons
      expect(find.text('Ambika Traders'), findsWidgets);
      expect(find.text('Record Payment'), findsWidgets);
      expect(find.text('Collect Payment'), findsWidgets);
    });
  });
}
