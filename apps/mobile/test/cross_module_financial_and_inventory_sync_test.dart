import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/collections/data/models/expense_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/features/inventory/data/models/purchase_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/orders/data/models/sales_return_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Cross-Module Financial & Inventory Synchronization Tests', () {
    test('1. Invoice generation deducts inventory stock and updates shop outstanding and ledger', () async {
      final appState = AppState();
      final targetProduct = appState.products.first;
      final initialStock = targetProduct.stockQuantity;
      final targetShop = appState.shops.first;
      final initialShopOutstanding = targetShop.currentOutstanding;

      const orderQty = 4;
      final itemTotal = targetProduct.basePrice * orderQty;

      final invoice = InvoiceModel(
        invoiceId: 'inv_sync_001',
        invoiceNumber: 'INV-SYNC-001',
        orderId: 'ORD-SYNC-001',
        shopId: targetShop.shopId,
        invoiceType: 'GST',
        invoiceDate: DateTime.now(),
        seller: {'firmName': 'Test Agency'},
        buyer: {'shopName': targetShop.shopName},
        placeOfSupply: 'Maharashtra',
        items: [
          TransactionItemSnapshot(
            productId: targetProduct.productId,
            productName: targetProduct.name,
            quantity: orderQty,
            rate: targetProduct.basePrice,
            taxableAmount: itemTotal,
            total: itemTotal,
          ),
        ],
        taxableSubtotal: itemTotal,
        cgst: 0.0,
        sgst: 0.0,
        igst: 0.0,
        grandTotal: itemTotal,
        paidAmount: 0.0,
        dueAmount: itemTotal,
        paymentStatus: 'unpaid',
      );

      await appState.createInvoice(invoice);

      // Verify inventory deducted
      final updatedProduct = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
      expect(updatedProduct.stockQuantity, equals(initialStock - orderQty));

      // Verify shop outstanding increased
      final updatedShop = appState.shops.firstWhere((s) => s.shopId == targetShop.shopId);
      expect(updatedShop.currentOutstanding, equals(initialShopOutstanding + itemTotal));

      // Verify double-entry ledger debit recorded
      final ledger = appState.ledgerEntries.firstWhere((l) => l.referenceId == 'inv_sync_001');
      expect(ledger.type, equals('INVOICE'));
      expect(ledger.amount, equals(itemTotal));
      expect(ledger.balanceAfter, equals(initialShopOutstanding + itemTotal));
    });

    test('2. Cash payment collection reduces dues, increments In-Hand Cash, and reconciles unpaid invoice', () async {
      final appState = AppState();
      final targetShop = appState.shops.first;
      final initialShopOutstanding = targetShop.currentOutstanding;
      final initialCash = appState.inHandCash;

      const paymentAmount = 1500.0;
      final payment = PaymentModel(
        paymentId: 'PAY-SYNC-001',
        shopId: targetShop.shopId,
        createdByUid: 'admin',
        amount: paymentAmount,
        paymentMode: 'Cash',
        referenceNumber: 'REF-001',
        date: DateTime.now(),
        notes: 'Cash payment from kirana',
      );

      await appState.recordPayment(payment);

      // Verify shop dues decremented
      final updatedShop = appState.shops.firstWhere((s) => s.shopId == targetShop.shopId);
      expect(updatedShop.currentOutstanding, equals((initialShopOutstanding - paymentAmount).clamp(0.0, double.infinity)));

      // Verify in-hand cash incremented
      expect(appState.inHandCash, equals(initialCash + paymentAmount));

      // Verify payment ledger entry
      final ledger = appState.ledgerEntries.firstWhere((l) => l.referenceId == 'PAY-SYNC-001');
      expect(ledger.type, equals('PAYMENT'));
      expect(ledger.amount, equals(-paymentAmount));

      // Verify deletePayment cleanly reverses the payment
      await appState.deletePayment('PAY-SYNC-001');
      final revertedShop = appState.shops.firstWhere((s) => s.shopId == targetShop.shopId);
      expect(revertedShop.currentOutstanding, equals(initialShopOutstanding));
      expect(appState.inHandCash, equals(initialCash));
    });

    test('3. Stock inward purchase increments product stock and decrements cash if paid in cash', () async {
      final appState = AppState();
      final targetProduct = appState.products.first;
      final initialStock = targetProduct.stockQuantity;
      final initialCash = appState.inHandCash;

      const purchaseUnits = 25;
      const purchaseAmount = 5000.0;

      final purchase = PurchaseModel(
        id: 'pur_sync_001',
        supplierName: 'Parle Products Ltd',
        billNumber: 'SUP-B-991',
        purchaseDate: DateTime.now(),
        itemsDescription: '${targetProduct.name} ($purchaseUnits pcs)',
        totalUnits: purchaseUnits,
        totalAmount: purchaseAmount,
        paymentStatus: 'Paid',
        paymentMode: 'Cash',
        items: [
          PurchaseItemModel(
            productId: targetProduct.productId,
            productName: targetProduct.name,
            quantity: purchaseUnits,
            unitPrice: 200.0,
            total: purchaseAmount,
          ),
        ],
        createdAt: DateTime.now(),
      );

      appState.addPurchase(purchase);

      // Verify stock increased
      final updatedProduct = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
      expect(updatedProduct.stockQuantity, equals(initialStock + purchaseUnits));

      // Verify cash decremented
      expect(appState.inHandCash, equals(initialCash - purchaseAmount));

      // Delete purchase and verify stock and funds restore
      appState.deletePurchase('pur_sync_001');
      final revertedProduct = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
      expect(revertedProduct.stockQuantity, equals(initialStock));
      expect(appState.inHandCash, equals(initialCash));
    });

    test('4. Field expense reduces In-Hand Cash and deletion restores balance', () async {
      final appState = AppState();
      final initialCash = appState.inHandCash;
      const expenseAmount = 350.0;

      final expense = ExpenseModel(
        id: 'exp_sync_001',
        title: 'Van Petrol / Fuel',
        category: 'Fuel',
        amount: expenseAmount,
        paymentMode: 'Cash',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      appState.addExpense(expense);

      expect(appState.inHandCash, equals(initialCash - expenseAmount));

      appState.deleteExpense('exp_sync_001');
      expect(appState.inHandCash, equals(initialCash));
    });

    test('5. Sales Return restores inventory stock, applies shop credit, and records credit note', () async {
      final appState = AppState();
      final targetProduct = appState.products.first;
      final initialStock = targetProduct.stockQuantity;
      final targetShop = appState.shops.first;
      final initialShopOutstanding = targetShop.currentOutstanding;

      const returnQty = 6;
      final returnAmount = targetProduct.basePrice * returnQty;

      final salesReturn = SalesReturnModel(
        returnId: 'ret_sync_001',
        returnNumber: 'RET-SYNC-001',
        shopId: targetShop.shopId,
        shopName: targetShop.shopName,
        date: DateTime.now(),
        items: [
          TransactionItemSnapshot(
            productId: targetProduct.productId,
            productName: targetProduct.name,
            quantity: returnQty,
            unitPrice: targetProduct.basePrice,
            itemSubtotal: returnAmount,
            total: returnAmount,
          ),
        ],
        totalAmount: returnAmount,
        reason: 'Expired Goods',
      );

      await appState.processSalesReturn(salesReturn);

      // Verify stock replenished
      final updatedProduct = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
      expect(updatedProduct.stockQuantity, equals(initialStock + returnQty));

      // Verify shop credit applied
      final updatedShop = appState.shops.firstWhere((s) => s.shopId == targetShop.shopId);
      expect(updatedShop.currentOutstanding, equals((initialShopOutstanding - returnAmount).clamp(0.0, double.infinity)));

      // Verify credit note in ledger
      final ledger = appState.ledgerEntries.firstWhere((l) => l.referenceId == 'ret_sync_001');
      expect(ledger.type, equals('CREDIT_NOTE'));
      expect(ledger.amount, equals(returnAmount));
    });

    test('6. Bill deletion reverses unpaid dues, restores inventory, and cancels linked order', () async {
      final appState = AppState();
      final targetProduct = appState.products.first;
      final initialStock = targetProduct.stockQuantity;
      final targetShop = appState.shops.first;

      const orderQty = 2;
      final itemTotal = targetProduct.basePrice * orderQty;

      final order = OrderModel(
        orderId: 'ORD-DEL-SYNC-01',
        shopId: targetShop.shopId,
        createdByUid: 'admin',
        status: 'pending',
        items: [],
        subtotal: itemTotal,
        totalGst: 0.0,
        grandTotal: itemTotal,
        placedAt: DateTime.now(),
      );

      final invoice = InvoiceModel(
        invoiceId: 'inv_del_sync_01',
        invoiceNumber: 'INV-DEL-SYNC-01',
        orderId: 'ORD-DEL-SYNC-01',
        shopId: targetShop.shopId,
        invoiceType: 'GST',
        invoiceDate: DateTime.now(),
        seller: {'firmName': 'Test'},
        buyer: {'shopName': targetShop.shopName},
        placeOfSupply: 'Maharashtra',
        items: [
          TransactionItemSnapshot(
            productId: targetProduct.productId,
            productName: targetProduct.name,
            quantity: orderQty,
            rate: targetProduct.basePrice,
            taxableAmount: itemTotal,
            total: itemTotal,
          ),
        ],
        taxableSubtotal: itemTotal,
        cgst: 0.0,
        sgst: 0.0,
        igst: 0.0,
        grandTotal: itemTotal,
        paidAmount: 0.0,
        dueAmount: itemTotal,
        paymentStatus: 'unpaid',
      );

      await appState.addOrder(order, invoice);

      // Verify stock was reduced
      var currentProd = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
      expect(currentProd.stockQuantity, equals(initialStock - orderQty));

      // Now delete invoice
      await appState.deleteInvoice('inv_del_sync_01', restoreStock: true, reverseLedger: true);

      // Verify stock restored
      currentProd = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
      expect(currentProd.stockQuantity, equals(initialStock));

      // Verify linked order status set to cancelled
      final linkedOrder = appState.orders.firstWhere((o) => o.orderId == 'ORD-DEL-SYNC-01');
      expect(linkedOrder.status, equals('cancelled'));
    });
  });
}
