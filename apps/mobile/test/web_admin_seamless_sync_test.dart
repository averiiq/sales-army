import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/coupon_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Web Admin & Mobile App Seamless Interoperability Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('1. The app has no built-in coupon codes (only admin-panel coupons, checked by the server)', () {
      for (final code in ['TRIAL30', 'TRIAL14', 'FLAT100', 'SAVE200', 'WELCOME50', 'FESTIVE25', 'FREE100', 'DEMO1MONTH', 'FREE1WEEK', 'DEMO1DAY', 'SAVE50']) {
        expect(appState.findCoupon(code), isNull, reason: 'Built-in code $code must not exist any more');
      }
      expect(appState.coupons, isEmpty);
    });

    test('2. Coupon discounts are computed correctly for each coupon type', () async {
      // Server-confirmed coupons arrive as maps (same shape as /api/checkout/coupon)
      final trial = CouponModel.fromMap({'code': 'promo70', 'type': 'trial', 'value': 30, 'title': '30 days'});
      expect(trial.code, 'PROMO70');
      expect(trial.calculateDiscount(899.0), 899.0);
      expect(trial.trialDays, 30);
      final flat = CouponModel.fromMap({'code': 'FLAT100', 'type': 'flat', 'value': 100, 'minAmount': 300});
      expect(flat.calculateDiscount(499.0), 100.0);
      expect(flat.calculateDiscount(299.0), 0.0, reason: 'below the minimum order value');
      final half = CouponModel.fromMap({'code': 'HALF', 'type': 'percentage', 'value': 50});
      expect(half.calculateDiscount(899.0), 449.5);

      // Without a signed-in session the server cannot confirm a code, so nothing is applied
      final error = await appState.applyCoupon('PROMO70', planId: 'startup', yearly: false);
      expect(error, isNotNull);
      expect(appState.appliedCoupon, isNull);

      appState.clearAppliedCoupon();
      expect(appState.appliedCoupon, isNull);
    });

    test('3. Unique User ID follows SA-USR-XXXX convention used in Web Admin', () {
      expect(appState.uniqueUserId, startsWith('SA-USR-'));
      expect(appState.uniqueUserId, 'SA-USR-8821');

      appState.setUniqueUserId('SA-USR-9999');
      expect(appState.uniqueUserId, 'SA-USR-9999');
    });

    test('4. exportAdminSyncBundle outputs complete format compatible with Web Admin', () {
      final bundle = appState.exportAdminSyncBundle();

      expect(bundle.containsKey('exportTimestamp'), isTrue);
      expect(bundle['platform'], contains('SalesArmy'));
      expect(bundle['coupons'], isA<List>());
      expect(bundle['plans'], isA<Map>());
      expect(bundle['settings'], isA<Map>());

      final plans = bundle['plans'] as Map<String, dynamic>;
      expect(plans['monthlyPlanPrice'], 899.0);
      expect(plans['annualPlanPrice'], 599.0);
      expect(plans['printerHardwarePrice'], 2499.0);
    });

    test('5. importAdminSyncBundle correctly ingests Web Admin bundle payload', () {
      final webAdminBundle = {
        'exportTimestamp': '2026-09-27T12:00:00Z',
        'platform': 'SalesArmy Monorepo Sync Engine',
        'coupons': [
          {
            'code': 'SPECIAL99',
            'type': 'flat',
            'value': 99.0,
            'title': 'Flash Special ₹99 Off',
            'description': 'Created via Web Admin sync',
            'minAmount': 200.0,
            'isActive': true,
          }
        ],
        'plans': {
          'silverPrice': 449.0,
          'platinumPrice': 4788.0,
          'planGst': 18.0,
          'printerPrice': 2499.0,
          'printerGst': 18.0,
          'applyGstOnInvoices': true,
        },
        'settings': {
          'maintenanceMode': true,
        }
      };

      appState.importAdminSyncBundle(webAdminBundle);

      // Verify imported coupon is now available
      final newCoupon = appState.findCoupon('SPECIAL99');
      expect(newCoupon, isNotNull);
      expect(newCoupon!.code, 'SPECIAL99');
      expect(newCoupon.value, 99.0);

      // Verify imported plan pricing
      expect(appState.monthlyPlanPrice, 449.0);
      expect(appState.annualPlanPrice, 399.0); // 4788 / 12 = 399
      expect(appState.printerHardwarePrice, 2499.0);

      // Verify maintenance mode
      expect(appState.isMaintenanceMode, isTrue);
    });

    test('6. Remote feature flags kill switches disable mobile modules via canAccessModule', () {
      // By default, features are enabled
      expect(appState.isFeatureEnabledRemotely('order_taking'), isTrue);
      expect(appState.canAccessModule('orders'), isTrue);

      // Super Admin remotely pauses order taking module
      appState.updateRemoteFeatureFlags({'order_taking': false});
      expect(appState.isFeatureEnabledRemotely('order_taking'), isFalse);
      expect(appState.canAccessModule('orders'), isFalse);

      // Super Admin remotely pauses collections module
      appState.updateRemoteFeatureFlags({'collections': false});
      expect(appState.isFeatureEnabledRemotely('collections'), isFalse);
      expect(appState.canAccessModule('accounts'), isFalse);

      // Super Admin re-enables order taking and collections
      appState.updateRemoteFeatureFlags({'order_taking': true, 'collections': true});
      expect(appState.canAccessModule('orders'), isTrue);
      expect(appState.canAccessModule('accounts'), isTrue);
    });

    test('7. Emergency broadcast banner can be dynamically dispatched and dismissed', () {
      expect(appState.emergencyBroadcast, isNull);
      expect(appState.isAnnouncementDismissed, isFalse);

      // Super Admin sends festive emergency broadcast
      appState.setEmergencyBroadcast({
        'active': true,
        'id': 'festive_2026',
        'title': '🎉 Diwali Mega Flash Offer',
        'message': 'Get 25% extra credits on all renewals today with code FESTIVE25.',
        'type': 'festive',
        'dismissible': true,
        'actionText': 'Claim Now',
      });

      expect(appState.emergencyBroadcast!['title'], contains('Diwali'));
      expect(appState.isAnnouncementDismissed, isFalse);

      // User dismisses announcement
      appState.dismissAnnouncement();
      expect(appState.isAnnouncementDismissed, isTrue);

      // Admin sends critical warning announcement (resets dismissed state)
      appState.setEmergencyBroadcast({
        'active': true,
        'id': 'gst_warning',
        'title': '⚠️ GST Portal Downtime Notice',
        'message': 'Government GST API will be down tonight from 11 PM to 2 AM.',
        'type': 'critical',
        'dismissible': false,
      });

      expect(appState.isAnnouncementDismissed, isFalse);
      expect(appState.emergencyBroadcast!['type'], 'critical');
    });

    test('8. Full remote app control payload roundtrips through export/importAdminSyncBundle', () {
      appState.setMaintenanceDetails(
        isMaintenance: true,
        message: 'Upgrading database storage cluster.',
        eta: '45 mins',
      );
      appState.updateRemoteFeatureFlags({'gps_tracking': false, 'soundbox_audio': true});

      final bundle = appState.exportAdminSyncBundle();
      expect(bundle['remoteFeatureFlags']['gps_tracking'], isFalse);
      expect(bundle['maintenance']['active'], isTrue);
      expect(bundle['maintenance']['message'], 'Upgrading database storage cluster.');
      expect(bundle['maintenance']['eta'], '45 mins');

      // Create new AppState and import
      final freshAppState = AppState();
      freshAppState.importAdminSyncBundle(bundle);

      expect(freshAppState.isFeatureEnabledRemotely('gps_tracking'), isFalse);
      expect(freshAppState.isMaintenanceMode, isTrue);
      expect(freshAppState.maintenanceMessage, 'Upgrading database storage cluster.');
      expect(freshAppState.maintenanceEta, '45 mins');
    });

    test('9. Remote kill switch immediately disables purchases, expenses, reports, and thermal printing', () {
      expect(appState.canAccessModule('purchase'), isTrue);
      expect(appState.canAccessModule('expense'), isTrue);
      expect(appState.canAccessModule('reports'), isTrue);
      expect(appState.isFeatureEnabledRemotely('thermal_printer'), isTrue);

      // Super Admin remotely flips kill switches
      appState.updateRemoteFeatureFlags({
        'purchases': false,
        'expenses': false,
        'reports': false,
        'thermal_printer': false,
      });

      expect(appState.canAccessModule('purchase'), isFalse);
      expect(appState.canAccessModule('expense'), isFalse);
      expect(appState.canAccessModule('reports'), isFalse);
      expect(appState.canAccessModule('thermal_printer'), isFalse);

      // Super Admin restores purchases and thermal printer
      appState.updateRemoteFeatureFlags({
        'purchases': true,
        'thermal_printer': true,
      });

      expect(appState.canAccessModule('purchase'), isTrue);
      expect(appState.canAccessModule('thermal_printer'), isTrue);
      expect(appState.canAccessModule('expense'), isFalse);
    });

    test('10. Web Admin subscriber tenant governance controls mobile subscription tier and status', () {
      appState.tenant = appState.tenant.copyWith(subscriptionStatus: 'active');
      expect(appState.tenant.subscriptionStatus, 'active');

      // Admin suspends tenant via sync bundle
      final suspensionBundle = {
        'tenants': [
          {
            'id': appState.tenant.tenantId,
            'subscriptionStatus': 'suspended',
            'subscriptionPlanId': 'startup',
          }
        ]
      };
      appState.importAdminSyncBundle(suspensionBundle);
      expect(appState.tenant.subscriptionStatus, 'suspended');

      // Admin upgrades tenant to Enterprise active tier
      final upgradeBundle = {
        'tenants': [
          {
            'id': appState.tenant.tenantId,
            'subscriptionStatus': 'active',
            'subscriptionPlanId': 'enterprise',
          }
        ]
      };
      appState.importAdminSyncBundle(upgradeBundle);
      expect(appState.tenant.subscriptionStatus, 'active');
      expect(appState.tenant.subscriptionPlanId, 'enterprise');
    });
  });
}
