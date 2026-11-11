import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  group('Home Page Top Alerts Hub Tests', () {
    testWidgets('DistributorDashboard renders all operational alerts at the top below navbar', (tester) async {
      final appState = AppState(loadMockData: true);
      // Add a pending order to trigger the pending orders alert
      await appState.createOrder(
        OrderModel(
          orderId: 'ORD-PENDING-001',
          shopId: 'shop_001',
          createdByUid: 'demo_user_01',
          status: 'pending',
          items: const [],
          subtotal: 1000,
          totalGst: 0,
          grandTotal: 1000,
          placedAt: DateTime.now(),
        ),
      );

      int? navigatedTab;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: Scaffold(
              body: DistributorDashboard(
                onNavigateTab: (tabIdx) => navigatedTab = tabIdx,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Market Dues Alert at the top
      expect(find.textContaining('Market Dues:'), findsOneWidget);
      expect(find.text('Collect'), findsOneWidget);

      // 2. Verify Low Stock Alert at the top
      expect(find.textContaining('Low Stock Alert:'), findsOneWidget);
      expect(find.text('Restock'), findsOneWidget);

      // 3. Verify Pending Orders Alert at the top
      expect(find.textContaining('Pending Orders:'), findsOneWidget);
      expect(find.text('View Orders'), findsOneWidget);

      // 4. Test Navigation: Tap 'Collect' navigates to Collections tab (tab index 4)
      await tester.tap(find.text('Collect'));
      await tester.pumpAndSettle();
      expect(navigatedTab, equals(4));

      // 5. Test Navigation: Tap 'Restock' navigates to Inventory tab (tab index 3)
      await tester.tap(find.text('Restock'));
      await tester.pumpAndSettle();
      expect(navigatedTab, equals(3));

      // 6. Test Navigation: Tap 'View Orders' navigates to Orders tab (tab index 2)
      await tester.tap(find.text('View Orders'));
      await tester.pumpAndSettle();
      expect(navigatedTab, equals(2));

      // 7. Test Dismiss Alert: Tapping close button dismisses that specific alert
      final closeButtons = find.byIcon(Icons.close_rounded);
      expect(closeButtons, findsWidgets);
      await tester.tap(closeButtons.first);
      await tester.pumpAndSettle();

      // Verify the first alert is now dismissed
      expect(find.textContaining('Market Dues:'), findsNothing);
      // Other alerts remain visible
      expect(find.textContaining('Low Stock Alert:'), findsOneWidget);
      expect(find.textContaining('Pending Orders:'), findsOneWidget);
    });
  });
}
