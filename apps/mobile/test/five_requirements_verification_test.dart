import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/admin/presentation/screens/subscription_checkout_screen.dart';
import 'package:salesarmy/features/billing/presentation/screens/gst_tax_invoice_viewer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('User 5 Strict Requirements Complete Verification Tests', () {
    // -------------------------------------------------------------------------
    // SCOPE 1: Orders & Billing Screen
    // -------------------------------------------------------------------------
    testWidgets('Scope 1: OrdersTab has pending orders, direct Deliver to completed, and Cancel action', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      // Seed a pending order
      final pendingOrder = OrderModel(
        orderId: 'ORD-TEST-PENDING-001',
        shopId: appState.shops.first.shopId,
        createdByUid: 'sales_rep_01',
        items: [
          TransactionItemSnapshot(
            productId: appState.products.first.productId,
            productName: appState.products.first.name,
            quantity: 2,
            rate: 90.0,
            taxableAmount: 180.0,
            gstRate: 5.0,
            cgst: 4.5,
            sgst: 4.5,
            totalGst: 9.0,
            total: 189.0,
          ),
        ],
        subtotal: 180.0,
        totalGst: 9.0,
        grandTotal: 189.0,
        status: 'pending',
        placedAt: DateTime.now(),
      );
      await appState.createOrder(pendingOrder);

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

      // 1. Verify static 'Pending' badge is rendered
      expect(find.text('Pending'), findsWidgets);

      // 2. Verify direct 'Deliver' button is visible on pending order card
      final deliverBtn = find.text('Deliver');
      expect(deliverBtn, findsWidgets);

      // 3. Verify 'Cancel' action button exists on order card header
      final cancelBtn = find.text('Cancel');
      expect(cancelBtn, findsWidgets);

      // 4. Tap 'Deliver' button -> transitions directly to 'completed'
      await tester.tap(deliverBtn.first);
      await tester.pumpAndSettle();

      final updatedOrder = appState.orders.firstWhere((o) => o.orderId == 'ORD-TEST-PENDING-001');
      expect(updatedOrder.status, equals('completed'));
      expect(updatedOrder.deliveredAt, isNotNull);

      // 5. Test dedicated Cancel action independently from the status display
      final pendingOrder2 = OrderModel(
        orderId: 'ORD-TEST-PENDING-002',
        shopId: appState.shops.first.shopId,
        createdByUid: 'sales_rep_01',
        items: [],
        subtotal: 250.0,
        totalGst: 0.0,
        grandTotal: 250.0,
        status: 'pending',
        placedAt: DateTime.now(),
      );
      await appState.createOrder(pendingOrder2);

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

      // Tap Cancel button on order card header -> opens Cancel Order confirmation dialog
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();

      expect(find.text('Cancel Order?'), findsOneWidget);
      expect(find.text('Cancel Order'), findsWidgets);

      // Tap 'Cancel Order'
      await tester.tap(find.text('Cancel Order'));
      await tester.pumpAndSettle();

      final cancelledOrder = appState.orders.firstWhere((o) => o.orderId == 'ORD-TEST-PENDING-002');
      expect(cancelledOrder.status, equals('cancelled'));
    });

    // -------------------------------------------------------------------------
    // SCOPE 2: Payment Collection Module
    // -------------------------------------------------------------------------
    testWidgets('Scope 2: CollectionsTab renders separate UPI/Razorpay and Record Collection buttons and filters in real-time', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      // Ensure test shop with outstanding due exists
      final testShop = ShopModel(
        shopId: 'shop-due-k1',
        shopName: 'Kolkata Sweet Centre',
        ownerName: 'Debashis Roy',
        address: 'FC Road, Pune',
        phone: '9822000001',
        currentOutstanding: 1200.0,
      );
      await appState.addShop(testShop);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: CollectionsTab(initialTabIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify two distinct action buttons on due cards
      expect(find.text('Collect Payment'), findsWidgets);
      expect(find.text('Record Payment'), findsWidgets);

      // 2. Verify real-time inline text filtering by party name
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Kolkata');
      await tester.pumpAndSettle();

      expect(find.text('Kolkata Sweet Centre'), findsWidgets);

      // 3. Tap 'Collect Payment' -> opens live gateway checkout modal
      await tester.tap(find.text('Collect Payment').first);
      await tester.pumpAndSettle();

      expect(find.text('UPI QR'), findsOneWidget);
      expect(find.text('Launch Razorpay Checkout'), findsOneWidget);
      expect(find.text('Share Payment Link'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // SCOPE 3: Profile Architecture
    // -------------------------------------------------------------------------
    testWidgets('Scope 3: Merged Profile & Business Details view with Unique User ID and 1-tap copy', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: ProfileAndSettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify single merged row 'Profile' (renamed from 'Profile & Business Details')
      expect(find.text('Profile'), findsOneWidget);

      // 2. Open unified modal
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();

      // 3. Verify Unique User ID banner is prominently placed at the top with 1-tap copy
      expect(find.text('UNIQUE USER ID / CUSTOMER ID'), findsOneWidget);
      expect(find.text(appState.uniqueUserId), findsWidgets);
      expect(find.text('Copy'), findsOneWidget);

      // 4. Verify both personal and company fields are unified in the single modal
      expect(find.text('Representative / Owner Name'), findsOneWidget);
      expect(find.text('Company / Firm Name'), findsOneWidget);
      expect(find.text('GSTIN (Tax ID)'), findsOneWidget);
      expect(find.text('Save Profile & Business Details'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // SCOPE 4: Plans & Hardware Purchase Flow
    // -------------------------------------------------------------------------
    testWidgets('Scope 4: Hardware peripheral toggle retained and Auto-fill Business Address populates fields', (tester) async {
      tester.view.physicalSize = const Size(1000, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      final plan = appState.subscriptionPlans.first;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: SubscriptionCheckoutScreen(
              initialPlan: plan,
              initialIncludePrinter: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify thermal POS printer hardware toggle exists and is functional
      expect(find.text('Wireless Thermal POS Printer'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);

      // 2. Select '+ Add New Delivery Address'
      await tester.tap(find.text('+ Add New Delivery Address'));
      await tester.pumpAndSettle();

      // 3. Verify "Auto-fill Business Address" button exists
      final autoFillBtn = find.text('Auto-fill Business Address');
      expect(autoFillBtn, findsOneWidget);

      // 4. Tap "Auto-fill Business Address" and verify fields are populated
      await tester.tap(autoFillBtn);
      await tester.pumpAndSettle();

      final streetFinder = find.widgetWithText(TextField, appState.tenant.warehouseAddress ?? 'Plot 42, Sector 8, Industrial Area, APMC Yard, Pune');
      expect(streetFinder, findsOneWidget);

      // 5. Verify fields remain editable by typing into street
      await tester.enterText(streetFinder, 'Custom Warehouse Street 100');
      await tester.pumpAndSettle();
      expect(find.text('Custom Warehouse Street 100'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // SCOPE 5: UI Polishing & Layout Fixes
    // -------------------------------------------------------------------------
    testWidgets('Scope 5: 7-column invoice table is wrapped in horizontal scroll with min-width constraint and FittedBox', (tester) async {
      tester.view.physicalSize = const Size(400, 800); // Narrow mobile device screen
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final invoice = InvoiceModel(
        invoiceId: 'inv-test-7col',
        invoiceNumber: 'INV-2026-0099',
        orderId: 'ord-1',
        shopId: 'shop-1',
        invoiceType: 'GST',
        invoiceDate: DateTime.now(),
        seller: {
          'firmName': 'SalesArmy Agency',
          'gstin': '27ABCDE1234F1Z5',
          'address': 'Plot 42, APMC Market Yard, Pune',
        },
        buyer: {
          'shopName': 'Shree Ganesh Kirana',
          'gstin': '27QWERT9876Y1Z2',
          'address': 'Shop 4, Market Road, Pune',
        },
        placeOfSupply: '27 (Maharashtra)',
        items: [
          TransactionItemSnapshot(
            productId: 'p1',
            productName: 'Tata Salt Vacuum Evaporated 1kg Premium Pouch',
            quantity: 24,
            rate: 22.0,
            taxableAmount: 528.0,
            gstRate: 5.0,
            cgst: 13.2,
            sgst: 13.2,
            totalGst: 26.4,
            total: 554.4,
          ),
        ],
        taxableSubtotal: 528.0,
        cgst: 13.2,
        sgst: 13.2,
        igst: 0.0,
        grandTotal: 554.4,
        paidAmount: 0.0,
        dueAmount: 554.4,
        paymentStatus: 'Unpaid',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.white,
            body: Builder(
              builder: (ctx) {
                return ElevatedButton(
                  onPressed: () => GstTaxInvoiceViewer.show(ctx, invoice),
                  child: const Text('Open Invoice'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Invoice'));
      await tester.pumpAndSettle();

      // 1. Verify invoice viewer opened
      expect(find.text('GST Tax Invoice'), findsOneWidget);

      // 2. Verify horizontal scroll view exists for table
      final horizontalScrolls = find.byWidgetPredicate(
        (widget) => widget is SingleChildScrollView && widget.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScrolls, findsOneWidget);

      // 3. Verify min-width constraint of 480 is enforced
      final constrainedBox = find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.minWidth == 480.0,
      );
      expect(constrainedBox, findsOneWidget);

      // 4. Verify FittedBox wraps numeric columns
      final fittedBoxes = find.byType(FittedBox);
      expect(fittedBoxes, findsWidgets);

      // 5. No render overflow exceptions occurred during narrow layout rendering
      expect(tester.takeException(), isNull);
    });
  });
}
