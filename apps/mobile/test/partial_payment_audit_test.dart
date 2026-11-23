import 'package:flutter_test/flutter_test.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/invoice_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression tests for the partial-payment audit (orders, bills, collections).
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  int seq = 0;
  String id(String p) => '$p-${DateTime.now().microsecondsSinceEpoch}-${seq++}';

  Future<ShopModel> newShop(AppState s) async {
    final shop = ShopModel(
      shopId: id('shop'),
      shopName: 'Partial Pay Kirana',
      ownerName: 'Owner',
      phone: '9000000000',
      currentOutstanding: 0.0,
    );
    await s.addShop(shop);
    return shop;
  }

  OrderModel newOrder(String shopId, double total, {DateTime? at}) => OrderModel(
        orderId: id('ORD'),
        shopId: shopId,
        createdByUid: 'rep',
        status: 'pending',
        items: [
          TransactionItemSnapshot(
            productId: 'p1',
            productName: 'Item',
            quantity: 1,
            unitPrice: total,
            gstRate: 0,
            itemSubtotal: total,
            itemGst: 0,
            itemGrandTotal: total,
          ),
        ],
        subtotal: total,
        totalGst: 0,
        grandTotal: total,
        placedAt: at ?? DateTime.now(),
        createdAt: at ?? DateTime.now(),
      );

  InvoiceModel newInvoice(String shopId, String orderId, double total, {double paid = 0, DateTime? at}) {
    final due = total - paid;
    return InvoiceModel(
      invoiceId: id('inv'),
      invoiceNumber: id('INV'),
      orderId: orderId,
      shopId: shopId,
      invoiceType: 'NON_GST',
      invoiceDate: at ?? DateTime.now(),
      seller: const {},
      buyer: const {'shopName': 'Partial Pay Kirana'},
      placeOfSupply: 'Maharashtra',
      items: const [],
      taxableSubtotal: total,
      cgst: 0,
      sgst: 0,
      igst: 0,
      grandTotal: total,
      paidAmount: paid,
      dueAmount: due,
      paymentStatus: due <= 0.01 ? 'paid' : (paid > 0 ? 'partial' : 'unpaid'),
    );
  }

  PaymentModel pay(String shopId, double amount, {String? notes, String? ref}) => PaymentModel(
        paymentId: id('PAY'),
        shopId: shopId,
        createdByUid: 'rep',
        amount: amount,
        paymentMode: 'Cash',
        referenceNumber: ref,
        notes: notes,
        date: DateTime.now(),
      );

  ShopModel fresh(AppState s, ShopModel shop) => s.shops.firstWhere((x) => x.shopId == shop.shopId);

  test('partial payment on an UNBILLED order reduces the shop due (was stuck at full)', () async {
    final s = AppState();
    final shop = await newShop(s);
    final order = newOrder(shop.shopId, 1000);
    await s.addOrder(order);

    await s.recordPayment(pay(shop.shopId, 400, notes: 'Payment for Order ${order.orderId}'),
        targetRef: order.orderId);

    expect(s.getShopOutstandingDue(fresh(s, shop)), 600);
    expect(s.getOrderPaidAmount(order), 400);
    expect(s.getOrderDueAmount(order), 600);
  });

  test('full payment on an unbilled order clears the due', () async {
    final s = AppState();
    final shop = await newShop(s);
    final order = newOrder(shop.shopId, 1000);
    await s.addOrder(order);

    await s.recordPayment(pay(shop.shopId, 1000, notes: 'Payment for Order ${order.orderId}'),
        targetRef: order.orderId);

    expect(s.getShopOutstandingDue(fresh(s, shop)), 0);
  });

  test('billing with a partial payment does NOT double-count it on the bill', () async {
    final s = AppState();
    final shop = await newShop(s);
    final order = newOrder(shop.shopId, 1000);
    final inv = newInvoice(shop.shopId, order.orderId, 1000, paid: 400);
    await s.addOrder(order, inv);
    // Billing flow: bill already carries the 400, so no re-allocation.
    await s.recordPayment(pay(shop.shopId, 400, ref: inv.invoiceNumber), allocateToInvoices: false);

    final bill = s.invoices.firstWhere((i) => i.invoiceId == inv.invoiceId);
    expect(bill.paidAmount, 400);
    expect(bill.dueAmount, 600);
    expect(bill.paymentStatus, 'partial');
    expect(s.getShopOutstandingDue(fresh(s, shop)), 600);
  });

  test('a later partial payment collected for a specific bill goes to that bill', () async {
    final s = AppState();
    final shop = await newShop(s);
    final o1 = newOrder(shop.shopId, 500);
    final o2 = newOrder(shop.shopId, 800);
    final older = newInvoice(shop.shopId, o1.orderId, 500, at: DateTime(2026, 1, 1));
    final newer = newInvoice(shop.shopId, o2.orderId, 800, at: DateTime(2026, 2, 1));
    await s.addOrder(o1, older);
    await s.addOrder(o2, newer);

    await s.recordPayment(pay(shop.shopId, 300), targetRef: newer.invoiceNumber);

    expect(s.invoices.firstWhere((i) => i.invoiceId == newer.invoiceId).paidAmount, 300);
    expect(s.invoices.firstWhere((i) => i.invoiceId == older.invoiceId).paidAmount, 0);
    expect(s.getShopOutstandingDue(fresh(s, shop)), 1000);
  });

  test('untargeted payments pay the OLDEST bill first', () async {
    final s = AppState();
    final shop = await newShop(s);
    final o1 = newOrder(shop.shopId, 500);
    final o2 = newOrder(shop.shopId, 800);
    final older = newInvoice(shop.shopId, o1.orderId, 500, at: DateTime(2026, 1, 1));
    final newer = newInvoice(shop.shopId, o2.orderId, 800, at: DateTime(2026, 2, 1));
    await s.addOrder(o1, older);
    await s.addOrder(o2, newer);

    await s.recordPayment(pay(shop.shopId, 600));

    expect(s.invoices.firstWhere((i) => i.invoiceId == older.invoiceId).paymentStatus, 'paid');
    expect(s.invoices.firstWhere((i) => i.invoiceId == newer.invoiceId).paidAmount, 100);
  });

  test('deleting a payment restores the bill to unpaid', () async {
    final s = AppState();
    final shop = await newShop(s);
    final order = newOrder(shop.shopId, 1000);
    final inv = newInvoice(shop.shopId, order.orderId, 1000);
    await s.addOrder(order, inv);
    final p = pay(shop.shopId, 400);
    await s.recordPayment(p, targetRef: inv.invoiceNumber);
    expect(s.invoices.firstWhere((i) => i.invoiceId == inv.invoiceId).paidAmount, 400);

    await s.deletePayment(p.paymentId);

    final bill = s.invoices.firstWhere((i) => i.invoiceId == inv.invoiceId);
    expect(bill.paidAmount, 0);
    expect(bill.dueAmount, 1000);
    expect(bill.paymentStatus, 'unpaid');
    expect(s.getShopOutstandingDue(fresh(s, shop)), 1000);
  });

  test('editing a payment amount updates the bill paid / due', () async {
    final s = AppState();
    final shop = await newShop(s);
    final order = newOrder(shop.shopId, 1000);
    final inv = newInvoice(shop.shopId, order.orderId, 1000);
    await s.addOrder(order, inv);
    final p = pay(shop.shopId, 400, ref: inv.invoiceNumber);
    await s.recordPayment(p, targetRef: inv.invoiceNumber);

    await s.updatePayment(p.copyWith(amount: 250));
    expect(s.invoices.firstWhere((i) => i.invoiceId == inv.invoiceId).paidAmount, 250);

    await s.updatePayment(p.copyWith(amount: 1000));
    expect(s.invoices.firstWhere((i) => i.invoiceId == inv.invoiceId).paymentStatus, 'paid');
  });

  test('billing an order at a different price tier corrects the shop balance', () async {
    final s = AppState();
    final shop = await newShop(s);
    final order = newOrder(shop.shopId, 1000);
    await s.addOrder(order);
    expect(fresh(s, shop).currentOutstanding, 1000);

    await s.createInvoice(newInvoice(shop.shopId, order.orderId, 1200));
    expect(fresh(s, shop).currentOutstanding, 1200);
  });
}
