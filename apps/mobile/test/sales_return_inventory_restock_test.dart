import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/orders/data/models/sales_return_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/features/orders/presentation/dialogs/sales_return_dialog.dart';

void main() {
  test('processSalesReturn automatically increases inventory stock and credits shop balance', () async {
    final appState = AppState();
    final targetProduct = appState.products.first;
    final initialStock = targetProduct.stockQuantity;
    final targetShop = appState.shops.first;
    final initialShopOutstanding = targetShop.currentOutstanding;

    const returnQty = 5;
    final returnAmount = targetProduct.basePrice * returnQty;

    final returnModel = SalesReturnModel(
      returnId: 'ret_test_101',
      returnNumber: 'RET-2026-0001',
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
      reason: 'Damaged Goods',
    );

    // Execute sales return
    await appState.processSalesReturn(returnModel);

    // Verify stock increased by returnQty
    final updatedProduct = appState.products.firstWhere((p) => p.productId == targetProduct.productId);
    expect(updatedProduct.stockQuantity, equals(initialStock + returnQty));

    // Verify shop outstanding reduced
    final updatedShop = appState.shops.firstWhere((s) => s.shopId == targetShop.shopId);
    expect(updatedShop.currentOutstanding, equals((initialShopOutstanding - returnAmount).clamp(0.0, double.infinity)));

    // Verify ledger entry created
    final returnLedgerEntry = appState.ledgerEntries.firstWhere((l) => l.referenceId == 'ret_test_101');
    expect(returnLedgerEntry.type, equals('CREDIT_NOTE'));
    expect(returnLedgerEntry.amount, equals(returnAmount));

    // Verify notification emitted
    expect(appState.notifications.any((n) => n.title.contains('RET-2026-0001')), isTrue);
  });

  testWidgets('showSalesReturnDialog renders controls and live restock preview', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Test Host')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.text('Test Host'));
    showSalesReturnDialog(context);
    await tester.pumpAndSettle();

    // Verify dialog elements
    expect(find.text('Sales Return'), findsOneWidget); // now a full page
    expect(find.text('Select Party *'), findsOneWidget);
    expect(find.text('Select Product to Return *'), findsOneWidget);
    expect(find.text('Return Quantity *'), findsOneWidget);
    expect(find.text('Return Reason *'), findsOneWidget);
    expect(find.text('Automatic Inventory Restock Preview'), findsOneWidget);
    expect(find.text('Confirm Return & Restock Inventory'), findsOneWidget);
  });
}
