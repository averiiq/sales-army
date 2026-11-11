import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:salesarmy/features/profile/presentation/dialogs/distributor_profile_modal.dart';
import 'package:salesarmy/core/services/app_state.dart';

void main() {
  testWidgets('DistributorProfileModal renders all sections matching Screenshots 1 to 5', (tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => DistributorProfileModal(
                      onSignOut: () {},
                    ),
                  );
                },
                child: const Text('Open Profile'),
              ),
            ),
          ),
        ),
      ),
    );

    // Open modal
    await tester.tap(find.text('Open Profile'));
    await tester.pumpAndSettle();

    // 1. Header checks
    expect(find.text('Distributor Profile'), findsOneWidget);
    expect(find.text('Agency Details & SalesArmy Plans'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsWidgets);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // 2. Segmented sub-tabs checks
    expect(find.text('Agency Details'), findsOneWidget);
    expect(find.text('SalesArmy Plans'), findsOneWidget);

    // 3. Card 1: Representative & Contact
    expect(find.text('Representative & Contact'), findsOneWidget);
    expect(find.text('Distributor / Agent Name *'), findsOneWidget);
    expect(find.text('Mobile Number *'), findsOneWidget);
    expect(find.text('WhatsApp Number'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text(appState.tenant.representativeName ?? 'Distributor Owner'), findsOneWidget);
    expect(find.text('+91 98220 11223'), findsOneWidget);
    expect(find.text('+91 98765 43210'), findsOneWidget);
    expect(find.text('admin@salesarmy.app'), findsOneWidget);

    // 4. Card 2: Agency & Enterprise Profile
    expect(find.text('Agency & Enterprise Profile'), findsOneWidget);
    expect(find.text('Agency / Firm Name *'), findsOneWidget);
    expect(find.text('Agency Classification'), findsOneWidget);
    expect(find.text('Unique Distributor / Agency ID Code'), findsOneWidget);
    expect(find.text('Authorized FMCG Brands Portfolio'), findsOneWidget);
    expect(find.text('SalesArmy SaaS HQ'), findsOneWidget);
    expect(find.text('Super Stockist & Wholesale Agency'), findsOneWidget);
    expect(find.text('DST-MH-7041'), findsOneWidget);

    // 5. Card 3: Legal, GST & Regulatory Licenses (scroll down to find)
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Legal, GST & Regulatory Licenses'), findsOneWidget);
    expect(find.text('Agency GSTIN'), findsOneWidget);
    expect(find.text('PAN Number'), findsOneWidget);
    expect(find.text('FSSAI License No.'), findsOneWidget);
    expect(find.text('Default GST %'), findsOneWidget);
    expect(find.text('27ABCDE1234F1Z5'), findsOneWidget);
    expect(find.text('ABCDE1234F'), findsOneWidget);
    expect(find.text('11521019000452'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);

    // 6. Card 4: Warehouse & Route Logistics
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Warehouse & Route Logistics'), findsOneWidget);
    expect(find.text('Agency Registered Godown / Warehouse Address'), findsOneWidget);
    expect(find.text('Assigned Territory & Beat Route'), findsOneWidget);
    expect(find.textContaining('Plot 42, Sector 8'), findsOneWidget);
    expect(find.text('Pune Central & PCMC Retail Route - Beat 4'), findsOneWidget);

    // 7. Card 5: Agency Bank Settlement Account
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Agency Bank Settlement Account'), findsOneWidget);
    expect(find.text('Settlement Bank Name'), findsOneWidget);
    expect(find.text('Account Number'), findsOneWidget);
    expect(find.text('IFSC Code'), findsOneWidget);
    expect(find.text('HDFC Bank'), findsOneWidget);
    expect(find.text('50200088921820'), findsOneWidget);
    expect(find.text('HDFC0001042'), findsOneWidget);

    // 8. Card 6: Account & Active Session
    expect(find.text('Account & Active Session'), findsOneWidget);
    expect(find.text('Log out of this distributor profile on this device'), findsOneWidget);
    expect(find.text('Log Out of Account'), findsOneWidget);

    // 9. Sticky bottom action bar
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Save Agency Details'), findsOneWidget);

    // 10. Switch to SalesArmy Plans tab
    await tester.tap(find.text('SalesArmy Plans'));
    await tester.pumpAndSettle();

    expect(find.text('Active SalesArmy Subscription'), findsOneWidget);
    expect(find.text('Plan: Monthly (₹899/mo) • Txn:'), findsOneWidget);
    expect(find.text('RZP_TXN_999482'), findsOneWidget);
    expect(find.text('Available SalesArmy Plans'), findsOneWidget);
    expect(find.text('Monthly Flexible Plan'), findsOneWidget);
    expect(find.text('Pay as you go monthly'), findsOneWidget);
    expect(find.text('₹899'), findsOneWidget);
    expect(find.text('Active Plan'), findsOneWidget);

    // Scroll down in SalesArmy Plans tab
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.text('Annual Plan'), findsOneWidget);
    expect(find.text('SAVE 33%'), findsOneWidget);
    expect(find.text('Billed annually at ₹7,188 / yr'), findsOneWidget);
    expect(find.text('₹599'), findsOneWidget);
    expect(find.text('Subscribe for ₹599 / mo (₹7,188/yr)'), findsOneWidget);
    expect(find.text('58mm Thermal Bluetooth POS Printer'), findsOneWidget);
    expect(find.text('₹2,499'), findsOneWidget);
    expect(find.text('Status: Not Purchased'), findsOneWidget);
    expect(find.text('Order Printer'), findsOneWidget);

    // Scroll further down to shipping address
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('Printer Delivery Shipping Address'), findsOneWidget);
    expect(find.text('Recipient Name'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsOneWidget);
    expect(find.text('Shop No. / Building / Street Address'), findsOneWidget);
    expect(find.text('Shop 14, APMC Market Yard'), findsOneWidget);
    expect(find.text('City / Town'), findsOneWidget);
    expect(find.text('Pune'), findsOneWidget);
    expect(find.text('Maharashtra'), findsOneWidget);
    expect(find.text('411037'), findsOneWidget);
    expect(find.text('Save Shipping Details'), findsOneWidget);

    // Verify Sticky bottom button is now Manage SalesArmy Plans
    expect(find.text('Manage SalesArmy Plans'), findsOneWidget);

    // 11. Switch back to Agency Details and test Save Agency Details
    await tester.tap(find.text('Agency Details'));
    await tester.pumpAndSettle();

    expect(find.text('Save Agency Details'), findsOneWidget);
    await tester.tap(find.text('Save Agency Details'));
    await tester.pumpAndSettle();

    // Dialog dismissed and snackbar shown
    expect(find.text('Agency details saved successfully!'), findsOneWidget);
    expect(find.text('Distributor Profile'), findsNothing);
  });
}
