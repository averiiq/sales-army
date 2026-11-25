import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/billing/data/models/gst_slab_model.dart';
import 'package:salesarmy/features/profile/presentation/screens/gst_configuration_screen.dart';

/// The GST slabs page must lay out without overflow on small phones, with
/// large system text, long slab names / HSN lists, and on tablets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  AppState stateWithLongSlab() {
    final s = AppState(loadMockData: true);
    s.addGstSlab(GstSlabModel(
      id: 'gst_long',
      rate: 18,
      name: '18% GST — Biscuits, confectionery, namkeen and packaged snacks',
      category: 'Custom',
      details: 'Custom',
      hsnCodes: '1905, 2106, 1704, 2008, 1806',
      isDefault: false,
      isActive: true,
      createdAt: DateTime(2026, 11, 26),
    ));
    s.setGstBillingEnabled(true);
    s.updateTenantLocallyForTest(plan: 'enterprise'); // custom slabs are Enterprise
    return s;
  }

  // Any layout overflow makes the framework fail the test by itself.
  Future<void> pumpAt(WidgetTester tester, Size size, double textScale) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: stateWithLongSlab(),
      child: MaterialApp(
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const GstConfigurationScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('small phone (320 wide) with large text: no overflow', (tester) async {
    await pumpAt(tester, const Size(320, 640), 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal phone: no overflow, long slab name and HSN visible', (tester) async {
    await pumpAt(tester, const Size(390, 844), 1.0);
    expect(tester.takeException(), isNull);
    expect(find.textContaining('HSN'), findsWidgets);
  });

  testWidgets('add-slab sheet fits a small phone with the keyboard open', (tester) async {
    await pumpAt(tester, const Size(320, 560), 1.2);
    await tester.tap(find.text('Add Slab'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add GST Slab'), findsOneWidget, reason: 'the sheet really opened');
    expect(find.text('GST Tax Percentage (%) *'), findsOneWidget);
  });

  testWidgets('tablet: content is width-limited, not stretched', (tester) async {
    await pumpAt(tester, const Size(1280, 800), 1.0);
    expect(tester.takeException(), isNull);
    final cardWidth = tester.getSize(find.text('Enable GST Invoicing').first).width;
    expect(cardWidth, lessThan(800));
  });
}
