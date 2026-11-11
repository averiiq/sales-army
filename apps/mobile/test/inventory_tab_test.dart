import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/inventory/presentation/screens/inventory_tab.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  testWidgets(
    'InventoryTab UI renders search bar, alert banner, stats, filter chips and products',
    (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: InventoryTab()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Search Bar
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);

      // Verify Category Filter Chips
      expect(find.textContaining('All (31)'), findsOneWidget);

      // Verify Product Cards
      expect(find.text('Aashirvaad Shudh Chakki Atta'), findsOneWidget);
      expect(find.text('Surface Cleaner'), findsOneWidget);
      expect(find.textContaining('WS: ₹240'), findsOneWidget);
      expect(find.textContaining('WS: ₹110'), findsOneWidget);

      // Verify Floating Action Button
      expect(find.byType(FloatingActionButton), findsOneWidget);
    },
  );

  testWidgets(
    'Tapping FAB opens Add Inventory Product modal sheet with clean inputs and GST preview',
    (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: InventoryTab()),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Floating Action Button
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Verify Modal header
      expect(find.text('Add Inventory Product'), findsOneWidget);
      expect(find.text('Upload Product Image'), findsOneWidget);
      expect(find.text('Or Choose Product Preset:'), findsNothing);

      // Verify GST Slab Card & calculation preview
      expect(find.text('Product-Wise GST Slab Option'), findsOneWidget);
      expect(find.text('GST Calculation Preview (Per Unit)'), findsOneWidget);
      expect(find.text('Taxable Base Price:'), findsOneWidget);
      expect(find.text('Total Price Incl. GST:'), findsOneWidget);
      expect(find.text('Save Product & GST'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Add Inventory Product'), findsNothing);
    },
  );
}
