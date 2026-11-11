import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  group('Security & Subscription Enforcement Tests', () {
    test('Privilege Escalation: Standard delivery agent cannot toggle Super Admin mode', () {
      final appState = AppState();
      appState.initForTenant('tenant_abc', 'agent_uid', role: 'distributor');

      expect(appState.isSuperAdminUser, isFalse);
      expect(appState.isSuperAdminMode, isFalse);

      // Standard user attempt must throw StateError
      expect(
        () => appState.toggleSuperAdminMode(true),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Unauthorized: Only Super Admin users can enter Super Admin Console'),
        )),
      );

      // State remains safe
      expect(appState.isSuperAdminMode, isFalse);
    });

    test('Super Admin role allows activating and deactivating Super Admin mode', () {
      final appState = AppState();
      appState.initForTenant('tenant_platform', 'admin_uid', role: 'super_admin');

      expect(appState.isSuperAdminUser, isTrue);
      expect(appState.isSuperAdminMode, isFalse);

      // Super admin can switch
      appState.toggleSuperAdminMode(true);
      expect(appState.isSuperAdminMode, isTrue);

      appState.toggleSuperAdminMode(false);
      expect(appState.isSuperAdminMode, isFalse);
    });

    test('Plan Limit Enforcement: Adding shops beyond maxShops is blocked', () async {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(maxShops: 2);

      // Currently MockData has 4 initial shops, so adding one more must fail
      final newShop = ShopModel(
        shopId: 'SH-TEST-999',
        shopName: 'Exceeding Shop',
        ownerName: 'Test Owner',
        phone: '9876543210',
        address: 'Test Address',
        currentOutstanding: 0.0,
        creditLimit: 50000.0,
      );

      await expectLater(
        appState.addShop(newShop),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('SaaS Plan Limit Exceeded: Your plan allows a maximum of 2 retail shops'),
        )),
      );
    });

    test('Subscription Lifecycle: Orders blocked when subscription is PAUSED, CANCELLED, or EXPIRED', () async {
      final appState = AppState();

      final testOrder = OrderModel(
        orderId: 'ORD-TEST-001',
        shopId: 'SH-001',
        createdByUid: 'agent_1',
        items: [
          TransactionItemSnapshot(
            productId: 'PROD-001',
            productName: 'Atta',
            quantity: 1,
            rate: 100.0,
            taxableAmount: 100.0,
            gstRate: 0.0,
            totalGst: 0.0,
            total: 100.0,
          ),
        ],
        subtotal: 100.0,
        totalGst: 0.0,
        grandTotal: 100.0,
        deliveryNote: 'Cash on delivery',
      );

      // 1. PAUSED account status
      appState.tenant = appState.tenant.copyWith(
        accountStatus: 'paused',
        subscriptionStatus: 'active',
      );
      expect(appState.isAccountPausedOrCancelled, isTrue);
      expect(appState.subscriptionBadgeText, equals('ACCOUNT PAUSED'));
      await expectLater(
        appState.createOrder(testOrder),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Subscription Inactive'),
        )),
      );

      // 2. CANCELLED account status
      appState.tenant = appState.tenant.copyWith(
        accountStatus: 'cancelled',
        subscriptionStatus: 'cancelled',
      );
      expect(appState.isAccountPausedOrCancelled, isTrue);
      expect(appState.subscriptionBadgeText, equals('ACCOUNT CANCELLED'));
      await expectLater(
        appState.createOrder(testOrder),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Subscription Inactive'),
        )),
      );

      // 3. EXPIRED subscription date
      appState.tenant = appState.tenant.copyWith(
        accountStatus: 'active',
        subscriptionStatus: 'expired',
        subscriptionEndDate: DateTime.now().subtract(const Duration(days: 5)),
      );
      expect(appState.isSubscriptionExpired, isTrue);
      expect(appState.subscriptionBadgeText, equals('SUBSCRIPTION EXPIRED'));
      await expectLater(
        appState.createOrder(testOrder),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Subscription Inactive'),
        )),
      );

      // 4. ACTIVE and valid
      appState.tenant = appState.tenant.copyWith(
        accountStatus: 'active',
        subscriptionStatus: 'active',
        subscriptionEndDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(appState.isSubscriptionActive, isTrue);
      expect(appState.subscriptionBadgeText, equals('ACCOUNT ACTIVE'));

      // Order should now succeed without throwing
      final initialOrderCount = appState.orders.length;
      await appState.createOrder(testOrder);
      expect(appState.orders.length, equals(initialOrderCount + 1));
    });

    test('Super Admin Sync: updateTenantStatus, purgeCashHistory, and resetUserAccount mutate state safely', () async {
      final appState = AppState();

      // Initial state
      expect(appState.tenant.subscriptionStatus, anyOf(equals('trial'), equals('active')));

      // 1. Super Admin pauses tenant
      appState.updateTenantStatus('PAUSED');
      expect(appState.tenant.accountStatus, equals('paused'));
      expect(appState.isAccountPausedOrCancelled, isTrue);

      // 2. Super Admin cancels tenant
      appState.updateTenantStatus('CANCELLED');
      expect(appState.tenant.accountStatus, equals('cancelled'));

      // 3. Super Admin approves / activates tenant
      appState.updateTenantStatus('ACTIVE');
      expect(appState.tenant.accountStatus, equals('active'));

      // 4. Super Admin purges cash history
      final initialPayments = appState.payments.length;
      expect(initialPayments, greaterThan(0));
      await appState.purgeCashHistoryForTenant('tenant_default');
      expect(appState.payments.where((p) => p.paymentMode.toLowerCase() == 'cash'), isEmpty);

      // 5. Super Admin resets user account
      await appState.resetUserAccountForTenant('tenant_default');
      expect(appState.orders, isEmpty);
      expect(appState.invoices, isEmpty);
      expect(appState.payments, isEmpty);
      expect(appState.shops.every((s) => s.currentOutstanding == 0.0), isTrue);
    });
  });

  group('MainShell UI Security & Status Widget Tests', () {
    testWidgets('Standard agent sees ACCOUNT ACTIVE badge; settings modal hides Super Admin console tile', (tester) async {
      final appState = AppState();
      appState.initForTenant('tenant_agent_1', 'agent_uid', role: 'distributor');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}, isSuperAdmin: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header Badge
      expect(find.text(appState.subscriptionBadgeText), findsOneWidget);

      // Tap profile header on AppBar to open Profile & Settings screen
      final rawFirm = appState.tenant.firmName ?? 'SalesArmy Agency';
      final profileHeader = find.text(rawFirm.length > 10 ? '${rawFirm.substring(0, 10)}...' : rawFirm);
      expect(profileHeader, findsOneWidget);
      await tester.tap(profileHeader);
      await tester.pumpAndSettle();

      // "Switch to Super Admin Console" tile MUST NOT be visible for standard agent
      expect(find.text('Switch to Super Admin Console'), findsNothing);
    });

    testWidgets('Super Admin user sees Switch to Super Admin Console in settings modal', (tester) async {
      final appState = AppState();
      appState.initForTenant('tenant_admin', 'admin_uid', role: 'super_admin');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}, isSuperAdmin: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Profile & Settings screen via profile header
      final rawAdminFirm = appState.tenant.firmName ?? 'SalesArmy Agency';
      final adminProfileHeader = find.text(rawAdminFirm.length > 10 ? '${rawAdminFirm.substring(0, 10)}...' : rawAdminFirm);
      expect(adminProfileHeader, findsOneWidget);
      await tester.tap(adminProfileHeader);
      await tester.pumpAndSettle();

      // Super Admin tile MUST be visible
      final superAdminTile = find.text('Switch to Super Admin Console');
      await tester.ensureVisible(superAdminTile);
      await tester.pumpAndSettle();
      expect(superAdminTile, findsOneWidget);
    });

    testWidgets('Suspended/Paused subscription renders top alert banner on MainShell', (tester) async {
      final appState = AppState();
      appState.initForTenant('tenant_paused', 'agent_uid', role: 'distributor');
      appState.updateTenantStatus('PAUSED');

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            home: MainShell(onSignOut: () {}, isSuperAdmin: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ACCOUNT PAUSED badge and alert banner
      expect(find.text('ACCOUNT PAUSED'), findsOneWidget);
      expect(
        find.text('Account status: ACCOUNT PAUSED. New order creation and live operations are restricted.'),
        findsOneWidget,
      );
    });
  });
}
