import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/features/auth/data/models/user_model.dart';
import 'package:salesarmy/features/admin/data/models/tenant_model.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';

void main() {
  group('SalesArmy Data Models Unit Tests', () {
    test('UserModel serialization and deserialization', () {
      final user = UserModel(
        uid: 'user_123',
        email: 'test@salesarmy.com',
        name: 'Test User',
        role: 'distributor',
        status: 'active',
        tenantId: 'tenant_001',
        createdAt: DateTime(2026, 9, 5),
      );

      final map = user.toMap();
      expect(map['email'], 'test@salesarmy.com');
      expect(map['role'], 'distributor');

      final deserializedUser = UserModel.fromMap(map, 'user_123');
      expect(deserializedUser.uid, 'user_123');
      expect(deserializedUser.email, 'test@salesarmy.com');
    });

    test('TenantModel serialization and deserialization', () {
      final tenant = TenantModel(
        tenantId: 'tenant_001',
        distributorId: 'dist_001',
        ownerUid: 'user_123',
        firmName: 'Demo Distributor',
        gstin: '27GUPTA1234H1Z1',
        createdAt: DateTime(2026, 9, 5),
      );

      final map = tenant.toMap();
      expect(map['firmName'], 'Demo Distributor');
      expect(map['gstin'], '27GUPTA1234H1Z1');

      final deserialized = TenantModel.fromMap(map, 'tenant_001');
      expect(deserialized.tenantId, 'tenant_001');
      expect(deserialized.firmName, 'Demo Distributor');
    });

    test('SubscriptionPlanModel pricing and limits check', () {
      final plan = SubscriptionPlanModel(
        planId: 'growth_plan',
        name: 'Growth Plan',
        description: 'For growing distributors',
        monthlyPrice: 2999.0,
        yearlyPrice: 29990.0,
        maxShops: 500,
        maxUsers: 10,
        allowedFeatures: ['invoicing', 'gst_reports', 'live_tracking'],
        isActive: true,
      );

      expect(plan.monthlyPrice, 2999.0);
      expect(plan.maxShops, 500);
      expect(plan.isActive, isTrue);

      final map = plan.toMap();
      expect(map['name'], 'Growth Plan');

      final deserialized = SubscriptionPlanModel.fromMap(map, 'growth_plan');
      expect(deserialized.planId, 'growth_plan');
      expect(deserialized.monthlyPrice, 2999.0);
    });
  });
}
