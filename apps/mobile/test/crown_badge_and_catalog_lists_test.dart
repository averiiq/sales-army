import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/widgets/plan_crown_badge.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Plan crown badge', () {
    final plans = SubscriptionPlanModel.defaultPlans;

    test('colour = cheapest plan that includes the feature', () {
      expect(PlanCrownBadge.lowestPlanFor(plans, 'order_taking')!.id, 'startup');
      expect(PlanCrownBadge.lowestPlanFor(plans, 'van_stock')!.id, 'grow');
      expect(PlanCrownBadge.lowestPlanFor(plans, 'audit_vault')!.id, 'enterprise');
      expect(PlanCrownBadge.lowestPlanFor(plans, 'not_a_feature'), isNull);

      Color c(String f) => PlanCrownBadge.colorsFor(PlanCrownBadge.lowestPlanFor(plans, f)!, plans).$1;
      expect(c('order_taking'), PlanCrownBadge.green);
      expect(c('van_stock'), PlanCrownBadge.purple);
      expect(c('audit_vault'), PlanCrownBadge.gold);
    });

    test('follows the admin: unticking a feature on Startup turns its crown purple', () {
      final edited = [
        plans[0].copyWith(allowedFeatures: plans[0].allowedFeatures.where((f) => f != 'reports').toList()),
        plans[1],
        plans[2],
      ];
      final p = PlanCrownBadge.lowestPlanFor(edited, 'reports')!;
      expect(p.id, 'grow');
      expect(PlanCrownBadge.colorsFor(p, edited).$1, PlanCrownBadge.purple);
    });

    test('custom plan ids are coloured by price rank', () {
      const custom = [
        SubscriptionPlanModel(id: 'basic', name: 'Basic', monthlyPrice: 100, allowedFeatures: ['a']),
        SubscriptionPlanModel(id: 'plus', name: 'Plus', monthlyPrice: 200, allowedFeatures: ['b']),
        SubscriptionPlanModel(id: 'max', name: 'Max', monthlyPrice: 300, allowedFeatures: ['c']),
      ];
      expect(PlanCrownBadge.colorsFor(custom[0], custom).$1, PlanCrownBadge.green);
      expect(PlanCrownBadge.colorsFor(custom[1], custom).$1, PlanCrownBadge.purple);
      expect(PlanCrownBadge.colorsFor(custom[2], custom).$1, PlanCrownBadge.gold);
    });

    testWidgets('renders a text-free badge, nothing for unknown features', (tester) async {
      final appState = AppState();
      await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(body: Row(children: [PlanCrownBadge(feature: 'audit_vault'), PlanCrownBadge(feature: 'nope')])),
        ),
      ));
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(Text), findsNothing);
      expect(find.byTooltip('Enterprise plan'), findsOneWidget);
    });

    testWidgets('crown fades once the bought plan includes the feature, bright again when it ends', (tester) async {
      final appState = AppState()..currentTenantId = 'tenant_test';
      Future<void> pumpBadge() async {
        await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(home: Scaffold(body: PlanCrownBadge(feature: 'audit_vault'))),
        ));
        await tester.pumpAndSettle();
      }

      double opacity() => tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity;

      // Bought Enterprise (includes audit_vault) → faded.
      await tester.runAsync(() => appState.applyServerPlanActivation(
            planId: 'enterprise',
            expiresAt: DateTime.now().add(const Duration(days: 30)),
          ));
      await pumpBadge();
      expect(opacity(), PlanCrownBadge.unlockedOpacity);
      expect(find.byTooltip('Included in your plan'), findsOneWidget);

      // Startup does not include audit_vault → bright.
      await tester.runAsync(() => appState.applyServerPlanActivation(
            planId: 'startup',
            expiresAt: DateTime.now().add(const Duration(days: 30)),
          ));
      await pumpBadge();
      expect(opacity(), 1.0);

      // Enterprise but expired (read-only) → bright again as a renew reminder.
      await tester.runAsync(() => appState.applyServerPlanActivation(
            planId: 'enterprise',
            expiresAt: DateTime.now().subtract(const Duration(days: 10)),
          ));
      await pumpBadge();
      expect(opacity(), 1.0);
    });
  });

  group('Per-account categories & units (nothing predefined)', () {
    test('a fresh account has no categories or units', () {
      final s = AppState();
      s.testProducts = [];
      expect(s.productCategories, isEmpty);
      expect(s.productUnits, isEmpty);
    });

    test('added values are kept, de-duplicated, and saved on the phone', () async {
      final s = AppState();
      s.testProducts = [];
      s.addProductCategory('Beverages');
      s.addProductCategory('beverages');
      s.addProductCategory('All');
      s.addProductUnit('crate');
      s.addProductUnit('Custom');
      expect(s.productCategories, ['Beverages']);
      expect(s.productUnits, ['crate']);
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().any((k) => k.startsWith('salesarmy_catalog_lists_')), isTrue);

      s.removeProductCategory('Beverages');
      expect(s.productCategories, isEmpty);
    });

    test('categories / units already used by products are included', () {
      final s = AppState();
      s.testProducts = [
        ProductModel(
          productId: 'p1',
          name: 'Cola',
          categoryId: 'Drinks',
          gstRate: 0,
          wholesalePrice: 1,
          retailPrice: 1,
          stockQuantity: 1,
          variants: [ProductVariant(size: '1', unit: 'bottle', wholesalePrice: 1, retailPrice: 1, customerPrice: 1, stockQuantity: 1)],
        ),
      ];
      expect(s.productCategories, contains('Drinks'));
      expect(s.productUnits, contains('bottle'));
    });

    test('usage counts block deleting a category / unit that products still use', () {
      final s = AppState();
      s.testProducts = [
        ProductModel(
          productId: 'p1',
          name: 'Cola',
          categoryId: 'Drinks',
          gstRate: 0,
          wholesalePrice: 1,
          retailPrice: 1,
          stockQuantity: 1,
          variants: [ProductVariant(size: '1', unit: 'bottle', wholesalePrice: 1, retailPrice: 1, customerPrice: 1, stockQuantity: 1)],
        ),
      ];
      s.addProductCategory('Snacks');
      s.addProductUnit('box');
      expect(s.productCountForCategory('drinks'), 1);
      expect(s.productCountForUnit('Bottle'), 1);
      expect(s.productCountForCategory('Snacks'), 0);
      expect(s.productCountForUnit('box'), 0);

      // Unused entries really disappear when deleted.
      s.removeProductCategory('Snacks');
      s.removeProductUnit('box');
      expect(s.productCategories, isNot(contains('Snacks')));
      expect(s.productUnits, isNot(contains('box')));
    });
  });
}
