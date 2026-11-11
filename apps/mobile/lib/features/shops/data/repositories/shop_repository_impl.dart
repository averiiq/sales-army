import 'dart:async';
import 'package:salesarmy/features/shops/domain/entities/shop_entity.dart';
import 'package:salesarmy/features/shops/domain/repositories/i_shop_repository.dart';
import 'package:salesarmy/core/cache/local_data_cache.dart';
import 'package:salesarmy/features/shops/data/models/shop_model.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

class ShopRepositoryImpl implements IShopRepository {
  final String tenantId;
  final LocalDataCache<ShopEntity> _cache;
  final StreamController<List<ShopEntity>> _streamController = StreamController<List<ShopEntity>>.broadcast();

  ShopRepositoryImpl({
    required this.tenantId,
  }) : _cache = LocalDataCache<ShopEntity>(
          maxMemoryCapacity: 2000,
          idSelector: (shop) => shop.shopId,
        );

  ShopEntity _toEntity(ShopModel model) {
    return ShopEntity(
      shopId: model.shopId,
      shopName: model.shopName,
      ownerName: model.ownerName,
      phone: model.phone,
      whatsappNumber: model.whatsappNumber,
      businessType: model.businessType,
      categoryId: model.categoryId,
      gstin: model.gstin,
      address: model.address,
      visitFrequency: model.visitFrequency,
      creditLimit: model.creditLimit,
      currentOutstanding: model.currentOutstanding,
      latitude: model.latitude,
      longitude: model.longitude,
      imageUrl: model.imageUrl,
      notes: model.notes,
      isActive: model.isActive,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
      createdByUid: model.createdByUid,
      updatedByUid: model.updatedByUid,
    );
  }

  ShopModel _toModel(ShopEntity entity) {
    return ShopModel(
      shopId: entity.shopId,
      shopName: entity.shopName,
      ownerName: entity.ownerName,
      phone: entity.phone,
      whatsappNumber: entity.whatsappNumber,
      businessType: entity.businessType,
      categoryId: entity.categoryId,
      gstin: entity.gstin,
      address: entity.address,
      visitFrequency: entity.visitFrequency,
      creditLimit: entity.creditLimit,
      currentOutstanding: entity.currentOutstanding,
      latitude: entity.latitude,
      longitude: entity.longitude,
      imageUrl: entity.imageUrl,
      notes: entity.notes,
      isActive: entity.isActive,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      createdByUid: entity.createdByUid,
      updatedByUid: entity.updatedByUid,
    );
  }

  void seedInitial(List<ShopModel> initialShops) {
    for (final shop in initialShops) {
      _cache.put(_toEntity(shop));
    }
    _notifyStream();
  }

  void replaceWith(List<ShopModel> shops) {
    _cache.clear();
    for (final shop in shops) {
      _cache.put(_toEntity(shop));
    }
    _notifyStream();
  }

  void _notifyStream() {
    if (!_streamController.isClosed) {
      _streamController.add(_cache.getAll().take(50).toList());
    }
  }

  @override
  Future<List<ShopEntity>> getShopsPaginated({
    int limit = 50,
    String? startAfterId,
  }) async {
    // 1. Check local cache first (Instant zero-latency response)
    final cached = _cache.getPaginated(limit: limit, startAfterId: startAfterId);
    if (cached.isNotEmpty) {
      return cached;
    }

    // 2. Fetch page from remote data source if cache miss
    if (SupabaseService.instance.isInitialized) {
      try {
        final supaShops = await SupabaseService.instance.fetchShops(tenantId);
        if (supaShops.isNotEmpty) {
          final fetched = supaShops
              .map((d) => _toEntity(ShopModel.fromMap(d, (d['shop_id'] ?? d['id'] ?? '').toString())))
              .toList();
          _cache.putAll(fetched);
          _notifyStream();
          final paginated = _cache.getPaginated(limit: limit, startAfterId: startAfterId);
          if (paginated.isNotEmpty) return paginated;
        }
      } catch (_) {}
    }

    return cached;
  }

  @override
  Future<List<ShopEntity>> searchShops(String query, {int limit = 20}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return _cache.getAll().take(limit).toList();
    }
    return _cache
        .getAll()
        .where((s) =>
            s.shopName.toLowerCase().contains(clean) ||
            s.ownerName.toLowerCase().contains(clean) ||
            (s.phone != null && s.phone!.contains(clean)) ||
            (s.gstin != null && s.gstin!.toLowerCase().contains(clean)))
        .take(limit)
        .toList();
  }

  @override
  Future<ShopEntity?> getShopById(String shopId) async {
    final local = _cache.get(shopId);
    if (local != null) return local;

    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          final data = await client
              .from('shops')
              .select('*')
              .eq('tenant_id', tenantId)
              .or('shop_id.eq.$shopId,id.eq.$shopId')
              .maybeSingle();
          if (data != null) {
            final entity = _toEntity(ShopModel.fromMap(Map<String, dynamic>.from(data), shopId));
            _cache.put(entity);
            return entity;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<void> saveShop(ShopEntity shop, {required String uid}) async {
    _cache.put(shop);
    _notifyStream();

    final model = _toModel(shop);

    if (SupabaseService.instance.isInitialized) {
      try {
        await SupabaseService.instance.upsertShop(
          tenantId: tenantId,
          shopData: model.toMap(),
        );
      } catch (_) {}
    }

  }

  @override
  Future<void> updateOutstandingBalance(String shopId, double deltaAmount) async {
    final shop = _cache.get(shopId);
    if (shop != null) {
      final updated = shop.copyWith(
        currentOutstanding: (shop.currentOutstanding + deltaAmount).clamp(0.0, double.infinity),
        updatedAt: DateTime.now(),
      );
      _cache.put(updated);
      _notifyStream();
    }

  }

  @override
  Stream<List<ShopEntity>> watchRecentShops({int limit = 20}) {
    return _streamController.stream;
  }

  void dispose() {
    _streamController.close();
  }
}
