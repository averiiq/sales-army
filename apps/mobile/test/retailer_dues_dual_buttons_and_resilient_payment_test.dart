import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/services/app_state.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/collections/data/models/payment_model.dart';
import 'package:salesarmy/features/collections/presentation/screens/collections_tab.dart';
import 'package:salesarmy/features/collections/presentation/dialogs/collect_payment_dialog.dart';
import 'package:salesarmy/core/utils/formatters.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Retailer Dues Dual Buttons and Resilient Payment Tests', () {
    testWidgets('1. Retailer dues card renders Khata, Record Payment and Collect Payment buttons', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      final shop = ShopModel(
        shopId: 'shop_retail_dues_1',
        shopName: 'Balaji Superstore',
        ownerName: 'Ramesh Balaji',
        phone: '9876543210',
        businessType: 'Kirana Store',
        creditLimit: 10000.0,
        currentOutstanding: 4500.0,
      );
      await appState.addShop(shop);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: CollectionsTab(initialTabIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify shop name and owner info
      expect(find.text('Balaji Superstore'), findsWidgets);
      expect(find.textContaining('Ramesh Balaji'), findsWidgets);

      // Verify Khata button
      expect(find.text('Khata'), findsWidgets);

      // Verify Due amount
      expect(find.text('Due: '), findsWidgets);
      expect(find.text(AppFormatters.currency(4500)), findsWidgets);

      // Verify Credit limit
      expect(find.text('Limit: ₹10000'), findsWidgets);

      // Verify both buttons exist
      expect(find.text('Record Payment'), findsWidgets);
      expect(find.text('Collect Payment'), findsWidgets);
    });

    testWidgets('2. Tapping Collect Payment opens payment collection modal (GatewayPaymentDialog)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      final shop = ShopModel(
        shopId: 'shop_retail_dues_2',
        shopName: 'Krishna Mart',
        ownerName: 'Krishna Kumar',
        phone: '9876543211',
        businessType: 'Supermarket',
        creditLimit: 15000.0,
        currentOutstanding: 3200.0,
      );
      await appState.addShop(shop);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: CollectionsTab(initialTabIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Collect Payment" button
      final collectPaymentBtn = find.text('Collect Payment').first;
      await tester.ensureVisible(collectPaymentBtn);
      await tester.tap(collectPaymentBtn);
      await tester.pumpAndSettle();

      // Verify Collect Payment dialog opens in UPI QR mode by default
      expect(find.text('UPI QR'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Launch Razorpay Checkout'), findsOneWidget);
      expect(find.text('Share Payment Link'), findsOneWidget);

      // Switch to Cash mode and collect
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      expect(find.text('Launch Razorpay Checkout'), findsNothing);
      final confirmCash = find.text('Confirm Cash Received');
      expect(confirmCash, findsOneWidget);
      await tester.ensureVisible(confirmCash);
      await tester.tap(confirmCash);
      await tester.pumpAndSettle();

      final updatedShop = appState.shops.firstWhere((s) => s.shopId == shop.shopId);
      expect(updatedShop.currentOutstanding, 0.0);
      expect(appState.payments.any((p) => p.shopId == shop.shopId && p.paymentMode == 'Cash'), isTrue);
    });

    testWidgets('3. Tapping Record Payment opens payment recording modal (CollectPaymentDialog)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final appState = AppState();
      final shop = ShopModel(
        shopId: 'shop_retail_dues_3',
        shopName: 'Ganesh General Stores',
        ownerName: 'Ganesh Gupta',
        phone: '9876543212',
        businessType: 'Kirana Store',
        creditLimit: 5000.0,
        currentOutstanding: 2000.0,
      );
      await appState.addShop(shop);

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: appState,
          child: const MaterialApp(
            home: Scaffold(
              body: CollectionsTab(initialTabIndex: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap "Record Payment" button
      final recordPaymentBtn = find.text('Record Payment').first;
      await tester.ensureVisible(recordPaymentBtn);
      await tester.tap(recordPaymentBtn);
      await tester.pumpAndSettle();

      // Verify Collect Payment Dialog opens with counter entry inputs
      expect(find.text('Total Outstanding Due'), findsOneWidget);
      expect(find.text('Amount Received (₹) *'), findsOneWidget);
      // Only one action button in the dialog: Record Payment (no Collect Payment)
      final dialog = find.byType(CollectPaymentDialog);
      expect(find.descendant(of: dialog, matching: find.text('Record Payment')), findsNWidgets(2)); // title + button
      expect(find.descendant(of: dialog, matching: find.text('Collect Payment')), findsNothing);

      // Verify Quick amounts exist
      expect(find.text('Quick Amounts'), findsOneWidget);
    });

    test('4. AppState.recordPayment reduces outstanding balance and creates LEDGER entry without hanging', () async {
      final appState = AppState();
      final shop = ShopModel(
        shopId: 'shop_retail_dues_4',
        shopName: 'Shivam Enterprise',
        ownerName: 'Shivam Patel',
        phone: '9876543213',
        businessType: 'Wholesale',
        creditLimit: 50000.0,
        currentOutstanding: 15000.0,
      );
      await appState.addShop(shop);

      final payment = PaymentModel(
        paymentId: 'PAY-TEST-999',
        shopId: shop.shopId,
        createdByUid: 'test_rep',
        amount: 5000.0,
        paymentMode: 'Cash',
        referenceNumber: 'CASH-REC-12345',
        notes: 'Counter Cash Settlement',
        date: DateTime.now(),
        createdAt: DateTime.now(),
      );

      // Verify executing recordPayment completes promptly
      await appState.recordPayment(payment);

      final updatedShop = appState.shops.firstWhere((s) => s.shopId == shop.shopId);
      expect(updatedShop.currentOutstanding, 10000.0);

      final ledgerEntry = appState.ledgerEntries.firstWhere((l) => l.referenceId == 'PAY-TEST-999');
      expect(ledgerEntry.type, 'PAYMENT');
      expect(ledgerEntry.amount, -5000.0);
      expect(ledgerEntry.balanceAfter, 10000.0);
    });
  });
}
