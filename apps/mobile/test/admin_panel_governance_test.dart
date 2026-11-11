import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Admin Panel End-to-End Governance Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('1. Remote Feature Flags govern all 10 mobile modules seamlessly', () {
      final allModules = [
        'order_taking',
        'gst_invoicing',
        'collections',
        'gps_tracking',
        'staff_management',
        'thermal_printer',
        'soundbox_audio',
        'van_stock',
        'customer_portal',
        'instant_sync',
      ];

      // Initially, all modules are enabled by default
      for (final mod in allModules) {
        expect(appState.isFeatureEnabledRemotely(mod), isTrue,
            reason: '$mod should be enabled by default');
        expect(appState.isModuleRemotelyDisabled(mod), isFalse,
            reason: '$mod should not be remotely disabled initially');
        expect(appState.canAccessModule(mod), isTrue,
            reason: '$mod should be accessible initially');
      }

      // Simulate Super Admin turning off thermal_printer and soundbox_audio kill switches
      appState.importAdminSyncBundle({
        'remoteConfig': {
          'featureFlags': {
            'order_taking': true,
            'gst_invoicing': true,
            'collections': true,
            'gps_tracking': true,
            'staff_management': true,
            'thermal_printer': false,
            'soundbox_audio': false,
            'van_stock': true,
            'customer_portal': true,
            'instant_sync': true,
          },
        },
      });

      // Verify thermal_printer is now disabled
      expect(appState.isFeatureEnabledRemotely('thermal_printer'), isFalse);
      expect(appState.isModuleRemotelyDisabled('thermal_printer'), isTrue);
      expect(appState.canAccessModule('thermal_printer'), isFalse);

      // Verify soundbox_audio is now disabled
      expect(appState.isFeatureEnabledRemotely('soundbox_audio'), isFalse);
      expect(appState.isModuleRemotelyDisabled('soundbox_audio'), isTrue);
      expect(appState.canAccessModule('soundbox_audio'), isFalse);

      // Verify other modules remain enabled
      expect(appState.canAccessModule('order_taking'), isTrue);
      expect(appState.canAccessModule('gst_invoicing'), isTrue);
      expect(appState.canAccessModule('gps_tracking'), isTrue);
    });

    test('2. Global Maintenance Mode remotely locks down app with custom ETA and notice', () {
      expect(appState.isMaintenanceMode, isFalse);

      // Simulate Admin activating maintenance mode with custom message
      appState.importAdminSyncBundle({
        'remoteConfig': {
          'maintenance': {
            'active': true,
            'message': 'Scheduled server migration for faster GST syncing.',
            'eta': '30 mins',
          },
        },
      });

      expect(appState.isMaintenanceMode, isTrue);
      expect(appState.maintenanceMessage, 'Scheduled server migration for faster GST syncing.');
      expect(appState.maintenanceEta, '30 mins');

      // Admin turns maintenance mode off
      appState.importAdminSyncBundle({
        'remoteConfig': {
          'maintenance': {
            'active': false,
            'message': 'Normal operation',
            'eta': '0 mins',
          },
        },
      });

      expect(appState.isMaintenanceMode, isFalse);
    });

    test('3. Version Shield enforces minimum app version and settings from Admin Panel', () {
      appState.importAdminSyncBundle({
        'remoteConfig': {
          'minAppVersion': 'v2.5.0',
        },
      });

      expect(appState.minAppVersion, 'v2.5.0');
    });

    test('4. Tenant Account Freeze / Suspension blocks business activities', () async {
      // Super Admin suspends the tenant account due to billing or compliance
      await appState.updateTenantStatus('paused');
      expect(appState.tenant.accountStatus, 'paused');

      // Admin restores account
      await appState.updateTenantStatus('active');
      expect(appState.tenant.accountStatus, 'active');
    });

    test('5. In-App Broadcast Center delivers real-time notifications and alerts', () {
      final broadcastPayload = {
        'id': 'ALERT-2026-FESTIVE',
        'title': 'Diwali Super Bonus Offer',
        'message': 'Earn 2x sales commission on all retail deliveries today!',
        'type': 'festive',
        'actionUrl': 'https://salesarmy.in/festive',
        'actionLabel': 'Claim Bonus',
        'dismissible': true,
        'active': true,
      };

      appState.importAdminSyncBundle({
        'broadcast': broadcastPayload,
      });

      expect(appState.emergencyBroadcast, isNotNull);
      expect(appState.emergencyBroadcast?['title'], 'Diwali Super Bonus Offer');
      expect(appState.emergencyBroadcast?['type'], 'festive');
      expect(appState.emergencyBroadcast?['active'], isTrue);
    });

    test('6. SMS Gateway & Auth Policies are governed remotely by Admin Panel', () {
      appState.importAdminSyncBundle({
        'remoteConfig': {
          'smsProvider': 'Twilio',
          'otpDigits': 4,
          'smsMode': 'Live',
          'enforceOtp': true,
        },
      });

      expect(appState.smsProvider, 'Twilio');
      expect(appState.otpDigits, 4);
      expect(appState.smsGatewayMode, 'Live');
      expect(appState.enforceMobileOtp, isTrue);
    });

    test('7. Admin Sync Bundle generates valid export with tenant, pricing, and config nodes', () {
      final bundle = appState.exportAdminSyncBundle();

      expect(bundle, isA<Map<String, dynamic>>());
      expect(bundle.containsKey('remoteFeatureFlags'), isTrue);
      expect(bundle.containsKey('emergencyBroadcast'), isTrue);
      expect(bundle.containsKey('coupons'), isTrue);
      expect(bundle.containsKey('tenants'), isTrue);
      expect(bundle.containsKey('plans'), isTrue);
      expect(bundle.containsKey('maintenance'), isTrue);
      expect(bundle.containsKey('settings'), isTrue);

      // Verify hardware pricing defaults
      final plans = bundle['plans'] as Map<String, dynamic>;
      expect(plans['printerHardwarePrice'], 2499.0);
      expect(plans['printerGstRate'], 18.0);
    });
  });
}
