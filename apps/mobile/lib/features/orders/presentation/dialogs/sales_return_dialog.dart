import 'package:flutter/material.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/features/orders/presentation/screens/sales_return_screen.dart';

export 'package:salesarmy/features/orders/presentation/screens/sales_return_screen.dart';

/// Kept for existing callers: Sales Return is now a full page, not a popup.
Future<void> showSalesReturnDialog(BuildContext context, {ShopModel? preselectedShop}) =>
    openSalesReturnScreen(context, preselectedShop: preselectedShop);
