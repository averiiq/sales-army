import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/presentation/screens/plan_and_pricing_screen.dart';
import 'package:salesarmy/features/admin/presentation/screens/subscription_checkout_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Refined Subscription & 1-Step Express Checkout Flow Tests', () {
    testWidgets('1. PlanAndPricingScreen renders executive tiers and directly opens checkout on tap', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: PlanAndPricingScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Tiers
      expect(find.text('Plan & Subscription'), findsOneWidget);
      expect(find.text('CURRENT ACTIVE PLAN'), findsOneWidget);
      expect(find.text('Startup'), findsOneWidget);
      expect(find.text('Grow'), findsOneWidget);
      expect(find.text('Enterprise'), findsOneWidget);
      expect(find.text('MOST POPULAR'), findsOneWidget);

      // Verify no cluttered 6-field manual address form on pricing page
      expect(find.text('Enter Shipping Details:'), findsNothing);

      // Tap 'Select Grow Plan' and verify it transitions straight to Express Checkout
      final selectGrowBtn = find.text('Select Grow Plan');
      expect(selectGrowBtn, findsOneWidget);
      await tester.tap(selectGrowBtn);
      await tester.pumpAndSettle();

      // Express Checkout is pushed directly without intermediate summary modal
      expect(find.text('Express Checkout'), findsOneWidget);
      expect(find.text('256-Bit SSL Encrypted • Instant Activation'), findsOneWidget);
    });

    testWidgets('2. Checkout renders coupons and shipping but requires server verification before activation', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();
      final growPlan = appState.subscriptionPlans.firstWhere((p) => p.name == 'Grow');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: SubscriptionCheckoutScreen(
              initialPlan: growPlan,
              initialIsYearly: false,
              initialIncludePrinter: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify single-view layout (no cumbersome "1. Plan", "2. Printer", "3. Coupon", "4. Payment", "5. Breakdown" step numbers)
      expect(find.text('1. Plan & Billing Cycle'), findsNothing);
      expect(find.text('Selected Subscription Plan'), findsOneWidget);
      expect(find.text('Wireless Thermal POS Printer'), findsOneWidget);
      expect(find.text('Offers & Coupons'), findsOneWidget);
      expect(find.text('Payment Method'), findsOneWidget);
      expect(find.text('Transparent Bill Breakdown'), findsOneWidget);

      // 2. Verify Smart Shipping default (courier to registered godown / warehouse address option)
      expect(find.text('Shop Address'), findsOneWidget);
      expect(find.text('+ Add New Delivery Address'), findsOneWidget);

      // 3. Verify Coupon input field exists and apply TRIAL30
      final couponField = find.widgetWithText(TextField, 'Enter coupon or promo code...');
      await tester.ensureVisible(couponField);
      await tester.enterText(couponField, 'TRIAL30');
      final applyBtn = find.text('Apply');
      await tester.ensureVisible(applyBtn);
      await tester.tap(applyBtn);
      await tester.pumpAndSettle();

      expect(appState.appliedCoupon?.code, equals('TRIAL30'));
      expect(find.textContaining('Applied: TRIAL30'), findsOneWidget);

      // 4. Verify Express CTA updates to Free Trial (or includes printer if added)
      expect(find.textContaining('Pay ₹'), findsOneWidget);

      // Toggle printer off to test pure free trial activation
      final printerSwitch = find.byType(Switch);
      await tester.ensureVisible(printerSwitch);
      expect(printerSwitch, findsOneWidget);
      await tester.tap(printerSwitch);
      await tester.pumpAndSettle();

      expect(find.text('Start 30-Day Free Trial (₹0)'), findsOneWidget);

      // Tap Activate Now
      final previousPlan = appState.tenant.subscriptionPlanId;
      final previousExpiry = appState.tenant.subscriptionEndDate;
      await tester.tap(find.text('Start 30-Day Free Trial (₹0)'));
      await tester.pump(); // Start async processing
      await tester.pump(const Duration(milliseconds: 1500)); // Advance gateway delay
      await tester.pump(const Duration(milliseconds: 500)); // Advance dialog transition
      await tester.pumpAndSettle();

      // Plans are activated only by the server (payment server or the
      // database test-activation RPC). With no server reachable here, the
      // phone must NOT grant itself the plan — it shows an error instead.
      expect(find.text('Payment & Plan Activated!'), findsNothing);
      expect(appState.tenant.subscriptionPlanId, equals(previousPlan));
      expect(appState.tenant.subscriptionEndDate, equals(previousExpiry));
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });
}
