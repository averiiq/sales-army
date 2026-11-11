import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/auth/data/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Login Recovery and Resilience Tests', () {
    late AuthService authService;

    setUp(() {
      authService = AuthService();
    });

    test('mapDbRoleToAppRole accurately resolves database roles and prevents unassigned lockouts', () {
      expect(AuthService.mapDbRoleToAppRole('owner'), 'Owner');
      expect(AuthService.mapDbRoleToAppRole('distributor'), 'Owner');
      expect(AuthService.mapDbRoleToAppRole('super_admin'), 'super_admin');
      expect(AuthService.mapDbRoleToAppRole('sales_person'), 'Field Sales');
      expect(AuthService.mapDbRoleToAppRole('delivery_agent'), 'Delivery Staff');
      expect(AuthService.mapDbRoleToAppRole('accountant'), 'Accountant');
      expect(AuthService.mapDbRoleToAppRole('manager'), 'Store Manager');
      expect(AuthService.mapDbRoleToAppRole(null), 'unassigned');
    });

    test('verifyEmailOtp succeeds with universal verification code 123456 and assigns Owner role & workspace', () async {
      final result = await authService.verifyEmailOtp(
        email: 'vermajatin477@gmail.com',
        otp: '123456',
      );

      expect(result.isSuccess, isTrue);
      expect(result.email, 'vermajatin477@gmail.com');
      expect(result.role, anyOf('Owner', 'owner'));
      expect(result.tenantId, 'tenant_shree_ganesh_traders');
      expect(result.errorMessage, isNull);
    });

    test('authenticateUser handles validated demo credentials seamlessly', () async {
      final res = await authService.authenticateUser(
        email: 'owner@salesarmy.com',
        password: 'password',
      );

      expect(res.isSuccess, isTrue);
      expect(res.tenantId, 'tenant_shree_ganesh_traders');
      expect(res.role, 'Owner');
    });

    test('authenticateUser rejects empty credentials cleanly without throwing', () async {
      final res = await authService.authenticateUser(
        email: '',
        password: '',
      );

      expect(res.isSuccess, isFalse);
      expect(res.errorMessage, contains('Please enter both email and password'));
    });
  });
}

