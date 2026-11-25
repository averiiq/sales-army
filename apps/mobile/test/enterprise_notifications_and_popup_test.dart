import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/core/services/notification_service.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';
import 'package:salesarmy/features/dashboard/presentation/dialogs/notification_center_modal.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/features/orders/data/models/sales_return_model.dart';

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

    testWidgets('5. NotificationCenterModal with initialNotificationId displays detail and marks as read', (tester) async {
      appState.clearAllNotifications();

      final targetNotif = NotificationModel(
        id: 'detail_target_1',
        title: 'Overdue Balance Notice',
        message: 'Kirana Mart overdue balance is ₹12,000 for 15 days',
        type: 'payment',
        createdAt: DateTime.now(),
        isRead: false,
      );
      appState.addNotification(targetNotif, showPopup: false);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: ElevatedButton(
                  onPressed: () => NotificationCenterModal.show(
                    ctx,
                    initialNotificationId: 'detail_target_1',
                  ),
                  child: const Text('Open Detail Modal'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Detail Modal'));
      await tester.pumpAndSettle();

      // Check detail view elements
      expect(find.text('Notification Detail'), findsOneWidget);
      expect(find.text('Overdue Balance Notice'), findsOneWidget);
      expect(find.text('Kirana Mart overdue balance is ₹12,000 for 15 days'), findsOneWidget);
      expect(find.text('Back to Notifications'), findsOneWidget);

      // Verify marked as read
      expect(appState.notifications.firstWhere((n) => n.id == 'detail_target_1').isRead, isTrue);

      // Tap back button
      await tester.tap(find.text('Back to Notifications'));
      await tester.pumpAndSettle();

      expect(find.text('Notifications & Alerts'), findsOneWidget);
    });

    test('6. Real business triggers generate in-app notifications', () async {
      appState.clearAllNotifications();

      // Setup sample shop & product
      final testShop = ShopModel(
        shopId: 'shop_test_1',
        shopName: 'Super Store',
        ownerName: 'Ramesh',
        phone: '9876543210',
        address: 'MG Road',
        currentOutstanding: 1000.0,
      );
      await appState.addShop(testShop);

      final testProduct = ProductModel(
        productId: 'prod_test_1',
        name: 'Basmati Rice 5kg',
        gstRate: 5.0,
        wholesalePrice: 400.0,
        stockQuantity: 6,
        lowStockAlertQty: 5,
      );
      await appState.addProduct(testProduct);

      // 1. Order Creation + Low Stock trigger
      final orderItem = TransactionItemSnapshot(
        productId: 'prod_test_1',
        productName: 'Basmati Rice 5kg',
        quantity: 2, // Stock drops from 6 -> 4 <= 5
        rate: 400.0,
        gstRate: 5.0,
        taxableAmount: 800.0,
        totalGst: 40.0,
        total: 840.0,
      );

      final testOrder = OrderModel(
        orderId: 'ORD-TEST-99',
        shopId: 'shop_test_1',
        createdByUid: 'test_user',
        status: 'pending',
        items: [orderItem],
        subtotal: 800.0,
        totalGst: 40.0,
        grandTotal: 840.0,
        placedAt: DateTime.now(),
      );

      await appState.addOrder(testOrder);

      // Check notifications generated
      final orderNotifs = appState.notifications.where((n) => n.type == 'order').toList();
      expect(orderNotifs.any((n) => n.title.contains('ORD-TEST-99')), isTrue);

      final stockNotifs = appState.notifications.where((n) => n.type == 'inventory').toList();
      expect(stockNotifs.any((n) => n.title.contains('Low Stock Alert: Basmati Rice 5kg')), isTrue);

      // 2. Payment Collection trigger
      final testPayment = PaymentModel(
        paymentId: 'PAY-TEST-99',
        shopId: 'shop_test_1',
        createdByUid: 'test_user',
        amount: 500.0,
        paymentMode: 'Cash',
        date: DateTime.now(),
      );

      await appState.recordPayment(testPayment);

      final paymentNotifs = appState.notifications.where((n) => n.type == 'payment').toList();
      expect(paymentNotifs.any((n) => n.title.contains('Payment Received: ₹500')), isTrue);

      // 3. Sales Return trigger
      final returnItem = TransactionItemSnapshot(
        productId: 'prod_test_1',
        productName: 'Basmati Rice 5kg',
        quantity: 1,
        rate: 400.0,
        gstRate: 5.0,
        taxableAmount: 400.0,
        totalGst: 20.0,
        total: 420.0,
      );

      final testReturn = SalesReturnModel(
        returnId: 'RET-TEST-99',
        returnNumber: 'SR-99',
        shopId: 'shop_test_1',
        shopName: 'Super Store',
        createdByUid: 'test_user',
        date: DateTime.now(),
        items: [returnItem],
        totalAmount: 420.0,
        reason: 'Damaged packaging',
      );

      await appState.processSalesReturn(testReturn);

      final returnNotifs = appState.notifications.where((n) => n.type == 'inventory').toList();
      expect(returnNotifs.any((n) => n.title.contains('Sales Return Processed: SR-99')), isTrue);
    });
  });
}
