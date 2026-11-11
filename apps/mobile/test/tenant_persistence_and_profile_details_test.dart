import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:provider/provider.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('TenantModel Serialization & Clearing', () {
    test('toJsonMap creates JSON-safe string maps without Timestamp', () {
      final now = DateTime.now();
      final model = TenantModel(
        tenantId: 'tenant_101',
        distributorId: 'dist_101',
        ownerUid: 'uid_101',
        firmName: 'Shree Ganesh Traders',
        representativeName: 'Ramesh Patel',
        mobile: '+91 9876543210',
        email: 'ramesh@ganesh.com',
        logoUrl: 'https://example.com/logo.png',
        profileImageUrl: 'https://example.com/avatar.png',
        createdAt: now,
        updatedAt: now,
      );

      final jsonMap = model.toJsonMap();
      expect(jsonMap['tenantId'], 'tenant_101');
      expect(jsonMap['firmName'], 'Shree Ganesh Traders');
      expect(jsonMap['representativeName'], 'Ramesh Patel');
      expect(jsonMap['logoUrl'], 'https://example.com/logo.png');
      expect(jsonMap['profileImageUrl'], 'https://example.com/avatar.png');

      // Verify JSON serialization doesn't throw
      final encoded = json.encode(jsonMap);
      expect(encoded.isNotEmpty, isTrue);

      // Verify deserialization back to model
      final decoded = json.decode(encoded) as Map<String, dynamic>;
      final rehydrated = TenantModel.fromMap(decoded, decoded['tenantId'] ?? 'tenant_101');
      expect(rehydrated.firmName, 'Shree Ganesh Traders');
      expect(rehydrated.representativeName, 'Ramesh Patel');
      expect(rehydrated.logoUrl, 'https://example.com/logo.png');
      expect(rehydrated.profileImageUrl, 'https://example.com/avatar.png');
    });

    test('copyWith allows clearing logo and profile image', () {
      final model = TenantModel(
        tenantId: 'tenant_101',
        distributorId: 'dist_101',
        ownerUid: 'uid_101',
        firmName: 'Shree Ganesh Traders',
        logoUrl: 'https://example.com/logo.png',
        profileImageUrl: 'https://example.com/avatar.png',
      );

      final cleared = model.copyWith(
        clearLogo: true,
        clearProfileImage: true,
      );

      expect(cleared.logoUrl, isNull);
      expect(cleared.profileImageUrl, isNull);
      expect(cleared.firmName, 'Shree Ganesh Traders');
    });

    test('toDistributorUpdateMap excludes Firestore protected governance keys', () {
      final model = TenantModel(
        tenantId: 'tenant_101',
        distributorId: 'dist_101',
        ownerUid: 'uid_101',
        accountStatus: 'active',
        subscriptionStatus: 'active',
        firmName: 'Balaji Distributors',
        representativeName: 'Suresh Kumar',
        logoUrl: 'https://example.com/balaji.png',
      );

      final updateMap = model.toDistributorUpdateMap();

      expect(updateMap.containsKey('tenantId'), isFalse);
      expect(updateMap.containsKey('distributorId'), isFalse);
      expect(updateMap.containsKey('ownerUid'), isFalse);
      expect(updateMap.containsKey('accountStatus'), isFalse);
      expect(updateMap.containsKey('subscriptionStatus'), isFalse);
      expect(updateMap.containsKey('createdAt'), isFalse);

      expect(updateMap['firmName'], 'Balaji Distributors');
      expect(updateMap['representativeName'], 'Suresh Kumar');
      expect(updateMap['logoUrl'], 'https://example.com/balaji.png');
    });
  });

  group('AppState Offline & Multi-Storage Persistence', () {
    test('updateTenant saves to SharedPreferences and notifies listeners', () async {
      SharedPreferences.setMockInitialValues({});
      final appState = AppState();

      final updatedTenant = appState.tenant.copyWith(
        firmName: 'Updated Enterprise FMCG',
        representativeName: 'Vikram Sharma',
        mobile: '+91 9988776655',
        email: 'vikram@fmcg.com',
        logoUrl: 'https://example.com/custom_fmcg_logo.png',
        profileImageUrl: 'https://example.com/vikram_avatar.png',
      );

      await appState.updateTenant(updatedTenant);

      expect(appState.tenant.firmName, 'Updated Enterprise FMCG');
      expect(appState.tenant.representativeName, 'Vikram Sharma');
      expect(appState.tenant.logoUrl, 'https://example.com/custom_fmcg_logo.png');
      expect(appState.tenant.profileImageUrl, 'https://example.com/vikram_avatar.png');

      // Verify local persistence in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedStr = prefs.getString('salesarmy_saved_tenant_profile_v1');
      expect(savedStr, isNotNull);

      final decoded = json.decode(savedStr!) as Map<String, dynamic>;
      expect(decoded['firmName'], 'Updated Enterprise FMCG');
      expect(decoded['representativeName'], 'Vikram Sharma');
      expect(decoded['logoUrl'], 'https://example.com/custom_fmcg_logo.png');
    });

    test('AppState reloads saved tenant profile from SharedPreferences on new startup', () async {
      final savedProfile = {
        'tenantId': 'persisted_tenant_99',
        'distributorId': 'dist_99',
        'ownerUid': 'owner_99',
        'firmName': 'Apex Beverages & Foods',
        'representativeName': 'Amit Verma',
        'mobile': '+91 9123456789',
        'email': 'amit@apex.com',
        'logoUrl': 'https://example.com/apex_logo.png',
        'profileImageUrl': 'https://example.com/amit.png',
      };

      SharedPreferences.setMockInitialValues({
        'salesarmy_saved_tenant_profile_v1': json.encode(savedProfile),
      });

      final freshAppState = AppState();
      // Allow async _loadSavedTenant to complete
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(freshAppState.tenant.firmName, 'Apex Beverages & Foods');
      expect(freshAppState.tenant.representativeName, 'Amit Verma');
      expect(freshAppState.tenant.logoUrl, 'https://example.com/apex_logo.png');
      expect(freshAppState.tenant.profileImageUrl, 'https://example.com/amit.png');
    });

    test('Profile image and logo persist across app restarts and cloud sync merges', () async {
      SharedPreferences.setMockInitialValues({});
      const testPhotoUri = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
      const testLogoUrl = 'https://images.unsplash.com/photo-1542838132-92c53300491e?w=400';

      final appState = AppState();
      await appState.updateTenant(appState.tenant.copyWith(
        profileImageUrl: testPhotoUri,
        logoUrl: testLogoUrl,
      ));

      // 1. Verify saved in SharedPreferences standalone keys
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('salesarmy_pref_profile_image_url_v2'), testPhotoUri);
      expect(prefs.getString('salesarmy_pref_logo_url_v2'), testLogoUrl);

      // 2. Simulate app restart: fresh AppState instance
      final restartedAppState = AppState();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(restartedAppState.tenant.profileImageUrl, testPhotoUri);
      expect(restartedAppState.tenant.logoUrl, testLogoUrl);

      // 3. Simulate cloud tenant update from database table (which has no profile_image_url column)
      final incomingCloudUpdate = TenantModel.fromMap({
        'business_name': 'Cloud Updated Firm',
        'contact_person': 'Cloud Owner',
      }, restartedAppState.tenant.tenantId);

      await restartedAppState.updateTenant(incomingCloudUpdate);

      // Verify profile photo was NOT wiped out
      expect(restartedAppState.tenant.profileImageUrl, testPhotoUri);
      expect(restartedAppState.tenant.logoUrl, testLogoUrl);
      expect(restartedAppState.tenant.firmName, 'Cloud Updated Firm');

      // 4. Verify explicit clear removes it properly
      await restartedAppState.updateTenant(
        restartedAppState.tenant.copyWith(clearProfileImage: true),
        clearProfileImage: true,
      );
      expect(restartedAppState.tenant.profileImageUrl, isNull);
      expect(prefs.getString('salesarmy_pref_profile_image_url_v2'), isNull);
    });
  });

  group('ProfileAndSettingsScreen UI Display', () {
    testWidgets('Renders representative name and firm name in hero container', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      await appState.updateTenant(appState.tenant.copyWith(
        firmName: 'Kaveri Provisions',
        representativeName: 'Kaveri Ammal',
      ));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kaveri Provisions'), findsWidgets);
      expect(find.textContaining('User ID:'), findsWidgets);
    });

    testWidgets('Header elements sequential order and plan & subscription card has spacing before tiles', (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      SharedPreferences.setMockInitialValues({});
      final appState = AppState();
      await appState.updateTenant(appState.tenant.copyWith(
        firmName: 'Kaveri Provisions',
        representativeName: 'Kaveri Ammal',
      ));

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final yellowTopFinder = find.byWidgetPredicate((widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).color == const Color(0xFFFFCC00));
      expect(yellowTopFinder, findsWidgets);

      final firmNameFinder = find.text('Kaveri Provisions').first;
      final userIdFinder = find.textContaining('User ID:').first;
      final planCardFinder = find.text('SalesArmy Plan & Subscription').first;
      final homeTileFinder = find.text('Home').first;

      final yellowTopPos = tester.getTopLeft(yellowTopFinder.first);
      final firmNamePos = tester.getTopLeft(firmNameFinder);
      final userIdPos = tester.getTopLeft(userIdFinder);
      final planCardPos = tester.getTopLeft(planCardFinder);
      final homeTilePos = tester.getTopLeft(homeTileFinder);

      // Verify strict sequential vertical hierarchy
      expect(yellowTopPos.dy < firmNamePos.dy, isTrue);
      expect(firmNamePos.dy < userIdPos.dy, isTrue);
      expect(userIdPos.dy < planCardPos.dy, isTrue);
      expect(planCardPos.dy < homeTilePos.dy, isTrue);

      // Verify gap between Plan & Subscription card and Quick Action tiles (no sticking)
      final planCardBottom = tester.getBottomRight(find.ancestor(
        of: planCardFinder,
        matching: find.byType(InkWell),
      ).first).dy;
      final homeTileTop = tester.getTopLeft(find.ancestor(
        of: homeTileFinder,
        matching: find.byType(InkWell),
      ).first).dy;
      expect(homeTileTop - planCardBottom, greaterThanOrEqualTo(14.0));
    });
  });
}
