import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/billing/presentation/dialogs/estimated_bill_dialog.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/sales_data_screen.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppState - Order Delivery Status and In-Hand Balances Tests', () {
    test('updateOrderStatus updates status to delivered and records deliveredAt', () async {
      final appState = AppState();
      const testOrderId = 'test_order_101';
      final order = OrderModel(
        orderId: testOrderId,
        shopId: 'shop_001',
        createdByUid: 'uid_1',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: 'prod_1',
            productName: 'Parle-G',
            quantity: 5,
            rate: 10.0,
            taxableAmount: 50.0,
            gstRate: 0.0,
            cgst: 0.0,
            sgst: 0.0,
            totalGst: 0.0,
            total: 50.0,
          ),
        ],
        subtotal: 50.0,
        totalGst: 0.0,
        grandTotal: 50.0,
        placedAt: DateTime.now(),
      );

      await appState.createOrder(order);
      expect(appState.orders.first.orderId, testOrderId);
      expect(appState.orders.first.status, 'pending');

      // Update to delivered
      await appState.updateOrderStatus(testOrderId, 'delivered');
      final delivered = appState.orders.firstWhere((o) => o.orderId == testOrderId);
      expect(delivered.status, 'delivered');
      expect(delivered.deliveredAt, isNotNull);

      // Update to cancelled
      await appState.updateOrderStatus(testOrderId, 'cancelled');
      final cancelled = appState.orders.firstWhere((o) => o.orderId == testOrderId);
      expect(cancelled.status, 'cancelled');

      // Update back to pending
      await appState.updateOrderStatus(testOrderId, 'pending');
      final pending = appState.orders.firstWhere((o) => o.orderId == testOrderId);
      expect(pending.status, 'pending');
      expect(pending.deliveredAt, isNull);
    });

    test('updateInHandAndAccountBalances updates balances and totalLiquidBalance', () async {
      final appState = AppState();
      await appState.updateInHandAndAccountBalances(
        inHandCash: 25000.0,
        inAccountBalance: 200000.0,
      );

      expect(appState.inHandCash, 25000.0);
      expect(appState.inAccountBalance, 200000.0);
      expect(appState.totalLiquidBalance, 225000.0);
    });
  });

  group('MainShell 5-Option Bottom Navbar Tests', () {
    testWidgets('MainShell displays exactly 5 bottom navbar options: Home, Parties, Bill, Orders, Collection',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_billing')), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);

      // Ensure Dashboard/Shops/Stock are not bottom bar labels
      expect(find.text('Dashboard'), findsNothing);
      expect(find.text('Shops'), findsNothing);
      expect(find.text('Stock'), findsNothing);
    });
  });

  group('Estimated Bill & Sales Data Screen Widget Tests', () {
    testWidgets('EstimatedBillDialog renders rough quotation banner, share and convert buttons',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: EstimatedBillDialog(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estimated Bill'), findsOneWidget);
      expect(find.text('Share WA'), findsNothing);
      expect(find.text('Convert to Bill'), findsOneWidget);
      expect(find.text('Generate Estimated Bill'), findsOneWidget);
      expect(find.text('ESTIMATED TOTAL'), findsOneWidget);
    });

    testWidgets('SalesDataScreen renders analytics header and tabs',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: SalesDataScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sales Data & Analytics'), findsOneWidget);
      expect(find.text('TOTAL REVENUE OVERVIEW'), findsOneWidget);
      expect(find.text('All Time'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('This Week'), findsOneWidget);
      expect(find.text('This Month'), findsWidgets);
    });
  });
}
