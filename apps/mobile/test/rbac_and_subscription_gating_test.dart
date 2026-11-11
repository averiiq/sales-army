import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/auth/presentation/screens/login_screen.dart';
import 'package:salesarmy/features/profile/presentation/screens/profile_and_settings_screen.dart';
import 'package:salesarmy/features/dashboard/presentation/screens/distributor_dashboard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise RBAC & Subscription Feature Gating Tests', () {
    testWidgets('1. LoginScreen renders modern Password and Email OTP tabs with Google Sign In', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onRoleLogin: (role) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check modern tabs: Password and Email OTP
      expect(find.text('Password'), findsWidgets);
      expect(find.text('Email OTP'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // Verify obsolete legacy tabs are removed
      expect(find.text('Mobile OTP'), findsNothing);
      expect(find.text('1-Tap Access'), findsNothing);

      // Switch to Email OTP tab
      await tester.tap(find.text('Email OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('2. Profile screen strictly hides sensitive owner actions for non-owner roles (RBAC)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      // Set active role to Delivery Staff
      appState.setActiveRole('Delivery Staff');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Operating as Delivery Staff banner
      expect(find.text('Operating as Delivery Staff'), findsOneWidget);

      // Sensitive Owner sections must NOT be rendered
      expect(find.text('Staff & Team'), findsNothing);
      expect(find.text('Banking and GST'), findsNothing);
      expect(find.text('Reset Account Data'), findsNothing);
      expect(find.text('Delete Account'), findsNothing);
    });

    testWidgets('3. Profile screen renders complete management suite for Owner role', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Owner');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Owner sees all administrative modules
      expect(find.text('Banking and GST'), findsOneWidget);
      expect(find.text('Staff & Team'), findsOneWidget);
      expect(find.text('Reset Account Data'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('4. Free Tier displays PRO / GROW+ badges and triggers upgrade sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Owner');
      // Set Free Tier
      appState.setFreeTier(true);
      expect(appState.isFreeTier, isTrue);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: ProfileAndSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Export Reports row on Free Tier (extra tags cleaned per user request)
      await tester.ensureVisible(find.text('Export Reports & Statements'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Export Reports & Statements'));
      await tester.pumpAndSettle();

      // Verify Subscription Upgrade Sheet opens
      expect(find.text('Unlock Export Reports & Statements'), findsOneWidget);
      expect(find.textContaining('SalesArmy Pro or Grow Plan'), findsOneWidget);
      expect(find.text('View Plans & Upgrade'), findsOneWidget);
    });

    testWidgets('5. DistributorDashboard applies RBAC by strictly removing unauthorized features with zero LOCKED badges', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Delivery Staff');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: DistributorDashboard(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Delivery Staff cannot update in-hand cash
      expect(find.text('Update'), findsNothing);

      // In accordance with enterprise RBAC, zero LOCKED badges must be rendered
      expect(find.text('LOCKED'), findsNothing);

      // Unauthorized functionality is completely removed (Create Bill, Estimated Bill)
      expect(find.text('Create Bill'), findsNothing);
      expect(find.text('Estimated Bill'), findsNothing);

      // Delivery Staff sees role-tailored top bar and permitted action cards
      expect(find.text('VAN ROUTE'), findsOneWidget);
      expect(find.text('Active Dispatches'), findsOneWidget);
      expect(find.text('Delivery Proof'), findsOneWidget);
      expect(find.text('Retailers Directory'), findsOneWidget);
      expect(find.text('Sales Return'), findsOneWidget);
    });

    testWidgets('6. MainShell bottom nav completely removes unauthorized tabs for Delivery Staff (zero locked badges)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      appState.setActiveRole('Delivery Staff');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active role badge rendered in header
      expect(find.text('Delivery Staff'), findsOneWidget);

      // Unauthorized tabs (Bill, Collection) are completely removed from bottom nav
      expect(find.text('Bill'), findsNothing);
      expect(find.text('Collection'), findsNothing);

      // Only authorized tabs are visible
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Parties'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);

      // Navigating between authorized tabs works cleanly
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();
    });
  });
}
