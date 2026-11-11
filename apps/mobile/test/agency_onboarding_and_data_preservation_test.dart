import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Agency Onboarding and Data Preservation Tests', () {
    test('AppState initializes with mock data and never leaves tenant empty', () async {
      final appState = AppState(loadMockData: true);

      // Verify shops and products are preserved and populated
      expect(appState.shops.isNotEmpty, isTrue);
      expect(appState.products.isNotEmpty, isTrue);
      expect(appState.orders.isNotEmpty, isTrue);

      // Verify default tenant
      expect(appState.tenant.tenantId, equals('tenant_shree_ganesh_traders'));
    });

    test('AppState initForTenant preserves starter data for new tenants', () async {
      final appState = AppState(loadMockData: true);

      appState.initForTenant('tenant_new_test_agency', 'usr_test_123', role: 'Owner');

      expect(appState.currentTenantId, equals('tenant_new_test_agency'));
      expect(appState.shops.isNotEmpty, isTrue);
      expect(appState.products.isNotEmpty, isTrue);
    });

    test('SupabaseService registerAgencyOwnerAndSeed handles agency creation and data provision', () async {
      final supabaseService = SupabaseService.instance;

      final result = await supabaseService.registerAgencyOwnerAndSeed(
        businessName: 'Apex FMCG Distributors',
        representativeName: 'Apex Director',
        email: 'apex.director@gmail.com',
        password: 'password123',
        phone: '+91 99887 76655',
        city: 'Pune',
      );

      expect(result['success'], isTrue);
      expect(result['tenantId'], isNotNull);
      expect(result['uid'], isNotNull);
      expect(result['tenantId'].toString(), startsWith('tenant_'));
    });
  });
}
