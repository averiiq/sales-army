import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/navigation/main_shell.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';

Map<String, dynamic> banner({String tenant = 'all', String plan = 'all', bool dismissible = true, String stamp = '2026-11-26T10:00:00Z'}) => {
      'active': true,
      'title': 'Diwali offer',
      'message': '20% off Grow',
      'severity': 'festive',
      'type': 'info', // stale legacy value must not win
      'targetTenant': tenant,
      'targetPlan': plan,
      'targetRole': plan, // the admin console mirrors plan into targetRole
      'dismissible': dismissible,
      'updatedAt': stamp,
    };

AppState signedIn({String tenant = 'tenant_a', String plan = 'grow'}) {
  final s = AppState(loadMockData: true)
    ..currentTenantId = tenant
    ..currentUid = 'user_1'
    ..currentUserRole = 'owner';
  s.updateTenantLocallyForTest(plan: plan);
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Admin broadcast targeting', () {
    test('everyone sees an "all agencies" banner', () {
      final s = signedIn()..setEmergencyBroadcast(banner());
      expect(s.showBroadcastBanner, isTrue);
    });

    test('a banner for another agency is hidden; for mine it shows', () {
      expect((signedIn()..setEmergencyBroadcast(banner(tenant: 'tenant_b'))).showBroadcastBanner, isFalse);
      expect((signedIn()..setEmergencyBroadcast(banner(tenant: 'tenant_a'))).showBroadcastBanner, isTrue);
    });

    test('plan targeting', () {
      expect((signedIn(plan: 'grow')..setEmergencyBroadcast(banner(plan: 'enterprise'))).showBroadcastBanner, isFalse);
      expect((signedIn(plan: 'enterprise')..setEmergencyBroadcast(banner(plan: 'enterprise'))).showBroadcastBanner, isTrue);
    });

    test('inbox rows: own agency and platform broadcasts yes, other agency / other role no', () {
      final s = signedIn();
      expect(s.isTargetedToMe({'tenant_id': null, 'is_broadcast': true, 'target_role': 'all'}), isTrue);
      expect(s.isTargetedToMe({'tenant_id': 'tenant_a', 'target_role': 'all'}), isTrue);
      expect(s.isTargetedToMe({'tenant_id': 'tenant_b', 'target_role': 'all'}), isFalse);
      expect(s.isTargetedToMe({'tenant_id': 'tenant_a', 'target_role': 'accountant'}), isFalse);
      expect(s.isTargetedToMe({'tenant_id': null, 'is_broadcast': true, 'data': {'targetPlan': 'startup'}}), isFalse);
    });
  });

  group('Banner dismissal', () {
    test('stays dismissed when the same banner re-syncs; a new banner shows again', () async {
      final s = signedIn()..setEmergencyBroadcast(banner());
      s.dismissAnnouncement();
      await Future<void>.delayed(Duration.zero);

      // Same banner arrives again (app restart / re-sync).
      final again = signedIn()..setEmergencyBroadcast(banner());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(again.showBroadcastBanner, isFalse);

      // Admin publishes a new one.
      final fresh = signedIn()..setEmergencyBroadcast(banner(stamp: '2026-11-27T10:00:00Z'));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(fresh.showBroadcastBanner, isTrue);
    });

    test('a non-dismissible banner cannot be dismissed', () {
      final s = signedIn()..setEmergencyBroadcast(banner(dismissible: false));
      s.dismissAnnouncement();
      expect(s.showBroadcastBanner, isTrue);
    });
  });

  test('notification rows from the database keep their real time and target', () {
    final n = NotificationModel.fromMap({
      'notification_id': 'notif_1',
      'type': 'broadcast',
      'title': 'Hello',
      'message': 'World',
      'target_uid': 'user_9',
      'is_read': false,
      'created_at': '2026-11-20T08:30:00Z',
    }, 'notif_1');
    expect(n.createdAt.toUtc(), DateTime.utc(2026, 11, 20, 8, 30));
    expect(n.targetUid, 'user_9');
  });

  testWidgets('home shows the targeted banner with the admin-picked style and hides it for other agencies', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final mine = signedIn()..setEmergencyBroadcast(banner(tenant: 'tenant_a'));
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: mine,
      child: MaterialApp(home: MainShell(onSignOut: () {})),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Diwali offer'), findsOneWidget);
    final festiveIconsWithBanner = tester.widgetList(find.byIcon(Icons.celebration_rounded)).length;

    mine.setEmergencyBroadcast(banner(tenant: 'tenant_b'));
    await tester.pumpAndSettle();
    expect(find.text('Diwali offer'), findsNothing);
    // The banner used the admin-picked festive style (not the stale 'info' type).
    expect(tester.widgetList(find.byIcon(Icons.celebration_rounded)).length, festiveIconsWithBanner - 1);
  });
}
