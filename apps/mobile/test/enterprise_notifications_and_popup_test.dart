import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/notification_service.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';
import 'package:salesarmy/features/dashboard/presentation/dialogs/notification_center_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Enterprise Notification & In-App Popup Suite', () {
    late AppState appState;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      appState = AppState();
      NotificationService.instance.initialize(appState);
    });

    test('1. AppState notification operations: add, mark read, unread count, delete, clear', () {
      appState.clearAllNotifications();
      expect(appState.notifications.length, equals(0));
      expect(appState.unreadNotificationsCount, equals(0));

      final n1 = NotificationModel(
        id: 'notif_order_1',
        title: 'New Retail Order #8921',
        message: 'Order for ₹15,246 placed by Ganesh Kirana',
        type: 'order',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final n2 = NotificationModel(
        id: 'notif_payment_1',
        title: 'UPI Payment Received',
        message: '₹5,000 received from Metro Mart',
        type: 'payment',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final n3 = NotificationModel(
        id: 'notif_bcast_1',
        title: 'Admin Flash Alert',
        message: 'All van deliveries must be confirmed by 7 PM',
        type: 'broadcast',
        createdAt: DateTime.now(),
        isRead: false,
      );

      // Add notifications
      appState.addNotification(n1, showPopup: false);
      appState.addNotification(n2, showPopup: false);
      appState.addNotification(n3, showPopup: false);

      expect(appState.notifications.length, equals(3));
      expect(appState.unreadNotificationsCount, equals(3));
      // First item is most recent
      expect(appState.notifications.first.id, equals('notif_bcast_1'));

      // Mark single read
      appState.markNotificationAsRead('notif_bcast_1');
      expect(appState.unreadNotificationsCount, equals(2));
      expect(appState.notifications.firstWhere((n) => n.id == 'notif_bcast_1').isRead, isTrue);

      // Mark all read
      appState.markAllNotificationsAsRead();
      expect(appState.unreadNotificationsCount, equals(0));
      expect(appState.notifications.every((n) => n.isRead), isTrue);

      // Delete notification
      appState.deleteNotification('notif_payment_1');
      expect(appState.notifications.length, equals(2));
      expect(appState.notifications.any((n) => n.id == 'notif_payment_1'), isFalse);

      // Clear all
      appState.clearAllNotifications();
      expect(appState.notifications.isEmpty, isTrue);
      expect(appState.unreadNotificationsCount, equals(0));
    });

    test('2. receiveRemoteNotification and sendAdminBroadcast', () async {
      appState.clearAllNotifications();

      final remotePush = NotificationModel(
        id: 'push_cloud_99',
        title: 'Cloud Push Dispatch',
        message: 'Postgres realtime broadcast received on mobile',
        type: 'inventory',
        createdAt: DateTime.now(),
        isRead: false,
      );

      appState.receiveRemoteNotification(remotePush);
      expect(appState.notifications.length, equals(1));
      expect(appState.notifications.first.id, equals('push_cloud_99'));
      expect(appState.unreadNotificationsCount, equals(1));

      // Admin broadcast
      await appState.sendAdminBroadcast(
        title: 'Urgent Staff Meeting',
        message: 'Morning briefing in 10 minutes at main warehouse',
        type: 'broadcast',
        targetRole: 'Field Sales',
      );

      expect(appState.notifications.length, equals(2));
      expect(appState.notifications.first.title, equals('Urgent Staff Meeting'));
      expect(appState.notifications.first.type, equals('broadcast'));
    });

    testWidgets('3. InAppNotificationBanner slides into overlay with rootNavigatorKey', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const Scaffold(
              body: Center(child: Text('Main Screen')),
            ),
          ),
        ),
      );

      final testNotif = NotificationModel(
        id: 'banner_test_1',
        title: 'High Priority Alert',
        message: 'Stock replenished for Parle-G Gold 1kg',
        type: 'inventory',
        createdAt: DateTime.now(),
        isRead: false,
      );

      // Trigger In-App Popup
      NotificationService.instance.showInAppPopup(testNotif);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // let slide animation complete

      // Verify banner elements rendered in overlay
      expect(find.text('High Priority Alert'), findsOneWidget);
      expect(find.text('Stock replenished for Parle-G Gold 1kg'), findsOneWidget);
      expect(find.text('View'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

      // Dismiss banner via close button
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(find.text('High Priority Alert'), findsNothing);
    });

    testWidgets('4. NotificationCenterModal displays category chips and filters notifications', (tester) async {
      appState.clearAllNotifications();

      appState.addNotification(
        NotificationModel(
          id: 'ord_1',
          title: 'Order Dispatched #441',
          message: 'Delivery van en route',
          type: 'order',
          createdAt: DateTime.now(),
        ),
        showPopup: false,
      );
      appState.addNotification(
        NotificationModel(
          id: 'pay_1',
          title: 'Payment Received ₹2,500',
          message: 'Cleared via UPI QR',
          type: 'payment',
          createdAt: DateTime.now(),
        ),
        showPopup: false,
      );
      appState.addNotification(
        NotificationModel(
          id: 'bcast_1',
          title: 'Regional Holiday Notice',
          message: 'Warehouse operations closed on Monday',
          type: 'broadcast',
          createdAt: DateTime.now(),
        ),
        showPopup: false,
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NotificationCenterModal.show(ctx),
                  child: const Text('Open Notifications'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open modal
      await tester.tap(find.text('Open Notifications'));
      await tester.pumpAndSettle();

      // Verify modal headers and category filter chips
      expect(find.text('Notifications & Alerts'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
      expect(find.text('Broadcasts'), findsOneWidget);

      // Initially 'All' shows all 3
      expect(find.text('Order Dispatched #441'), findsOneWidget);
      expect(find.text('Payment Received ₹2,500'), findsOneWidget);
      expect(find.text('Regional Holiday Notice'), findsOneWidget);

      // Filter by 'Orders'
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('Order Dispatched #441'), findsOneWidget);
      expect(find.text('Payment Received ₹2,500'), findsNothing);
      expect(find.text('Regional Holiday Notice'), findsNothing);

      // Filter by 'Broadcasts'
      await tester.tap(find.text('Broadcasts'));
      await tester.pumpAndSettle();

      expect(find.text('Order Dispatched #441'), findsNothing);
      expect(find.text('Regional Holiday Notice'), findsOneWidget);

      // Tap Mark All Read
      if (find.text('Mark All Read').evaluate().isNotEmpty) {
        await tester.tap(find.text('Mark All Read'));
        await tester.pumpAndSettle();
        expect(appState.unreadNotificationsCount, equals(0));
      }
    });
  });
}
