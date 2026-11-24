import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/admin/data/models/staff_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';
import 'package:salesarmy/features/collections/data/models/expense_model.dart';

/// Plans are the single source of truth: admin-managed capabilities and
/// limits, a signup trial (no free plan), grace days, then read-only.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  AppState onPlan(String planId, {String status = 'active', DateTime? end}) {
    final s = AppState();
    s.tenant = s.tenant.copyWith(
      subscriptionPlanId: planId,
      subscriptionStatus: status,
      subscriptionEndDate: end ?? DateTime.now().add(const Duration(days: 30)),
    );
    return s;
  }

  StaffModel staff(String id) => StaffModel(
        id: id,
        name: 'Staff $id',
        email: '$id@salesarmy.com',
        mobile: '98765432${id.length}',
        role: 'Field Sales',
        permissions: StaffPermissions.fieldSales(),
        createdAt: DateTime.now(),
      );

  ShopModel shop(String id) => ShopModel(shopId: id, shopName: 'Shop $id', ownerName: 'O', phone: '9800000000');
  ProductModel product(String id) =>
      ProductModel(productId: id, name: 'P $id', gstRate: 0, wholesalePrice: 10, retailPrice: 15, stockQuantity: 1);

  group('Signup trial & expiry (no free plan)', () {
    test('1. Startup trial: limits come from the plan', () {
      final s = onPlan('startup', status: 'trial', end: DateTime.now().add(const Duration(days: 14)));
      expect(s.currentPlan.id, 'startup');
      expect(s.isTrial, isTrue);
      expect(s.remainingTrialDays, inInclusiveRange(13, 14));
      expect(s.subscriptionBadgeText, contains('TRIAL ACTIVE'));
      expect(s.maxAllowedProducts, 50);
      expect(s.maxAllowedUsers, 2);
      expect(s.maxAllowedShops, 200);
      expect(s.isReadOnlyMode, isFalse);
    });

    test('2. Trial grace: ended trial keeps working for the admin grace days', () {
      final s = onPlan('startup', status: 'trial', end: DateTime.now().subtract(const Duration(days: 2)));
      s.applyPlanSettingsForTest({'trialGracePeriodDays': 3});
      expect(s.isInTrialGracePeriod, isTrue);
      expect(s.isReadOnlyMode, isFalse);
      expect(s.writeBlockReason(), isNull);

      s.applyPlanSettingsForTest({'trialGracePeriodDays': 1});
      expect(s.isInTrialGracePeriod, isFalse);
      expect(s.isReadOnlyMode, isTrue);
      expect(s.subscriptionBadgeText, contains('READ-ONLY'));
    });

    test('3. Expired = read-only: cannot create, can still collect / view', () async {
      final s = onPlan('grow', status: 'expired');
      expect(s.isReadOnlyMode, isTrue);
      expect(s.hasFeature('order_taking'), isFalse);
      expect(s.hasFeature('collections'), isTrue, reason: 'collecting dues stays open');
      expect(s.hasFeature('reports'), isTrue, reason: 'viewing data stays open');
      expect(s.canAccessModule('orders'), isTrue, reason: 'tabs stay visible to view data');
      expect(s.billingBlockReason, contains('read-only'));
      expect(() => s.ensureCanCreateBills(), throwsA(isA<PlanRestrictionException>()));
      await expectLater(s.addShop(shop('new')), throwsA(isA<PlanRestrictionException>()));
      await expectLater(s.addProduct(product('new')), throwsA(isA<PlanRestrictionException>()));
      expect(
        () => s.addExpense(ExpenseModel(id: 'e1', title: 'Fuel', category: 'Fuel', amount: 10, paymentMode: 'Cash', date: DateTime.now(), createdAt: DateTime.now())),
        throwsA(isA<PlanRestrictionException>()),
      );
    });

    test('4. Old free / freemium rows are treated as ended, never as a plan', () {
      final s = onPlan('free', status: 'freemium');
      expect(s.isSubscriptionExpired, isTrue);
      expect(s.isReadOnlyMode, isTrue);
      expect(s.currentPlan.id, 'startup', reason: 'falls back to the signup plan');
    });

    test('5. Paused accounts are hard-locked (not just read-only)', () {
      final s = onPlan('grow', status: 'suspended');
      expect(s.isAccountPausedOrCancelled, isTrue);
      expect(s.isReadOnlyMode, isFalse);
      expect(s.hasFeature('collections'), isFalse);
      expect(s.writeBlockReason(), contains('paused'));
    });

    test('6. Admin signup settings are picked up', () {
      final s = AppState();
      s.applyPlanSettingsForTest({'defaultPlanId': 'grow', 'defaultTrialDays': 21, 'trialGracePeriodDays': 5});
      expect(s.signupPlanId, 'grow');
      expect(s.signupTrialDays, 21);
      expect(s.trialGraceDays, 5);
      s.applyPlanSettingsForTest({'defaultPlanId': 'free'});
      expect(s.signupPlanId, 'grow', reason: '"free" is never accepted');
    });
  });

  group('Limits from the plan', () {
    test('7. Staff seats', () async {
      final s = onPlan('startup', status: 'trial');
      s.testStaffList = [staff('a'), staff('b')];
      expect(s.limitReason('staff'), isNotNull);
      await expectLater(
        s.addStaff(staff('c')),
        throwsA(isA<PlanRestrictionException>().having((e) => e.message, 'message', contains('Staff Seats Limit Reached'))),
      );
    });

    test('8. Products', () async {
      final s = onPlan('startup', status: 'trial');
      s.testProducts = List.generate(50, (i) => product('P$i'));
      await expectLater(
        s.addProduct(product('over')),
        throwsA(isA<PlanRestrictionException>().having((e) => e.message, 'message', contains('Catalog Product Limit Exceeded'))),
      );
    });

    test('9. Parties', () async {
      final s = onPlan('startup', status: 'trial');
      s.testShops = List.generate(200, (i) => shop('S$i'));
      await expectLater(
        s.addShop(shop('over')),
        throwsA(isA<PlanRestrictionException>().having((e) => e.message, 'message', contains('maximum of 200 retail shops'))),
      );
    });

    test('10. 0 means unlimited', () async {
      final s = onPlan('enterprise');
      expect(s.maxAllowedProducts, 0);
      expect(SubscriptionPlanModel.isUnlimited(s.maxAllowedProducts), isTrue);
      s.testProducts = List.generate(500, (i) => product('P$i'));
      expect(s.limitReason('products'), isNull);
      await s.addProduct(product('one-more'));
      expect(s.products.length, 501);
    });

    test('11. Editing an existing record is never blocked by a limit', () async {
      final s = onPlan('startup', status: 'trial');
      s.testShops = List.generate(200, (i) => shop('S$i'));
      await s.addShop(shop('S5')); // same id -> edit
    });
  });

  group('Capabilities are what the admin ticks', () {
    test('12. Grow and Enterprise defaults', () {
      final grow = onPlan('grow');
      expect(grow.maxAllowedUsers, 5);
      expect(grow.maxAllowedShops, 1000);
      expect(grow.hasFeature('van_stock'), isTrue);
      expect(grow.hasFeature('dynamic_upi_qr'), isTrue);
      expect(grow.hasFeature('fleet_multi_van'), isFalse, reason: 'alias of multi_van');

      final ent = onPlan('enterprise');
      expect(ent.hasFeature('multi_van'), isTrue);
      expect(ent.hasFeature('audit_vault'), isTrue);
    });

    test('13. A capability the admin unticks is locked and hides its module', () {
      final s = onPlan('lite');
      s.setSubscriptionPlansForTest(const [
        SubscriptionPlanModel(id: 'lite', name: 'Lite', monthlyPrice: 49, allowedFeatures: ['order_taking', 'estimate_bills']),
      ]);
      expect(s.hasFeature('order_taking'), isTrue);
      expect(s.hasFeature('invoicing'), isFalse);
      expect(s.hasFeature('collections'), isFalse);
      expect(s.canAccessModule('collections'), isFalse);
      expect(s.canAccessModule('purchases'), isFalse);
      expect(s.canAccessModule('billing'), isTrue);
      expect(s.writeBlockReason(feature: 'purchases'), contains('not included in your Lite plan'));
    });

    test('14. Monthly order cap', () {
      final s = onPlan('tiny');
      s.setSubscriptionPlansForTest(const [
        SubscriptionPlanModel(id: 'tiny', name: 'Tiny', monthlyPrice: 1, maxOrdersPerMonth: 0, allowedFeatures: ['order_taking']),
      ]);
      expect(s.limitReason('orders'), isNull, reason: '0 = unlimited');
    });

    test('15. Plans saved before capabilities v2 keep what the app never locked', () {
      final legacy = SubscriptionPlanModel.fromMap({'id': 'grow', 'name': 'Grow', 'monthlyPrice': 599, 'allowedFeatures': ['invoicing']}, 'grow');
      for (final k in SubscriptionPlanModel.legacyImplicitFeatures) {
        expect(legacy.allowedFeatures, contains(k));
      }
      final v2 = SubscriptionPlanModel.fromMap(
          {'id': 'grow', 'name': 'Grow', 'monthlyPrice': 599, 'allowedFeatures': ['invoicing'], 'featuresVersion': 2}, 'grow');
      expect(v2.allowedFeatures, ['invoicing']);
      expect(v2.toMap()['featuresVersion'], 2);
    });

    test('16. Marketing bullets are never treated as capabilities', () {
      final p = SubscriptionPlanModel.fromMap(
          {'id': 'x', 'name': 'X', 'monthlyPrice': 1, 'features': ['invoicing'], 'featuresVersion': 2}, 'x');
      expect(p.allowedFeatures, isEmpty);
    });

    test('17. Unknown plan id falls back to the signup plan', () {
      final s = onPlan('deleted_plan');
      expect(s.currentPlan.id, 'startup');
      expect(s.planById('GOLD')?.id, 'grow', reason: 'legacy alias');
    });

    test('18. Super admin is never restricted', () {
      final s = onPlan('grow', status: 'expired');
      s.currentUserRole = 'super_admin';
      expect(s.isReadOnlyMode, isFalse);
      expect(s.writeBlockReason(feature: 'audit_vault'), isNull);
      expect(s.hasFeature('multi_van'), isTrue);
    });
  });
}
