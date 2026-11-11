import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Party (Shop) Persistence & Cloud Sync Verification', () {
    test('1. Created shop persists to local storage and survives app close/relaunch', () async {
      final appState = AppState(loadMockData: false);
      const testTenantId = 'tenant_party_persistence_test';
      const testUid = 'usr_party_test_1';

      appState.initForTenant(testTenantId, testUid, role: 'Owner');

      final newShop = ShopModel(
        shopId: 'shop_persist_001',
        shopName: 'Balaji Supermarket',
        ownerName: 'Balaji Rao',
        phone: '9876543210',
        businessType: 'Supermarket',
        address: 'MG Road, Pune',
        creditLimit: 50000.0,
        currentOutstanding: 0.0,
      );

      // Add shop
      await appState.addShop(newShop);
      expect(appState.shops.any((s) => s.shopId == 'shop_persist_001'), isTrue);

      // Simulate App Close & Relaunch by creating a new AppState instance and initializing same tenant
      final relaunchedAppState = AppState(loadMockData: false);
      relaunchedAppState.initForTenant(testTenantId, testUid, role: 'Owner');

      // Allow async local storage load to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify the shop is preserved across app restart
      expect(relaunchedAppState.shops.any((s) => s.shopId == 'shop_persist_001'), isTrue);
      final restoredShop = relaunchedAppState.shops.firstWhere((s) => s.shopId == 'shop_persist_001');
      expect(restoredShop.shopName, 'Balaji Supermarket');
      expect(restoredShop.ownerName, 'Balaji Rao');
      expect(restoredShop.creditLimit, 50000.0);
    });

    test('2. Updating shop persists updated fields across reload', () async {
      final appState = AppState(loadMockData: false);
      const testTenantId = 'tenant_party_update_test';
      const testUid = 'usr_party_test_2';

      appState.initForTenant(testTenantId, testUid, role: 'Owner');

      final shop = ShopModel(
        shopId: 'shop_update_002',
        shopName: 'Krishna Provision Store',
        ownerName: 'Krishna Murthy',
        phone: '9811122233',
        businessType: 'Kirana',
        address: 'Station Road',
        creditLimit: 20000.0,
        currentOutstanding: 5000.0,
      );

      await appState.addShop(shop);

      // Update shop outstanding and address
      final updatedShop = shop.copyWith(
        address: 'Station Road Near Platform 1',
        currentOutstanding: 2500.0,
      );
      await appState.updateShop(updatedShop);

      // Simulate App Close & Relaunch
      final relaunchedAppState = AppState(loadMockData: false);
      relaunchedAppState.initForTenant(testTenantId, testUid, role: 'Owner');
      await Future.delayed(const Duration(milliseconds: 100));

      final restored = relaunchedAppState.shops.firstWhere((s) => s.shopId == 'shop_update_002');
      expect(restored.address, 'Station Road Near Platform 1');
      expect(restored.currentOutstanding, 2500.0);
    });
  });
}

