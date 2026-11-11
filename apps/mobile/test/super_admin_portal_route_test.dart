import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/admin/presentation/screens/super_admin_login_screen.dart';
import 'package:salesarmy/features/auth/presentation/screens/login_screen.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  group('Super Admin Login & Route Separation Tests', () {
    testWidgets('LoginScreen does NOT contain SaaS Super Admin login option', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LoginScreen(
              onDemoDistributorLogin: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Super Admin Console button MUST NOT be present on LoginScreen
      expect(find.text('1-Tap: Super Admin Console'), findsNothing);
      expect(find.text('Enter Super Admin Console'), findsNothing);
      expect(find.text('RESTRICTED ADMINISTRATIVE GATEWAY'), findsNothing);
      expect(find.text('1-Tap Access'), findsNothing);
    });

    testWidgets('SuperAdminPortalPage renders dedicated Super Admin gateway and logs in', (tester) async {
      tester.view.physicalSize = const Size(1280, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: SuperAdminPortalPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Administrative Gateway branding
      expect(find.text('RESTRICTED ADMINISTRATIVE GATEWAY'), findsOneWidget);
      expect(find.text('SaaS Super Admin Console'), findsOneWidget);
      expect(find.text('Log in to manage platform tenants, subscriptions, gateways and billing.'), findsOneWidget);
      expect(find.text('Super Admin Email'), findsOneWidget);
      expect(find.text('Master Admin Passcode'), findsOneWidget);
      expect(find.text('Enter Super Admin Console'), findsOneWidget);
      expect(find.text('1-Tap: Instant Super Admin Access'), findsOneWidget);
      expect(find.text('Return to Distributor App'), findsOneWidget);

      // Tap 1-Tap Instant Super Admin Access
      await tester.ensureVisible(find.text('1-Tap: Instant Super Admin Access'));
      await tester.tap(find.text('1-Tap: Instant Super Admin Access'));
      await tester.pumpAndSettle();

      // Should now render the SuperAdminConsole
      expect(find.text('SaaS Super Admin'), findsOneWidget);
      expect(find.text('CONSOLE'), findsOneWidget);
      expect(find.text('Subscriber'), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Setting'), findsOneWidget);
    });
  });
}
