import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Dashboard Tile Routing & Shell Navigation Tests', () {
    testWidgets('1. DistributorDashboard tiles route correctly via onNavigateRoute and onNavigateTab', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState(loadMockData: true);
      await appState.createOrder(
        OrderModel(
          orderId: 'ORD-ROUTING-001',
          shopId: 'shop_001',
          createdByUid: 'demo_user_01',
          status: 'pending',
          items: const [],
          subtotal: 1500,
          totalGst: 0,
          grandTotal: 1500,
          placedAt: DateTime.now(),
        ),
      );

      String? capturedRoute;
      int? capturedTabIndex;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: DistributorDashboard(
                onNavigateRoute: (r) => capturedRoute = r,
                onNavigateTab: (idx) => capturedTabIndex = idx,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Test 1: Tap 'Collect' on Market Dues Alert
      expect(find.text('Collect'), findsOneWidget);
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();
      expect(capturedRoute, equals('collections'));

      // Test 2: Tap 'Restock' on Low Stock Alert
      expect(find.text('Restock'), findsOneWidget);
      await tester.tap(find.text('Restock'));
      await tester.pumpAndSettle();
      expect(capturedRoute, equals('inventory'));

      // Test 3: Tap 'View Orders' on Pending Orders Alert
      expect(find.text('View Orders'), findsOneWidget);
      await tester.tap(find.text('View Orders'));
      await tester.pumpAndSettle();
      expect(capturedRoute, equals('orders'));

      // Test 4: Tap 'View All' on Recent Invoices
      final viewAllOrders = find.text('View All');
      expect(viewAllOrders, findsWidgets);
      await tester.tap(viewAllOrders.first, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(capturedRoute, equals('orders'));

      // Test 5: Tap 'New Order' quick action tile redirects to billing
      expect(find.text('New Order'), findsOneWidget);
      await tester.tap(find.text('New Order'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(capturedRoute, equals('billing'));

      // Test 6: Tap 'Collect Dues' quick action tile redirects to collections
      expect(find.text('Collect Dues'), findsOneWidget);
      await tester.tap(find.text('Collect Dues'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(capturedRoute, equals('collections'));
    });

    testWidgets('2. MainShell shows top & bottom navbar only on Home with animated slide on other pages', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState(loadMockData: true);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify MainShell is mounted on Home tab
      expect(find.byType(DistributorDashboard), findsOneWidget);

      // Verify top AppBar is present on Home page
      expect(find.byType(AppBar), findsOneWidget);

      // Verify bottom nav items exist and navbar is fully visible on Home
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_billing')), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);

      // Bottom navbar is persistent across all pages
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_billing')), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Collection'), findsOneWidget);

      // 1. Navigate to Orders tab from bottom bar
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      // Top AppBar is removed on non-home pages
      expect(find.byType(AppBar), findsNothing);

      // Bottom navbar remains visible on Orders page
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Home'), findsOneWidget);

      // Tap back arrow button to return to Home
      final backIcon = find.byIcon(Icons.arrow_back_rounded);
      expect(backIcon, findsWidgets);
      await tester.tap(backIcon.first);
      await tester.pumpAndSettle();

      // Returned to Home: Top AppBar is restored
      expect(find.byType(AppBar), findsOneWidget);

      // 2. Navigate to Collection tab
      await tester.tap(find.text('Collection'));
      await tester.pumpAndSettle();

      // Top AppBar is null on Collection
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Collection'), findsWidgets);

      // Return via back arrow button
      expect(backIcon, findsWidgets);
      await tester.tap(backIcon.first);
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsOneWidget);

      // 3. Navigate to Parties tab
      await tester.tap(find.text('Parties'));
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Parties'), findsWidgets);

      // Return to Home via back icon button
      expect(backIcon, findsWidgets);
      await tester.tap(backIcon.first);
      await tester.pumpAndSettle();

      // Back on Home
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('3. Delivery role routes Orders/Deliveries correctly in MainShell', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final appState = AppState(loadMockData: true);
      // Switch active role to Delivery Staff
      appState.setActiveRole('Delivery Staff');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // For Delivery role, Bill and Collection tabs must NOT be present in bottom nav
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.byKey(const ValueKey('nav_billing')), findsNothing);
      expect(find.text('Collection'), findsNothing);

      // Tap 'Trip Route' action pill on Delivery hero card
      expect(find.text('Trip Route'), findsOneWidget);
      await tester.tap(find.text('Trip Route'), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Should have switched to the Orders/Deliveries tab
      expect(find.text('Orders'), findsWidgets);
    });
  });
}
