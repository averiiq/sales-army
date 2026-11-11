import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  group('Order Cancel Button Tests', () {
    testWidgets('Order card renders Cancel button at the top after shop name and cancels order on confirmation', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      final initialCount = appState.orders.length;
      expect(initialCount, greaterThan(0));

      final firstOrder = appState.orders.first;
      final shop = appState.shops.firstWhere((s) => s.shopId == firstOrder.shopId, orElse: () => appState.shops.first);

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

      // Verify Cancel button is visible at the top of the card
      expect(find.text('Cancel'), findsWidgets);
      expect(find.byIcon(Icons.cancel_outlined), findsWidgets);

      // Verify Cancel button position is to the right of shop name
      final shopNameFinder = find.text(shop.shopName).first;
      final cancelBtnFinder = find.text('Cancel').first;

      final shopPos = tester.getTopLeft(shopNameFinder);
      final cancelPos = tester.getTopLeft(cancelBtnFinder);

      expect(cancelPos.dx, greaterThan(shopPos.dx));
      // Y positions are horizontally aligned within top header
      expect((cancelPos.dy - shopPos.dy).abs(), lessThan(30.0));

      // Tap Cancel button
      await tester.tap(cancelBtnFinder);
      await tester.pumpAndSettle();

      // Verify Confirmation Dialog appears
      expect(find.text('Cancel Order?'), findsOneWidget);
      expect(find.textContaining('Are you sure you want to cancel Order #${firstOrder.orderId}'), findsOneWidget);

      // Tap Confirm 'Cancel Order' button in dialog
      final dialogCancelBtn = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(ElevatedButton, 'Cancel Order'),
      );
      expect(dialogCancelBtn, findsOneWidget);
      await tester.tap(dialogCancelBtn);
      await tester.pumpAndSettle();

      // Verify order is marked as cancelled in AppState
      expect(appState.orders.firstWhere((o) => o.orderId == firstOrder.orderId).status, equals('cancelled'));

      // Verify feedback snackbar
      expect(find.text('Order #${firstOrder.orderId} marked as Cancelled'), findsOneWidget);
    });

    testWidgets('List view also displays cancel button for orders', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

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

      // Switch to List View
      final listViewIcon = find.byIcon(Icons.view_list_rounded).first;
      await tester.tap(listViewIcon);
      await tester.pumpAndSettle();

      // Verify cancel icons are present in list view
      expect(find.byIcon(Icons.cancel_outlined), findsWidgets);
    });
  });
}
