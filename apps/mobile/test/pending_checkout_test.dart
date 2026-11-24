import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('saved checkout remembers its plan, and can be cleared', () async {
    final app = AppState(loadMockData: true)..currentTenantId = 'tenant_test';
    await app.savePendingCheckout(id: 'abc', planId: 'grow');
    expect(await app.readPendingCheckout(), {'id': 'abc', 'planId': 'grow'});
    await app.clearPendingCheckout();
    expect(await app.readPendingCheckout(), isNull);
  });

  test('checkout id saved by older builds (plain string) is still read', () async {
    final app = AppState(loadMockData: true)..currentTenantId = 'tenant_test';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppState.pendingCheckoutKey(app.currentTenantId ?? app.tenant.tenantId), 'legacy-id');
    expect(await app.readPendingCheckout(), {'id': 'legacy-id', 'planId': ''});
  });

  test('server-confirmed activation unlocks billing on this phone immediately', () async {
    final app = AppState(loadMockData: true);
    final end = DateTime.now().add(const Duration(days: 30));
    await app.applyServerPlanActivation(planId: 'enterprise', expiresAt: end);
    expect(app.tenant.subscriptionPlanId, 'enterprise');
    expect(app.tenant.subscriptionStatus, 'active');
    expect(app.isReadOnlyMode, isFalse);
    expect(app.billingBlockReason, isNull);
  });
}
