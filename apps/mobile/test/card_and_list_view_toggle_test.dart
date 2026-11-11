import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/features/inventory/presentation/screens/inventory_tab.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  group('Orders & Inventory Card vs List View Toggle Tests', () {
    testWidgets('OrdersTab allows toggling between Card and List views', (tester) async {
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

      // Verify initial Card View
      expect(find.byIcon(Icons.grid_view_rounded), findsWidgets);
      expect(find.byIcon(Icons.view_list_rounded), findsWidgets);
      expect(find.text('ORD-2026-001'), findsWidgets);
      expect(find.text('Collect Payment'), findsWidgets);
      expect(find.text('View Bill'), findsWidgets);

      // Tap List View toggle button
      final listViewIcon = find.byIcon(Icons.view_list_rounded).first;
      await tester.tap(listViewIcon);
      await tester.pumpAndSettle();

      // In List View, compact list items show 'View' quick action
      expect(find.text('ORD-2026-001'), findsWidgets);
      expect(find.text('View'), findsWidgets);

      // Tap Card View toggle button to return to Card View
      final cardViewIcon = find.byIcon(Icons.grid_view_rounded).first;
      await tester.tap(cardViewIcon);
      await tester.pumpAndSettle();

      // Verified back in Card View
      expect(find.text('Collect Payment'), findsWidgets);
      expect(find.text('View Bill'), findsWidgets);
    });

    testWidgets('InventoryTab allows toggling between Grid Card and List views', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: InventoryTab(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify initial Card View (2-Column Grid)
      expect(find.byIcon(Icons.grid_view_rounded), findsOneWidget);
      expect(find.byIcon(Icons.view_list_rounded), findsOneWidget);
      expect(find.text('Aashirvaad Shudh Chakki Atta'), findsWidgets);
      expect(find.textContaining('WS: ₹240'), findsWidgets);
      expect(find.byType(SliverGrid), findsOneWidget);

      // Tap List View toggle button
      final listViewIcon = find.byIcon(Icons.view_list_rounded);
      await tester.tap(listViewIcon);
      await tester.pumpAndSettle();

      // Verify List View is rendered
      expect(find.byType(SliverList), findsWidgets);
      expect(find.text('Aashirvaad Shudh Chakki Atta'), findsWidgets);
      expect(find.textContaining('WS: ₹240'), findsWidgets);

      // Tap Card View toggle button to return to Grid View
      final cardViewIcon = find.byIcon(Icons.grid_view_rounded);
      await tester.tap(cardViewIcon);
      await tester.pumpAndSettle();

      // Verified back in Grid Card View
      expect(find.byType(SliverGrid), findsOneWidget);
    });
  });
}
