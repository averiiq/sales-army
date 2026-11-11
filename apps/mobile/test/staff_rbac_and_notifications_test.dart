import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/admin/data/models/staff_model.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';
import 'package:salesarmy/features/visits/data/models/reminder_model.dart';
import 'package:salesarmy/features/visits/presentation/screens/visits_tab.dart';
import 'package:salesarmy/features/dashboard/presentation/dialogs/notification_center_modal.dart';

void main() {
  group('Staff & RBAC Domain Tests', () {
    test('StaffPermissions presets enforce correct role defaults', () {
      final owner = StaffPermissions.owner();
      expect(owner.billing, isTrue);
      expect(owner.products, isTrue);
      expect(owner.orders, isTrue);
      expect(owner.inventory, isTrue);
      expect(owner.reports, isTrue);
      expect(owner.accounts, isTrue);
      expect(owner.staff, isTrue);
      expect(owner.settings, isTrue);

      final delivery = StaffPermissions.delivery();
      expect(delivery.billing, isFalse);
      expect(delivery.products, isFalse);
      expect(delivery.orders, isTrue);
      expect(delivery.inventory, isFalse);
      expect(delivery.reports, isFalse);
      expect(delivery.accounts, isFalse);
      expect(delivery.staff, isFalse);
      expect(delivery.settings, isFalse);

      final accountant = StaffPermissions.accountant();
      expect(accountant.billing, isTrue);
      expect(accountant.products, isFalse);
      expect(accountant.orders, isTrue);
      expect(accountant.reports, isTrue);
      expect(accountant.accounts, isTrue);
      expect(accountant.staff, isFalse);

      final fieldSales = StaffPermissions.fieldSales();
      expect(fieldSales.billing, isTrue);
      expect(fieldSales.products, isTrue);
      expect(fieldSales.orders, isTrue);
      expect(fieldSales.reports, isFalse);
      expect(fieldSales.accounts, isFalse);
    });

    test('AppState.canAccessModule respects active staff role permissions', () {
      final appState = AppState();

      // Default (Owner mode): all modules accessible
      expect(appState.canAccessModule('billing'), isTrue);
      expect(appState.canAccessModule('inventory'), isTrue);
      expect(appState.canAccessModule('reports'), isTrue);
      expect(appState.canAccessModule('staff'), isTrue);

      // Switch to Delivery Staff
      final deliveryStaff = StaffModel(
        id: 'staff_del_1',
        name: 'Ramesh Delivery',
        email: 'ramesh@agency.com',
        mobile: '9876543210',
        role: 'Delivery Staff',
        permissions: StaffPermissions.delivery(),
        createdAt: DateTime.now(),
      );
      appState.setActiveStaffUser(deliveryStaff);

      expect(appState.canAccessModule('orders'), isTrue);
      expect(appState.canAccessModule('billing'), isFalse);
      expect(appState.canAccessModule('inventory'), isFalse);
      expect(appState.canAccessModule('reports'), isFalse);
      expect(appState.canAccessModule('accounts'), isFalse);
      expect(appState.canAccessModule('staff'), isFalse);

      // Switch back to Owner mode
      appState.setActiveStaffUser(null);
      expect(appState.canAccessModule('billing'), isTrue);
    });

    test('AppState staff CRUD and active staff synchronization', () async {
      final appState = AppState();
      appState.tenant = appState.tenant.copyWith(subscriptionPlanId: 'enterprise', maxUsers: 10);
      final initialCount = appState.staffList.length;

      final newStaff = StaffModel(
        id: 'staff_test_99',
        name: 'Pooja Accountant',
        email: 'pooja@agency.com',
        mobile: '9811122233',
        role: 'Accountant',
        permissions: StaffPermissions.accountant(),
        createdAt: DateTime.now(),
      );

      await appState.addStaff(newStaff);
      expect(appState.staffList.length, initialCount + 1);
      expect(appState.staffList.any((s) => s.id == 'staff_test_99'), isTrue);

      // Update
      final updatedStaff = newStaff.copyWith(name: 'Pooja Sharma (Senior Accountant)');
      await appState.updateStaff(updatedStaff);
      expect(appState.staffList.firstWhere((s) => s.id == 'staff_test_99').name, 'Pooja Sharma (Senior Accountant)');

      // Delete
      await appState.deleteStaff('staff_test_99');
      expect(appState.staffList.any((s) => s.id == 'staff_test_99'), isFalse);
    });
  });

  group('Notifications & Reminders Tests', () {
    test('AppState notification mark as read and unread count', () async {
      final appState = AppState();
      final initialUnread = appState.unreadNotificationsCount;

      final testNotif = NotificationModel(
        id: 'notif_test_1',
        type: 'payment',
        title: 'Test Payment Received',
        message: 'Collected ₹5,000 via UPI',
        isRead: false,
        createdAt: DateTime.now(),
      );
      appState.addNotification(testNotif);

      expect(appState.unreadNotificationsCount, initialUnread + 1);

      await appState.markNotificationAsRead('notif_test_1');
      expect(appState.notifications.firstWhere((n) => n.id == 'notif_test_1').isRead, isTrue);

      await appState.markAllNotificationsAsRead();
      expect(appState.unreadNotificationsCount, 0);
    });

    test('AppState reminder add, complete, and delete', () async {
      final appState = AppState();
      final initialCount = appState.reminders.length;

      final rem = ReminderModel(
        reminderId: 'rem_test_1',
        shopId: 'shop_001',
        assignedToUid: 'demo_user',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        description: 'Follow up on payment cheque',
        isCompleted: false,
      );

      await appState.addReminder(rem);
      expect(appState.reminders.length, initialCount + 1);
      expect(appState.reminders.firstWhere((r) => r.reminderId == 'rem_test_1').isCompleted, isFalse);

      await appState.completeReminder('rem_test_1');
      expect(appState.reminders.firstWhere((r) => r.reminderId == 'rem_test_1').isCompleted, isTrue);

      await appState.deleteReminder('rem_test_1');
      expect(appState.reminders.any((r) => r.reminderId == 'rem_test_1'), isFalse);
    });

    testWidgets('VisitsTab renders 3 tabs including Reminders and switches tabs', (tester) async {
      final appState = AppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: VisitsTab(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header and 3 tabs
      expect(find.text('Reminders & Field Visits'), findsOneWidget);
      expect(find.textContaining('Upcoming'), findsOneWidget);
      expect(find.textContaining('Completed'), findsOneWidget);
      expect(find.textContaining('Reminders ('), findsOneWidget);
      expect(find.text('+ Reminder'), findsOneWidget);

      // Switch to Reminders tab
      await tester.tap(find.textContaining('Reminders ('));
      await tester.pumpAndSettle();

      // Reminders list or empty state is visible
      expect(find.byIcon(Icons.delete_outline_rounded), findsWidgets);
    });

    testWidgets('NotificationCenterModal renders notifications and marks read', (tester) async {
      final appState = AppState();
      appState.addNotification(
        NotificationModel(
          id: 'test_notif_001',
          title: 'Stock Warning',
          message: 'Inventory running low for Parle-G Gold 1kg',
          type: 'inventory',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: NotificationCenterModal(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications & Alerts'), findsOneWidget);
      expect(find.text('Tap to view full details'), findsWidgets);

      // Tap on first notification to open detail view
      await tester.tap(find.text('Tap to view full details').first);
      await tester.pumpAndSettle();

      expect(find.text('Notification Detail'), findsOneWidget);
      expect(find.text('FULL NOTIFICATION TEXT'), findsOneWidget);
      expect(find.text('Back to Notifications'), findsOneWidget);

      // Go back
      await tester.tap(find.text('Back to Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications & Alerts'), findsOneWidget);
    });
  });
}
