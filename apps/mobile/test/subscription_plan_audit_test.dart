import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/admin/data/models/staff_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Comprehensive SaaS Plan & Subscription Deep Audit Tests', () {
    test('1. Default Signup Plan is Startup Tier with 14-Day Free Trial', () {
      final appState = AppState();
      
      // Configure newly registered tenant with startup defaults
      final now = DateTime.now();
      final trialExpiry = now.add(const Duration(days: 14));
      
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'startup',
        subscriptionStatus: 'trial',
        subscriptionEndDate: trialExpiry,
        maxUsers: 1,
        maxShops: 200,
      );

      expect(appState.currentPlan.id, equals('startup'));
      expect(appState.isTrial, isTrue);
      expect(appState.remainingTrialDays, greaterThanOrEqualTo(13));
      expect(appState.remainingTrialDays, lessThanOrEqualTo(14));
      expect(appState.subscriptionBadgeText, contains('TRIAL ACTIVE'));
      expect(appState.maxAllowedProducts, equals(50));
      expect(appState.maxAllowedUsers, equals(1));
      expect(appState.maxAllowedShops, equals(200));
    });

    test('2. Startup Plan Quota: Adding staff beyond 1 is blocked', () async {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'startup',
        subscriptionStatus: 'trial',
      );

      // Pre-fill staff list to 1 (Proprietor / First seat filled)
      appState.testStaffList = [
        StaffModel(
          id: 'staff_1',
          name: 'First Staff',
          email: 'first@salesarmy.com',
          mobile: '9876543210',
          role: 'Field Sales',
          permissions: StaffPermissions.fieldSales(),
          createdAt: DateTime.now(),
        ),
      ];

      final extraStaff = StaffModel(
        id: 'staff_2',
        name: 'Second Staff (Exceeding)',
        email: 'second@salesarmy.com',
        mobile: '9876543211',
        role: 'Delivery Staff',
        permissions: StaffPermissions.delivery(),
        createdAt: DateTime.now(),
      );

      await expectLater(
        appState.addStaff(extraStaff),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Staff Seats Limit Reached'),
        )),
      );
    });

    test('3. Startup Plan Quota: Adding products beyond 50 is blocked', () async {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'startup',
        subscriptionStatus: 'trial',
      );

      // Seed 50 products
      final fiftyProducts = List.generate(
        50,
        (i) => ProductModel(
          productId: 'PROD-$i',
          name: 'Product $i',
          gstRate: 0.0,
          wholesalePrice: 10.0,
          retailPrice: 15.0,
          stockQuantity: 100,
        ),
      );
      appState.testProducts = fiftyProducts;

      final extraProduct = ProductModel(
        productId: 'PROD-EXCEED',
        name: 'Product 51 (Exceeding)',
        gstRate: 0.0,
        wholesalePrice: 10.0,
        retailPrice: 15.0,
        stockQuantity: 100,
      );

      await expectLater(
        appState.addProduct(extraProduct),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Catalog Product Limit Exceeded'),
        )),
      );
    });

    test('4. Startup Plan Quota: Adding shops beyond 200 is blocked', () async {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'startup',
        subscriptionStatus: 'trial',
      );

      // Seed 200 shops
      final twoHundredShops = List.generate(
        200,
        (i) => ShopModel(
          shopId: 'SH-$i',
          shopName: 'Shop $i',
          ownerName: 'Owner $i',
          phone: '98000000$i',
          address: 'Address $i',
          currentOutstanding: 0.0,
          creditLimit: 50000.0,
        ),
      );
      appState.testShops = twoHundredShops;

      final extraShop = ShopModel(
        shopId: 'SH-EXCEED',
        shopName: 'Shop 201 (Exceeding)',
        ownerName: 'Exceeding Owner',
        phone: '9800009999',
        address: 'Exceeding Address',
        currentOutstanding: 0.0,
        creditLimit: 50000.0,
      );

      await expectLater(
        appState.addShop(extraShop),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('SaaS Plan Limit Exceeded: Your plan allows a maximum of 200 retail shops'),
        )),
      );
    });

    test('5. Upgrading to Grow Plan expands quotas to 200 products, 5 staff, 1000 shops', () {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'grow',
        subscriptionStatus: 'active',
      );

      expect(appState.currentPlan.id, equals('grow'));
      expect(appState.maxAllowedProducts, equals(200));
      expect(appState.maxAllowedUsers, equals(5));
      expect(appState.maxAllowedShops, equals(1000));
      expect(appState.canAccessFeatureBySubscription('van_stock'), isTrue);
      expect(appState.canAccessFeatureBySubscription('dynamic_upi_qr'), isTrue);
      expect(appState.canAccessFeatureBySubscription('fleet_multi_van'), isFalse);
    });

    test('6. Upgrading to Enterprise Plan unlocks unlimited scale and fleet features', () {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'enterprise',
        subscriptionStatus: 'active',
      );

      expect(appState.currentPlan.id, equals('enterprise'));
      expect(appState.maxAllowedProducts, equals(9999));
      expect(appState.maxAllowedUsers, equals(50));
      expect(appState.maxAllowedShops, equals(10000));
      expect(appState.canAccessFeatureBySubscription('van_stock'), isTrue);
      expect(appState.canAccessFeatureBySubscription('fleet_multi_van'), isTrue);
      expect(appState.canAccessFeatureBySubscription('audit_vault'), isTrue);
    });

    test('7. Freemium Guarantee: Core Invoicing and Rough Bills are never restricted', () {
      final appState = AppState();

      // Even on startup trial or expired trial
      appState.tenant = appState.tenant.copyWith(
        subscriptionPlanId: 'startup',
        subscriptionStatus: 'trial',
      );

      expect(appState.canAccessFeatureBySubscription('order_taking'), isTrue);
      expect(appState.canAccessFeatureBySubscription('gst_invoicing'), isTrue);
      expect(appState.canAccessFeatureBySubscription('estimate_bills'), isTrue);
      expect(appState.canAccessFeatureBySubscription('thermal_printing'), isTrue);
      expect(appState.canAccessFeatureBySubscription('offline_outbox'), isTrue);
    });
  });
}
