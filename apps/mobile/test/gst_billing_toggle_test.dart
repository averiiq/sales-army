import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/orders/presentation/screens/orders_tab.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/mock_data.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  group('GST Billing Toggle - AppState & TenantModel', () {
    test('AppState defaults isGstBillingEnabled to true and toggles correctly', () async {
      final appState = AppState();
      expect(appState.isGstBillingEnabled, isTrue);

      bool notified = false;
      appState.addListener(() {
        notified = true;
      });

      await appState.setGstBillingEnabled(false);
      expect(appState.isGstBillingEnabled, isFalse);
      expect(notified, isTrue);

      notified = false;
      await appState.setGstBillingEnabled(true);
      expect(appState.isGstBillingEnabled, isTrue);
      expect(notified, isTrue);
    });

    test('TenantModel serialization preserves isGstBillingEnabled', () {
      final tenant = MockData.demoTenant.copyWith(isGstBillingEnabled: false);
      expect(tenant.isGstBillingEnabled, isFalse);

      final map = tenant.toMap();
      expect(map['isGstBillingEnabled'], isFalse);

      final deserialized = MockData.demoTenant.copyWith().toMap();
      expect(deserialized['isGstBillingEnabled'], isTrue);
    });
  });

  group('GST Billing Toggle - OrdersTab UI', () {
    testWidgets('OrdersTab shows GST Bills tab and billing options when isGstBillingEnabled is true', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      await appState.setGstBillingEnabled(true);

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

      // Bill tab should be visible
      expect(find.text('Bill'), findsOneWidget);

      // Switch to Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      // Orders tab is displayed
      expect(find.text('Orders'), findsOneWidget);
    });

    testWidgets('OrdersTab hides GST Bills tab and billing options when isGstBillingEnabled is false', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      await appState.setGstBillingEnabled(false);

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

      // Bill and Order Taker should NOT be visible
      expect(find.text('Bill'), findsNothing);
      expect(find.text('Order Taker'), findsNothing);

      // Orders Management Queue is active directly as the sole view
      expect(find.text('Orders Management Queue'), findsOneWidget);
    });
  });

  group('GST Billing Toggle - Settings Switch', () {
    testWidgets('MainShell settings sheet allows toggling GST Billing', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      expect(appState.isGstBillingEnabled, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(
              onSignOut: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Profile and Settings by tapping top-left profile header
      final rawFirm = appState.tenant.firmName ?? 'SalesArmy Agency';
      final profileHeader = find.text(rawFirm.length > 10 ? '${rawFirm.substring(0, 10)}...' : rawFirm);
      expect(profileHeader, findsOneWidget);
      await tester.tap(profileHeader);
      await tester.pumpAndSettle();

      // Verify My Business screen opened
      expect(find.text('My Business'), findsWidgets);

      // Verify GST Details row is visible on main screen
      final gstDetailsRow = find.text('GST Details');
      expect(gstDetailsRow, findsOneWidget);
      await tester.ensureVisible(gstDetailsRow);
      await tester.pumpAndSettle();

      // Tap GST Details to open compliance modal
      await tester.tap(gstDetailsRow);
      await tester.pumpAndSettle();

      // Verify Enable GST Tax Invoicing switch is visible inside modal
      expect(find.text('Enable GST Tax Invoicing'), findsOneWidget);

      // Toggle switch
      final switchFinder = find.byWidgetPredicate(
        (widget) => widget is SwitchListTile && widget.title is Text && (widget.title as Text).data == 'Enable GST Tax Invoicing',
      );
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(appState.isGstBillingEnabled, isFalse);
    });
  });
}
