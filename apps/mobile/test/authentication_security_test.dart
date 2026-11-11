import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';
import 'package:salesarmy/features/auth/presentation/screens/login_screen.dart';

class UnavailableGoogleAuth extends AuthService {
  @override
  Future<GoogleAuthResult?> signInWithGoogle() async => throw StateError('Provider unavailable');
}

void main() {
  test('fixed OTPs and demo passwords cannot authenticate without a verified backend', () async {
    final auth = AuthService();
    expect((await auth.authenticateUser(email: 'superadmin@salesarmy.saas', password: 'SAAS-ADMIN-2026')).isSuccess, isFalse);
    for (final otp in ['1234', '123456']) {
      expect((await auth.verifyEmailOtp(email: 'owner@example.test', otp: otp)).isSuccess, isFalse);
    }
    expect(AuthService.mapDbRoleToAppRole(null, 'superadmin@example.test'), 'unassigned');
  });

  testWidgets('Google failure never offers fabricated accounts or dispatches a login callback', (tester) async {
    var loggedIn = false;
    await tester.pumpWidget(MaterialApp(home: LoginScreen(authService: UnavailableGoogleAuth(), onRoleLogin: (_) => loggedIn = true)));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Google sign-in is unavailable'), findsOneWidget);
    expect(find.text('Rajesh Traders (Distributor Owner)'), findsNothing);
    expect(loggedIn, isFalse);
  });
}
