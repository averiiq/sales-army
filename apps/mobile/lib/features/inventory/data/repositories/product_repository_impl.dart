import 'dart:async';
import 'package:salesarmy/features/inventory/domain/entities/product_entity.dart';
import 'package:salesarmy/features/inventory/domain/repositories/i_product_repository.dart';
import 'package:salesarmy/core/cache/local_data_cache.dart';
import 'package:salesarmy/features/inventory/data/models/product_model.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

class ProductRepositoryImpl implements IProductRepository {
  final String tenantId;
  final LocalDataCache<ProductEntity> _cache;
  final StreamController<List<ProductEntity>> _streamController = StreamController<List<ProductEntity>>.broadcast();

  ProductRepositoryImpl({
    required this.tenantId,
  }) : _cache = LocalDataCache<ProductEntity>(
          maxMemoryCapacity: 3000,
          idSelector: (p) => p.productId,
        );

  ProductEntity _toEntity(ProductModel model) {
    return ProductEntity(
      productId: model.productId,
      name: model.name,
      variant: model.variant,
      size: model.size,
      categoryId: model.categoryId,
      sku: model.sku,
      barcode: model.barcode,
      hsnSacCode: model.hsnSacCode,
      basePrice: model.basePrice,
      wholesalePrice: model.wholesalePrice,
      retailPrice: model.retailPrice,
      customerPrice: model.customerPrice,
      gstRate: model.gstRate,
      stockQuantity: model.stockQuantity,
      lowStockAlertQty: model.lowStockAlertQty,
      imageUrl: model.imageUrl,
      isActive: model.isActive,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      createdByUid: model.createdByUid,
      updatedByUid: model.updatedByUid,
    );
  }

  ProductModel _toModel(ProductEntity entity) {
    return ProductModel(
      productId: entity.productId,
      name: entity.name,
      variant: entity.variant,
      size: entity.size,
      categoryId: entity.categoryId,
      sku: entity.sku,
      barcode: entity.barcode,
      hsnSacCode: entity.hsnSacCode,
      basePrice: entity.basePrice,
      wholesalePrice: entity.wholesalePrice,
      retailPrice: entity.retailPrice,
      customerPrice: entity.customerPrice,
      gstRate: entity.gstRate,
      stockQuantity: entity.stockQuantity,
      lowStockAlertQty: entity.lowStockAlertQty,
      imageUrl: entity.imageUrl,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdByUid: entity.createdByUid,
      updatedByUid: entity.updatedByUid,
    );
  }

  void seedInitial(List<ProductModel> initialProducts) {
    for (final product in initialProducts) {
      _cache.put(_toEntity(product));
    }
    _notifyStream();
  }

  void replaceWith(List<ProductModel> products) {
    _cache.clear();
    for (final product in products) {
      _cache.put(_toEntity(product));
    }
    _notifyStream();
  }

  void _notifyStream() {
    if (!_streamController.isClosed) {
      _streamController.add(_cache.getAll().where((p) => p.isActive).toList());
    }
  }

  @override
  Future<List<ProductEntity>> getProductsPaginated({
    int limit = 50,
    String? startAfterId,
    String? categoryId,
  }) async {
    final cached = _cache.getPaginated(
      limit: limit,
      startAfterId: startAfterId,
      filter: categoryId != null ? (p) => p.categoryId == categoryId : null,
    );

    if (cached.isNotEmpty) {
      return cached;
    }

    // 2. Remote fetch with Supabase first, fallback to Firestore
    if (SupabaseService.instance.isInitialized) {
      try {
        final supaData = await SupabaseService.instance.fetchProducts(tenantId);
        if (supaData.isNotEmpty) {
          final fetched = supaData
              .map((d) => _toEntity(ProductModel.fromMap(d, (d['product_id'] ?? d['id'] ?? '').toString())))
              .toList();
          _cache.putAll(fetched);
          _notifyStream();
          final paginated = _cache.getPaginated(
            limit: limit,
            startAfterId: startAfterId,
            filter: categoryId != null ? (p) => p.categoryId == categoryId : null,
          );
          if (paginated.isNotEmpty) return paginated;
        }
      } catch (_) {}
    }

    return cached;
  }

  @override
  Future<List<ProductEntity>> searchCatalog(String query, {int limit = 30}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return _cache.getAll().take(limit).toList();
    }
    return _cache
        .getAll()
        .where((p) =>
            p.name.toLowerCase().contains(clean) ||
            (p.sku != null && p.sku!.toLowerCase().contains(clean)) ||
            (p.barcode != null && p.barcode!.contains(clean)))
        .take(limit)
        .toList();
  }

  @override
  Future<ProductEntity?> getProductById(String productId) async {
    final local = _cache.get(productId);
    if (local != null) return local;

    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          final data = await client
              .from('products')
              .select('*')
              .eq('tenant_id', tenantId)
              .or('product_id.eq.$productId,id.eq.$productId')
              .maybeSingle();
          if (data != null) {
            final entity = _toEntity(ProductModel.fromMap(Map<String, dynamic>.from(data), productId));
            _cache.put(entity);
            return entity;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<void> saveProduct(ProductEntity product, {required String uid}) async {
    _cache.put(product);
    _notifyStream();

    final model = _toModel(product);

    if (SupabaseService.instance.isInitialized) {
      try {
        await SupabaseService.instance.upsertProduct(
          tenantId: tenantId,
          productData: model.toMap(),
        );
      } catch (_) {}
    }

  }

  @override
  Future<void> adjustStock(String productId, int deltaQty) async {
    final product = _cache.get(productId);
    if (product != null) {
      final updated = product.copyWith(
        stockQuantity: (product.stockQuantity + deltaQty).clamp(0, 999999),
        updatedAt: DateTime.now(),
      );
      _cache.put(updated);
      _notifyStream();
    }

  }

  @override
  Stream<List<ProductEntity>> watchActiveCatalog() {
    return _streamController.stream;
  }

  void dispose() {
    _streamController.close();
  }
}
