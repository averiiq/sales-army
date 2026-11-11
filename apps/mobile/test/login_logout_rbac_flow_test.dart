import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/features/auth/presentation/screens/login_screen.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';

class _TestGoogleAuthService extends AuthService {
  @override
  Future<GoogleAuthResult?> signInWithGoogle() async {
    return GoogleAuthResult.success(
      uid: 'goog_usr_accountant_001',
      email: 'accountant@agency.com',
      displayName: 'Vikram Accountant',
      role: 'Accountant',
      tenantId: 'tenant_shree_ganesh_traders',
    );
  }
}

void main() {
  group('Login, Logout & RBAC Architectural Tests', () {
    // demoMode is now a const false; retained only as a no-op shim here so
    // the surrounding tests still describe their intent.
    test('AppState.signOutSession() resets credentials, role, staff and tenant state', () {
      final appState = AppState();

      // Configure a dirty session
      appState.initForTenant('tenant_abc', 'usr_123', role: 'distributor');
      appState.setActiveRole('Accountant');
      expect(appState.currentTenantId, 'tenant_abc');
      expect(appState.currentUid, 'usr_123');
      expect(appState.activeRole, 'Accountant');
      expect(appState.activeStaffUser, isNotNull);

      // Sign out
      appState.signOutSession();

      // Verify complete sanitization
      expect(appState.currentTenantId, isNull);
      expect(appState.currentUid, isNull);
      expect(appState.currentUserRole, isNull);
      expect(appState.activeStaffUser, isNull);
      expect(appState.isSuperAdminMode, isFalse);
      expect(appState.activeRole, 'Owner'); // Defaults to clean owner baseline
      expect(appState.tenant.firmName, isNotNull);
    });

    test('AppState.setActiveRole presets correct permissions for all 5 enterprise roles', () {
      final appState = AppState();

      // 1. Owner / Distributor
      appState.setActiveRole('Owner');
      expect(appState.activeRole, 'Owner');
      expect(appState.activeStaffUser, isNull);
      expect(appState.canAccessModule('billing'), isTrue);
      expect(appState.canAccessModule('staff'), isTrue);
      expect(appState.canAccessModule('settings'), isTrue);

      // 2. Accountant
      appState.setActiveRole('Accountant');
      expect(appState.activeRole, 'Accountant');
      expect(appState.activePermissions.billing, isTrue);
      expect(appState.activePermissions.reports, isTrue);
      expect(appState.activePermissions.accounts, isTrue);
      expect(appState.activePermissions.staff, isFalse);
      expect(appState.canAccessModule('billing'), isTrue);
      expect(appState.canAccessModule('reports'), isTrue);
      expect(appState.canAccessModule('accounts'), isTrue);
      expect(appState.canAccessModule('collections'), isTrue);
      expect(appState.canAccessModule('staff'), isFalse);

      // 3. Delivery Staff
      appState.setActiveRole('Delivery Staff');
      expect(appState.activeRole, 'Delivery Staff');
      expect(appState.activePermissions.orders, isTrue);
      expect(appState.activePermissions.billing, isFalse);
      expect(appState.activePermissions.inventory, isFalse);
      expect(appState.activePermissions.reports, isFalse);
      expect(appState.activePermissions.accounts, isFalse);
      expect(appState.activePermissions.staff, isFalse);
      expect(appState.canAccessModule('orders'), isTrue);
      expect(appState.canAccessModule('billing'), isFalse);
      expect(appState.canAccessModule('inventory'), isFalse);

      // 4. Field Sales
      appState.setActiveRole('Field Sales');
      expect(appState.activeRole, 'Field Sales');
      expect(appState.activePermissions.orders, isTrue);
      expect(appState.activePermissions.billing, isTrue);
      expect(appState.activePermissions.products, isTrue);
      expect(appState.activePermissions.inventory, isTrue);
      expect(appState.activePermissions.reports, isFalse);
      expect(appState.activePermissions.accounts, isFalse);
      expect(appState.canAccessModule('orders'), isTrue);
      expect(appState.canAccessModule('billing'), isTrue);
      expect(appState.canAccessModule('reports'), isFalse);

      // 5. Store Manager
      appState.setActiveRole('Store Manager');
      expect(appState.activeRole, 'Store Manager');
      expect(appState.activePermissions.inventory, isTrue);
      expect(appState.activePermissions.products, isTrue);
      expect(appState.activePermissions.purchase, isTrue);
      expect(appState.activePermissions.billing, isFalse);
      expect(appState.activePermissions.orders, isFalse);
      expect(appState.canAccessModule('inventory'), isTrue);
      expect(appState.canAccessModule('purchase'), isTrue);
      expect(appState.canAccessModule('billing'), isFalse);

      // 6. Super Admin
      appState.setActiveRole('super_admin');
      expect(appState.isSuperAdminUser, isTrue);
      expect(appState.canAccessModule('billing'), isTrue);
      expect(appState.canAccessModule('staff'), isTrue);
    });

    testWidgets('MainShell renders active role badge in top AppBar', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Accountant');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active role badge pill is visible in AppBar
      expect(find.text('Accountant'), findsOneWidget);

      // Switch to Delivery Staff
      appState.setActiveRole('Delivery Staff');
      await tester.pumpAndSettle();
      expect(find.text('Delivery Staff'), findsOneWidget);
    });

    testWidgets('ProfileAndSettingsScreen displays Active Role chip and confirms sign out', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Field Sales');
      bool signOutTriggered = false;

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: ProfileAndSettingsScreen(
              initialTab: 0,
              onSignOut: () {
                signOutTriggered = true;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Role chip is visible in header
      expect(find.text('Operating as Field Sales'), findsOneWidget);

      // 2. Scroll down to Log out button
      final logOutFinder = find.text('Log out');
      await tester.scrollUntilVisible(logOutFinder, 300);
      expect(logOutFinder, findsOneWidget);

      // 3. Tap Log out -> confirmation dialog opens
      await tester.tap(logOutFinder);
      await tester.pumpAndSettle();

      expect(find.text('Sign Out?'), findsOneWidget);

      // 4. Confirm Sign Out in dialog
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Sign Out');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(signOutTriggered, isTrue);
      expect(appState.currentUserRole, isNull);
    });

    testWidgets('LoginScreen authenticates and dispatches onRoleLogin via Google login', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? loggedInRole;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: _TestGoogleAuthService(),
            onRoleLogin: (role) {
              loggedInRole = role;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Continue with Google
      final googleBtn = find.text('Continue with Google');
      expect(googleBtn, findsOneWidget);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(loggedInRole, 'Accountant');
    });
  });
}
