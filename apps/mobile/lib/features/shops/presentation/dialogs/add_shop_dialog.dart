import 'package:flutter/material.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/shops/presentation/screens/create_shop_screen.dart';

Future<void> showAddShopDialog(BuildContext context, {ShopModel? existingShop}) {
  return Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => CreateShopScreen(initialShop: existingShop)),
  );
}
