import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/features/auth/presentation/screens/login_screen.dart';

class MockGoogleAuthService extends AuthService {
  final GoogleAuthResult? mockResult;
  MockGoogleAuthService({this.mockResult});

  @override
  Future<GoogleAuthResult?> signInWithGoogle() async {
    return mockResult ??
        GoogleAuthResult.success(
          uid: 'goog_usr_777',
          email: 'vikram.accounts@gmail.com',
          displayName: 'Vikram Singhania',
          role: 'Accountant',
          tenantId: 'tenant_shree_ganesh_traders',
        );
  }
}

void main() {
  group('LoginScreen Minimal Three-Option Verification', () {
    testWidgets('Renders only the three requested login options: Email/Password, Email OTP, and Google', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? loggedInRole;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onRoleLogin: (role) {
              loggedInRole = role;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Clean Header
      expect(find.text('SalesArmy'), findsOneWidget);
      expect(find.text('Sign in to access your business operations'), findsOneWidget);

      // 2. Verify ONLY 2 Tabs exist: Password and Email OTP (NO Mobile OTP, NO 1-Tap Access)
      expect(find.text('Password'), findsNWidgets(2)); // Tab and field label
      expect(find.text('Email OTP'), findsOneWidget);
      expect(find.text('Mobile OTP'), findsNothing);
      expect(find.text('1-Tap Access'), findsNothing);

      // 3. Tab 0: Password fields
      expect(find.text('Email Address'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);

      // 4. Verify Google Login Option exists
      expect(find.text('OR'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      // 5. Verify Sign In with Email & Password triggers onRoleLogin
      await tester.enterText(find.byType(TextField).at(0), 'distributor@salesarmy.com');
      await tester.enterText(find.byType(TextField).at(1), 'password123');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();
      expect(loggedInRole, isNotNull);

      // 6. Test Email OTP Tab
      await tester.tap(find.text('Email OTP'));
      await tester.pumpAndSettle();

      // Verify "Send Verification Code" CTA
      expect(find.text('Send Verification Code'), findsOneWidget);
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      // Verify OTP Input and Verify Button are displayed
      expect(find.text('Verification Code'), findsOneWidget);
      expect(find.text('Verify & Sign In'), findsOneWidget);

      // 7. Test Sign Up Mode Switcher
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();

      expect(find.text('Create an account to get started'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget); // Switch back link
    });

    testWidgets('Google Sign-In button handles authentication and enforces no fabricated dummy accounts', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      String? loggedInRole;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: MockGoogleAuthService(),
            onRoleLogin: (role) {
              loggedInRole = role;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Tap Continue with Google
      final googleBtn = find.text('Continue with Google');
      expect(googleBtn, findsOneWidget);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      // 2. Verify no fabricated dummy accounts are rendered
      expect(find.text('Rajesh Traders (Distributor Owner)'), findsNothing);

      // 3. Verify user is authenticated with Accountant role
      expect(loggedInRole, 'Accountant');
    });

    testWidgets('Google Sign-In with Super Admin credentials authenticates Super Admin', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      bool superAdminTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            authService: MockGoogleAuthService(
              mockResult: GoogleAuthResult.success(
                uid: 'super_admin_001',
                email: 'admin@salesarmy.saas',
                displayName: 'Platform Admin',
                role: 'super_admin',
                tenantId: 'platform_tenant',
              ),
            ),
            onDemoSuperAdminLogin: () {
              superAdminTriggered = true;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Google button
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      // Verify Super Admin login triggered
      expect(superAdminTriggered, isTrue);
    });
  });
}
