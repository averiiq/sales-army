import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/collections/data/models/expense_model.dart';
import 'package:salesarmy/features/dashboard/data/models/notification_model.dart';
import 'package:salesarmy/features/inventory/data/models/purchase_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Purchase, Expense & Notification System Tests', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
      // Set predictable initial balances
      appState.updateInHandAndAccountBalances(inHandCash: 50000.0, inAccountBalance: 100000.0);
    });

    test('1. Adding a paid cash purchase deducts cash and increments inventory stock', () {
      final initialCash = appState.inHandCash;
      final product = appState.products.first;
      final initialStock = product.stockQuantity;

      final purchaseItem = PurchaseItemModel(
        productId: product.productId,
        productName: product.name,
        quantity: 25,
        unitPrice: 100.0,
        total: 2500.0,
      );

      final purchase = PurchaseModel(
        id: 'pur_test_1',
        supplierName: 'Parle Test Supplier',
        billNumber: 'BILL-101',
        purchaseDate: DateTime.now(),
        itemsDescription: '25 units of ${product.name}',
        totalUnits: 25,
        totalAmount: 2500.0,
        paymentStatus: 'paid',
        paymentMode: 'Cash',
        createdAt: DateTime.now(),
        items: [purchaseItem],
      );

      appState.addPurchase(purchase);

      // Verify cash balance deducted
      expect(appState.inHandCash, equals(initialCash - 2500.0));

      // Verify product stock incremented
      final updatedProduct = appState.products.firstWhere((p) => p.productId == product.productId);
      expect(updatedProduct.stockQuantity, equals(initialStock + 25));

      // Verify purchase stored
      expect(appState.purchases.any((p) => p.id == 'pur_test_1'), isTrue);

      // Verify notification logged
      expect(appState.notifications.any((n) => n.title.contains('Goods In')), isTrue);
    });

    test('2. Deleting a purchase reverts inventory stock and refunds cash balance', () {
      final product = appState.products.first;
      final initialStock = product.stockQuantity;
      final initialCash = appState.inHandCash;

      final purchaseItem = PurchaseItemModel(
        productId: product.productId,
        productName: product.name,
        quantity: 10,
        unitPrice: 50.0,
        total: 500.0,
      );

      final purchase = PurchaseModel(
        id: 'pur_test_2',
        supplierName: 'Supplier 2',
        billNumber: 'BILL-102',
        purchaseDate: DateTime.now(),
        itemsDescription: '10 units',
        totalUnits: 10,
        totalAmount: 500.0,
        paymentStatus: 'paid',
        paymentMode: 'Cash',
        createdAt: DateTime.now(),
        items: [purchaseItem],
      );

      appState.addPurchase(purchase);
      expect(appState.inHandCash, equals(initialCash - 500.0));
      expect(appState.products.firstWhere((p) => p.productId == product.productId).stockQuantity, equals(initialStock + 10));

      // Now delete purchase
      appState.deletePurchase('pur_test_2');

      // Verify refunded cash
      expect(appState.inHandCash, equals(initialCash));

      // Verify reverted stock
      expect(appState.products.firstWhere((p) => p.productId == product.productId).stockQuantity, equals(initialStock));

      // Verify purchase removed
      expect(appState.purchases.any((p) => p.id == 'pur_test_2'), isFalse);
    });

    test('3. Adding expense deducts from balance and deleting expense refunds balance', () {
      final initialCash = appState.inHandCash;

      final expense = ExpenseModel(
        id: 'exp_test_1',
        title: 'Diesel for van',
        category: 'Fuel / Transport',
        amount: 800.0,
        paymentMode: 'Cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      appState.addExpense(expense);

      // Verify deducted
      expect(appState.inHandCash, equals(initialCash - 800.0));
      expect(appState.expenses.any((e) => e.id == 'exp_test_1'), isTrue);

      // Delete expense
      appState.deleteExpense('exp_test_1');

      // Verify refunded
      expect(appState.inHandCash, equals(initialCash));
      expect(appState.expenses.any((e) => e.id == 'exp_test_1'), isFalse);
    });

    test('4. Notification management: add, mark read, mark all read, delete, clear', () async {
      appState.clearAllNotifications();
      expect(appState.notifications.isEmpty, isTrue);
      expect(appState.unreadNotificationsCount, equals(0));

      final notif1 = NotificationModel(
        id: 'notif_1',
        type: 'order',
        title: 'Order Dispatched',
        message: 'Order #ORD-1 has been dispatched.',
        createdAt: DateTime.now(),
        isRead: false,
      );

      final notif2 = NotificationModel(
        id: 'notif_2',
        type: 'inventory',
        title: 'Low Stock',
        message: 'Sugar 1kg low stock.',
        createdAt: DateTime.now(),
        isRead: false,
      );

      appState.addNotification(notif1);
      appState.addNotification(notif2);

      expect(appState.notifications.length, equals(2));
      expect(appState.unreadNotificationsCount, equals(2));

      // Mark single as read
      await appState.markNotificationAsRead('notif_1');
      expect(appState.notifications.firstWhere((n) => n.id == 'notif_1').isRead, isTrue);
      expect(appState.unreadNotificationsCount, equals(1));

      // Mark all read
      await appState.markAllNotificationsAsRead();
      expect(appState.unreadNotificationsCount, equals(0));

      // Delete single
      appState.deleteNotification('notif_1');
      expect(appState.notifications.length, equals(1));
      expect(appState.notifications.any((n) => n.id == 'notif_1'), isFalse);

      // Clear all
      appState.clearAllNotifications();
      expect(appState.notifications.isEmpty, isTrue);
    });
  });
}
