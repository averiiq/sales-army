import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/supabase_service.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';

void main() {
  test('Test Supabase login for real seeded accounts', () async {
    HttpOverrides.global = null;
    await SupabaseService.instance.initialize();
    final authService = AuthService();

    final testAccounts = [
      'superadmin@salesarmy.saas',
      'owner@salesarmy.com',
      'distributor@salesarmy.com',
      'sales@salesarmy.com',
      'accountant@salesarmy.com',
    ];

    for (final email in testAccounts) {
      final result = await authService.authenticateUser(
        email: email,
        password: 'Password@123',
      );
      // ignore: avoid_print
      print('[$email] isSuccess: ${result.isSuccess}, role: ${result.role}, tenantId: ${result.tenantId}, error: ${result.errorMessage}');
      expect(result.isSuccess, true, reason: 'Failed to authenticate $email: ${result.errorMessage}');
    }
  });
}
