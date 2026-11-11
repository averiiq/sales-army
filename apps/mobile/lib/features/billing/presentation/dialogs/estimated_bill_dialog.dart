import 'package:flutter/material.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/billing/presentation/screens/estimated_bill_screen.dart';

class EstimatedBillDialog extends StatelessWidget {
  final ShopModel? initialShop;

  const EstimatedBillDialog({super.key, this.initialShop});

  static Future<void> show(BuildContext context, {ShopModel? shop}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EstimatedBillScreen(initialShop: shop),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return EstimatedBillScreen(initialShop: initialShop);
  }
}
