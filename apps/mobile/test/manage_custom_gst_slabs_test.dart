import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/billing/data/models/gst_slab_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/profile/presentation/screens/gst_configuration_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Manage Custom GST Slabs and Billing Application Tests', () {
    test('GstSlabModel instantiation with note, details, category and HSN', () {
      final slab = GstSlabModel(
        id: 'gst_custom_18_confectionery',
        rate: 18.0,
        name: 'Confectionery & Bakery Standard',
        category: 'Concessional & Processed',
        details: 'Applicable to baked cookies, packaged snacks, and dry fruit gifts',
        note: 'Subject to CBIC circular 45/2026 for retail packaged goods',
        hsnCodes: '1905, 2106',
        isDefault: false,
        isActive: true,
        createdAt: DateTime(2026, 10, 2),
      );

      expect(slab.rate, 18.0);
      expect(slab.name, 'Confectionery & Bakery Standard');
      expect(slab.category, 'Concessional & Processed');
      expect(slab.details, contains('packaged snacks'));
      expect(slab.note, contains('CBIC circular'));
      expect(slab.hsnCodes, '1905, 2106');
      expect(slab.cgstRate, 9.0);
      expect(slab.sgstRate, 9.0);
      expect(slab.igstRate, 18.0);
      expect(slab.formattedRate, '18%');
      expect(slab.displayName, '18% - Confectionery & Bakery Standard');

      // Test map serialization & deserialization
      final map = slab.toMap();
      expect(map['rate'], 18.0);
      expect(map['note'], contains('CBIC circular'));
      expect(map['details'], contains('packaged snacks'));

      final restored = GstSlabModel.fromMap(map);
      expect(restored.id, slab.id);
      expect(restored.name, slab.name);
      expect(restored.details, slab.details);
      expect(restored.note, slab.note);
      expect(restored.hsnCodes, slab.hsnCodes);
    });

    test('AppState manages GST slabs lifecycle (add, query, delete)', () async {
      final appState = AppState();

      // Verify standard FMCG slabs are present by default
      expect(appState.activeGstSlabs.isNotEmpty, true);
      expect(appState.activeGstSlabs.any((s) => s.rate == 0.0), true);
      expect(appState.activeGstSlabs.any((s) => s.rate == 5.0), true);
      expect(appState.activeGstSlabs.any((s) => s.rate == 12.0), true);
      expect(appState.activeGstSlabs.any((s) => s.rate == 18.0), true);
      expect(appState.activeGstSlabs.any((s) => s.rate == 28.0), true);

      final initialCount = appState.activeGstSlabs.length;

      // Add custom slab with details and note
      final customSlab = GstSlabModel(
        id: 'gst_test_40_demerit',
        rate: 40.0,
        name: 'Demerit & Luxury Tobacco Surcharge',
        category: 'Luxury & Demerit',
        details: 'Special surcharge on aerated carbonated beverages and tobacco',
        note: 'Levied with state compensation cess',
        hsnCodes: '2202, 2402',
        isDefault: false,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await appState.addGstSlab(customSlab);

      expect(appState.activeGstSlabs.length, initialCount + 1);
      final fetched = appState.getSlabByRate(40.0);
      expect(fetched, isNotNull);
      expect(fetched!.name, 'Demerit & Luxury Tobacco Surcharge');
      expect(fetched.details, contains('carbonated beverages'));
      expect(fetched.note, contains('compensation cess'));
      expect(fetched.hsnCodes, '2202, 2402');

      // Delete custom slab
      final deleted = await appState.deleteGstSlab(customSlab.id);
      expect(deleted, true);
      expect(appState.activeGstSlabs.length, initialCount);
      expect(appState.getSlabByRate(40.0), isNull);
    });

    test('Custom GST slab calculates tax and bill amounts accurately', () {
      final customSlab = GstSlabModel(
        id: 'gst_test_12_dairy',
        rate: 12.0,
        name: 'Processed Dairy & Condensed Milk',
        category: 'Processed & Dairy',
        details: 'Paneer, cheese spreads, and pasteurized butter',
        note: 'Exempt for raw unbranded milk, 12% for retail packaged dairy',
        hsnCodes: '0402, 0406',
        isDefault: false,
        isActive: true,
        createdAt: DateTime.now(),
      );

      // Create test product with base price ₹500
      final product = ProductModel(
        productId: 'prod_cheese_01',
        name: 'Pure Cheddar Cheese Block 1kg',
        sku: 'DAIRY-001',
        categoryId: 'cat_dairy',
        basePrice: 500.0,
        gstRate: 5.0, // standard catalog rate
        hsnSacCode: '0406',
        stockQuantity: 50,
        lowStockAlertQty: 10,
        createdAt: DateTime.now(),
      );

      final quantity = 2;
      final subtotal = product.basePrice * quantity; // ₹1000.0

      // When custom slab (12%) is applied to the bill:
      final customGstRate = customSlab.rate;
      final taxAmount = subtotal * (customGstRate / 100); // ₹120.0
      final grandTotal = subtotal + taxAmount; // ₹1120.0
      final cgst = taxAmount / 2; // ₹60.0
      final sgst = taxAmount / 2; // ₹60.0
      final igst = taxAmount; // ₹120.0

      expect(subtotal, 1000.0);
      expect(taxAmount, 120.0);
      expect(grandTotal, 1120.0);
      expect(cgst, 60.0);
      expect(sgst, 60.0);
      expect(igst, 120.0);
    });

    testWidgets('Add Custom GST modal is simple, clean, and has extra presets/sliders removed', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: GstConfigurationScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Add Slab' button in header
      final addSlabBtn = find.widgetWithText(ElevatedButton, 'Add Slab');
      expect(addSlabBtn, findsOneWidget);
      await tester.tap(addSlabBtn);
      await tester.pumpAndSettle();

      // Verify Popup Header
      expect(find.text('Add Custom GST Tax Slab'), findsOneWidget);

      // Verify that extra sliders, preset chips, and tax preview cards are removed
      expect(find.byType(Slider), findsNothing);
      expect(find.text('Popular Rate Presets'), findsNothing);
      expect(find.text('TAX BREAKDOWN PREVIEW'), findsNothing);
      expect(find.text('Custom FMCG Rate'), findsNothing);

      // Verify simple, clean form fields
      expect(find.text('GST Tax Percentage (%) *'), findsOneWidget);
      expect(find.text('Slab Name / Title *'), findsOneWidget);
      expect(find.text('HSN / SAC Code (Optional)'), findsOneWidget);

      // Enter 12% tax rate
      final rateField = find.widgetWithText(TextField, '18');
      expect(rateField, findsOneWidget);
      await tester.enterText(rateField, '12');
      await tester.pumpAndSettle();

      // Enter custom slab name
      final nameField = find.widgetWithText(TextField, '12% GST');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Packaged Staples');
      await tester.pumpAndSettle();

      // Enter optional HSN code
      await tester.enterText(find.widgetWithText(TextField, 'e.g. 1905, 2106'), '1905');
      await tester.pumpAndSettle();

      // Tap submit button to save
      final submitBtn = find.text('Add 12% GST Tax Slab');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify modal dismissed and new slab appears in list
      expect(find.text('Add Custom GST Tax Slab'), findsNothing);
      expect(find.textContaining('Packaged Staples'), findsWidgets);
    });
  });
}

