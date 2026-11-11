import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('SalesArmy Basic Widget Sanity Test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Text('SalesArmy Multi-Tenant SaaS'),
        ),
      ),
    );

    expect(find.text('SalesArmy Multi-Tenant SaaS'), findsOneWidget);
  });
}
