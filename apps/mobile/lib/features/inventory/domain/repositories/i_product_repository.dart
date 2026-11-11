import 'package:salesarmy/features/inventory/domain/entities/product_entity.dart';

abstract class IProductRepository {
  /// Fetches paginated catalog items
  Future<List<ProductEntity>> getProductsPaginated({
    int limit = 50,
    String? startAfterId,
    String? categoryId,
  });

  /// Instant catalog search by name, SKU, or barcode
  Future<List<ProductEntity>> searchCatalog(
    String query, {
    int limit = 30,
  });

  /// Retrieves a single product by ID
  Future<ProductEntity?> getProductById(String productId);

  /// Saves or updates a product in catalog
  Future<void> saveProduct(ProductEntity product, {required String uid});

  /// Adjusts local inventory count atomically
  Future<void> adjustStock(String productId, int deltaQty);

  /// Reactive stream of active catalog items
  Stream<List<ProductEntity>> watchActiveCatalog();
}
