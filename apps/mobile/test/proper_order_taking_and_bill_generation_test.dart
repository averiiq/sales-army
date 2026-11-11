import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/orders/presentation/screens/order_taker_flow.dart';
import 'package:salesarmy/features/orders/presentation/dialogs/complete_and_bill_order_modal.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Proper FMCG Order Taking and Bill Generation Flow Tests', () {
    testWidgets('OrderTakerFlow renders Book Order and Review & Bill buttons', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: OrderTakerFlow(
                initialShop: appState.shops.first,
                initialCart: {appState.products.first.productId: 2},
                onOrderCompleted: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify bottom action bar has both Book Order and Review & Bill
      expect(find.text('Book Order'), findsOneWidget);
      expect(find.text('Review & Bill'), findsOneWidget);
      expect(find.textContaining('item'), findsWidgets);
    });

    testWidgets('Booking Order Only creates order in pending status without immediate invoice', (tester) async {
      final appState = AppState();
      final initialOrderCount = appState.orders.length;
      final initialInvoiceCount = appState.invoices.length;
      final targetShop = appState.shops.first;

      bool completedCalled = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: OrderTakerFlow(
                initialShop: targetShop,
                initialCart: {appState.products.first.productId: 3},
                onOrderCompleted: () {
                  completedCalled = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Book Order button
      await tester.tap(find.text('Book Order'));
      await tester.pumpAndSettle();

      expect(completedCalled, isTrue);
      expect(appState.orders.length, initialOrderCount + 1);
      // Standalone order does not immediately create an invoice
      expect(appState.invoices.length, initialInvoiceCount);

      final bookedOrder = appState.orders.first;
      expect(bookedOrder.status, 'pending');
      expect(bookedOrder.shopId, targetShop.shopId);
      expect(bookedOrder.items.first.quantity, 3);
    });

    testWidgets('OrdersTab shows View Bill for billed order and Generate Bill for unbilled order', (tester) async {
      final appState = AppState();

      // Ensure we have an unbilled order
      final unbilledOrder = OrderModel(
        orderId: 'ORD-TEST-UNBILLED-99',
        shopId: appState.shops.first.shopId,
        createdByUid: 'sales_rep_01',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: appState.products.first.productId,
            productName: appState.products.first.name,
            quantity: 4,
            rate: 100.0,
            taxableAmount: 400.0,
            gstRate: 5.0,
            cgst: 10.0,
            sgst: 10.0,
            totalGst: 20.0,
            total: 420.0,
          ),
        ],
        subtotal: 400.0,
        totalGst: 20.0,
        grandTotal: 420.0,
        placedAt: DateTime.now(),
      );
      await appState.createOrder(unbilledOrder);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(initialTabIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // ORD-2026-001 has an invoice and shows "View Bill"
      expect(find.text('View Bill'), findsWidgets);

      // ORD-TEST-UNBILLED-99 has no invoice and shows "Generate Bill"
      expect(find.text('Generate Bill'), findsWidgets);
    });

    testWidgets('CompleteAndBillOrderModal bills existing order and updates status to confirmed', (tester) async {
      final appState = AppState();
      final initialInvoiceCount = appState.invoices.length;
      final targetShop = appState.shops.first;

      final existingOrder = OrderModel(
        orderId: 'ORD-CONVERT-88',
        shopId: targetShop.shopId,
        createdByUid: 'sales_rep_01',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: appState.products.first.productId,
            productName: appState.products.first.name,
            quantity: 2,
            rate: appState.products.first.basePrice,
            taxableAmount: appState.products.first.basePrice * 2,
            gstRate: 0.0,
            cgst: 0.0,
            sgst: 0.0,
            totalGst: 0.0,
            total: appState.products.first.basePrice * 2,
          ),
        ],
        subtotal: appState.products.first.basePrice * 2,
        totalGst: 0.0,
        grandTotal: appState.products.first.basePrice * 2,
        placedAt: DateTime.now(),
      );
      await appState.createOrder(existingOrder);

      OrderModel? completedOrder;
      InvoiceModel? completedInvoice;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      CompleteAndBillOrderModal.show(
                        context,
                        destinationShop: targetShop,
                        cartQuantities: {
                          appState.products.first.productId: 2,
                        },
                        existingOrder: existingOrder,
                        onOrderCompleted: (ord, inv) {
                          completedOrder = ord;
                          completedInvoice = inv;
                        },
                      );
                    },
                    child: const Text('Open Modal'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the modal
      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      // Verify Modal displays dynamic title for existing order
      expect(find.textContaining('ORD-CONVERT-88'), findsWidgets);

      // Settle via Cash (Confirm Cash Payment & Print Invoice)
      final completeButton = find.text('Confirm Cash Payment & Print Invoice');
      expect(completeButton, findsOneWidget);
      await tester.ensureVisible(completeButton);
      await tester.tap(completeButton);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));

      expect(completedOrder, isNotNull);
      expect(completedInvoice, isNotNull);
      expect(completedOrder!.orderId, 'ORD-CONVERT-88');
      expect(completedInvoice!.orderId, 'ORD-CONVERT-88');
      expect(appState.invoices.length, initialInvoiceCount + 1);

      // Order status updated to confirmed in AppState
      final updatedOrder = appState.orders.firstWhere((o) => o.orderId == 'ORD-CONVERT-88');
      expect(updatedOrder.status, 'confirmed');
    });

    test('AppState sync methods create, bill, record payment, and cancel invoices correctly', () async {
      final appState = AppState();
      final shop = appState.shops.first;
      final initialOutstanding = shop.currentOutstanding;

      // 1. Create Standalone Order
      final order = OrderModel(
        orderId: 'ORD-LIFECYCLE-001',
        shopId: shop.shopId,
        createdByUid: 'test_rep',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: appState.products.first.productId,
            productName: appState.products.first.name,
            quantity: 2,
            rate: 200.0,
            taxableAmount: 400.0,
            gstRate: 0.0,
            cgst: 0.0,
            sgst: 0.0,
            totalGst: 0.0,
            total: 400.0,
          ),
        ],
        subtotal: 400.0,
        totalGst: 0.0,
        grandTotal: 400.0,
        placedAt: DateTime.now(),
      );

      await appState.addOrder(order);
      expect(appState.orders.first.orderId, 'ORD-LIFECYCLE-001');

      // 2. Generate Invoice
      final invoice = InvoiceModel(
        invoiceId: 'inv_lifecycle_001',
        invoiceNumber: 'INV-2026-9999',
        orderId: 'ORD-LIFECYCLE-001',
        shopId: shop.shopId,
        invoiceType: 'GST',
        invoiceDate: DateTime.now(),
        seller: {'firmName': 'Test Firm'},
        buyer: {'shopName': shop.shopName},
        items: order.items,
        placeOfSupply: 'Maharashtra',
        taxableSubtotal: 400.0,
        cgst: 0.0,
        sgst: 0.0,
        igst: 0.0,
        grandTotal: 400.0,
        paidAmount: 0.0,
        dueAmount: 400.0,
        paymentStatus: 'unpaid',
      );

      await appState.createInvoice(invoice);
      final shopAfterInvoice = appState.shops.firstWhere((s) => s.shopId == shop.shopId);
      expect(shopAfterInvoice.currentOutstanding, initialOutstanding + 400.0);

      // 3. Record Payment
      final payment = PaymentModel(
        paymentId: 'PAY-LIFECYCLE-001',
        shopId: shop.shopId,
        createdByUid: 'test_rep',
        amount: 400.0,
        paymentMode: 'Cash',
        referenceNumber: 'INV-2026-9999',
        date: DateTime.now(),
      );

      await appState.recordPayment(payment);
      final shopAfterPayment = appState.shops.firstWhere((s) => s.shopId == shop.shopId);
      expect(shopAfterPayment.currentOutstanding, initialOutstanding);

      // 4. Update order status
      await appState.updateOrderStatus('ORD-LIFECYCLE-001', 'delivered');
      final deliveredOrder = appState.orders.firstWhere((o) => o.orderId == 'ORD-LIFECYCLE-001');
      expect(deliveredOrder.status, 'delivered');
      expect(deliveredOrder.deliveredAt, isNotNull);

      // 5. Delete / Cancel Invoice
      final deleted = await appState.deleteInvoice('inv_lifecycle_001');
      expect(deleted, isTrue);
      expect(appState.invoices.any((i) => i.invoiceId == 'inv_lifecycle_001'), isFalse);
    });
  });
}
