import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/subscription_plan_model.dart';

/// Regression: after the v2 plan upgrade, Enterprise lost GST billing
/// ("invoicing") and the app blocked GST bills. Uses the live plan data.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Enterprise (live plan data) can create GST and estimate bills', () {
    final tiers = (jsonDecode(File('test/fixtures_live_plans.json').readAsStringSync()) as List)
        .map((t) => SubscriptionPlanModel.fromMap(Map<String, dynamic>.from(t as Map), (t)['id'].toString()))
        .toList()
        .cast<SubscriptionPlanModel>();
    final app = AppState(loadMockData: true)
      ..currentTenantId = 'tenant_x'
      ..currentUserRole = 'owner';
    app.setSubscriptionPlansForTest(tiers);
    app.updateTenantLocallyForTest(plan: 'enterprise');

    expect(app.currentPlan.id, 'enterprise');
    expect(app.hasFeature('invoicing'), isTrue, reason: 'GST billing');
    expect(app.hasFeature('estimate_bills'), isTrue);
    expect(app.billingBlockReason, isNull);
    expect(app.writeBlockReason(feature: 'invoicing'), isNull);
    expect(() => app.ensureCanWrite(feature: 'invoicing'), returnsNormally);
  });
}
