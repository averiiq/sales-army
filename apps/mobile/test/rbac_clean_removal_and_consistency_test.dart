import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/shops/presentation/screens/shop_detail_screen.dart';
import 'package:salesarmy/features/shops/presentation/screens/shops_tab.dart';

void main() {
  group('RBAC Strict Removal & Visual Consistency Tests', () {
    testWidgets('OrdersTab completely omits unauthorized sub-tabs for Delivery Staff', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Delivery Staff');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Delivery Staff must NOT see Order Taker or GST Bill tabs
      expect(find.text('Order Taker'), findsNothing);
      expect(find.byKey(const ValueKey('nav_billing')), findsNothing);

      // Must see the clean single-tab queue header banner
      expect(find.text('Delivery & Dispatch Route Queue'), findsOneWidget);
      expect(find.byIcon(Icons.local_shipping_rounded), findsWidgets);

      // Must NOT see any locked badges
      expect(find.text('LOCKED'), findsNothing);
      expect(find.text('UPGRADE'), findsNothing);
    });

    testWidgets('OrdersTab shows Orders for Field Sales but omits Bill and Order Taker', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Field Sales');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Order Taker is removed from OrdersTab
      expect(find.text('Order Taker'), findsNothing);
      expect(find.text('Orders Management Queue'), findsOneWidget);

      // And Field Sales does NOT see the GST Bill tab on OrdersTab
      expect(find.byKey(const ValueKey('nav_billing')), findsNothing);

      // Zero locked badges
      expect(find.text('LOCKED'), findsNothing);
    });

    testWidgets('OrdersTab shows Orders and Bill for Owner with Order Taker cleanly removed', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Owner');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: OrdersTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Owner sees Orders and Bill tabs (Order Taker removed)
      expect(find.text('Order Taker'), findsNothing);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Bill'), findsOneWidget);

      // Zero locked badges
      expect(find.text('LOCKED'), findsNothing);
    });

    testWidgets('ShopsTab omits Add Shop FAB and renders Directions for Delivery Staff', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Delivery Staff');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: ShopsTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Delivery Staff cannot add new shops -> FAB must be completely omitted
      expect(find.byType(FloatingActionButton), findsNothing);

      // Shop action button must be 'Directions' instead of 'New Order'
      expect(find.text('Directions'), findsWidgets);
      expect(find.text('New Order'), findsNothing);

      // Zero locked badges
      expect(find.text('LOCKED'), findsNothing);
    });

    testWidgets('ShopDetailScreen omits financial icons, Bills tab, and Take Order for Delivery Staff', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Delivery Staff');
      final testShop = appState.shops.first;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: ShopDetailScreen(shop: testShop),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Financial statements icons in AppBar are completely omitted
      expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
      expect(find.byIcon(Icons.menu_book_rounded), findsNothing);

      // Bills tab is completely omitted
      expect(find.textContaining('Bills ('), findsNothing);

      // Deliveries tab is tailored for Delivery Staff
      expect(find.textContaining('Deliveries ('), findsOneWidget);

      // Bottom dock renders 'Directions', NOT 'Take Order'
      expect(find.text('Take Order'), findsNothing);
      expect(find.text('Directions'), findsOneWidget);

      // Zero locked badges
      expect(find.text('LOCKED'), findsNothing);
    });

    testWidgets('Profile quick cards completely omit unauthorized modules', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Delivery Staff');

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

      // Delivery Staff should NOT see 'Sales' quick card
      expect(find.text('Sales'), findsNothing);

      // Should see 'Deliveries' quick card tailored to their role
      expect(find.text('Deliveries'), findsOneWidget);

      // Zero locked badges
      expect(find.text('LOCKED'), findsNothing);
    });
  });
}
