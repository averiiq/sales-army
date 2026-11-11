import 'package:salesarmy/features/shops/domain/entities/shop_entity.dart';

abstract class IShopRepository {
  /// Fetches a slice of shops with cursor pagination to prevent OOM
  Future<List<ShopEntity>> getShopsPaginated({
    int limit = 50,
    String? startAfterId,
  });

  /// Instant local search by shop name, owner name, phone, or GSTIN
  Future<List<ShopEntity>> searchShops(
    String query, {
    int limit = 20,
  });

  /// Retrieves a single shop by its unique ID
  Future<ShopEntity?> getShopById(String shopId);

  /// Optimistically saves or updates a shop and queues mutation
  Future<void> saveShop(ShopEntity shop, {required String uid});

  /// Atomically updates a retailer's outstanding balance
  Future<void> updateOutstandingBalance(String shopId, double deltaAmount);

  /// Reactive stream for UI widgets, strictly bounded to prevent RAM bloat
  Stream<List<ShopEntity>> watchRecentShops({int limit = 20});
}
