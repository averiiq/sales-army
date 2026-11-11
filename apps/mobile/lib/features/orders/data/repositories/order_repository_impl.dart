import 'dart:async';
import 'package:salesarmy/features/orders/domain/entities/order_entity.dart';
import 'package:salesarmy/features/orders/domain/repositories/i_order_repository.dart';
import 'package:salesarmy/core/cache/local_data_cache.dart';
import 'package:salesarmy/features/orders/data/models/order_model.dart';
import 'package:salesarmy/features/billing/data/models/transaction_item_snapshot.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

class OrderRepositoryImpl implements IOrderRepository {
  final String tenantId;
  final LocalDataCache<OrderEntity> _cache;
  final StreamController<List<OrderEntity>> _streamController = StreamController<List<OrderEntity>>.broadcast();

  OrderRepositoryImpl({
    required this.tenantId,
  }) : _cache = LocalDataCache<OrderEntity>(
          maxMemoryCapacity: 1000,
          idSelector: (order) => order.orderId,
        );

  OrderEntity _toEntity(OrderModel model) {
    return OrderEntity(
      orderId: model.orderId,
      shopId: model.shopId,
      createdByUid: model.createdByUid,
      status: model.status,
      items: model.items
          .map((item) => OrderItemEntity(
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                gstRate: item.gstRate,
                itemSubtotal: item.itemSubtotal,
                itemGst: item.itemGst,
                itemGrandTotal: item.itemGrandTotal,
              ))
          .toList(),
      subtotal: model.subtotal,
      totalGst: model.totalGst,
      grandTotal: model.grandTotal,
      deliveryNote: model.deliveryNote,
      placedAt: model.placedAt,
      deliveredAt: model.deliveredAt,
      createdAt: model.createdAt,
      updatedAt: model.updatedAt,
    );
  }

  OrderModel _toModel(OrderEntity entity) {
    return OrderModel(
      orderId: entity.orderId,
      shopId: entity.shopId,
      createdByUid: entity.createdByUid,
      status: entity.status,
      items: entity.items
          .map((item) => TransactionItemSnapshot(
                productId: item.productId,
                productName: item.productName,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                gstRate: item.gstRate,
                itemSubtotal: item.itemSubtotal,
                itemGst: item.itemGst,
                itemGrandTotal: item.itemGrandTotal,
              ))
          .toList(),
      subtotal: entity.subtotal,
      totalGst: entity.totalGst,
      grandTotal: entity.grandTotal,
      deliveryNote: entity.deliveryNote,
      placedAt: entity.placedAt,
      deliveredAt: entity.deliveredAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  void seedInitial(List<OrderModel> initialOrders) {
    for (final order in initialOrders) {
      _cache.put(_toEntity(order));
    }
    _notifyStream();
  }

  void replaceWith(List<OrderModel> orders) {
    _cache.clear();
    for (final order in orders) {
      _cache.put(_toEntity(order));
    }
    _notifyStream();
  }

  void _notifyStream() {
    if (!_streamController.isClosed) {
      _streamController.add(_cache.getAll().take(30).toList());
    }
  }

  @override
  Future<List<OrderEntity>> getOrdersPaginated({
    int limit = 50,
    String? startAfterId,
    String? shopId,
  }) async {
    // 1. Return from memory-bounded cache first
    final cached = _cache.getPaginated(
      limit: limit,
      startAfterId: startAfterId,
      filter: shopId != null ? (order) => order.shopId == shopId : null,
    );

    if (cached.isNotEmpty) {
      return cached;
    }

    // 2. Fetch page from Supabase if initialized, fallback to Firestore
    if (SupabaseService.instance.isInitialized) {
      try {
        final supaData = await SupabaseService.instance.fetchOrders(tenantId);
        if (supaData.isNotEmpty) {
          final fetched = supaData
              .map((d) => _toEntity(OrderModel.fromMap(d, (d['order_id'] ?? d['id'] ?? '').toString())))
              .toList();
          _cache.putAll(fetched);
          _notifyStream();
          final paginated = _cache.getPaginated(
            limit: limit,
            startAfterId: startAfterId,
            filter: shopId != null ? (order) => order.shopId == shopId : null,
          );
          if (paginated.isNotEmpty) return paginated;
        }
      } catch (_) {}
    }

    return cached;
  }

  @override
  Future<OrderEntity?> getOrderById(String orderId) async {
    final local = _cache.get(orderId);
    if (local != null) return local;

    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          final data = await client
              .from('orders')
              .select('*, order_items(*)')
              .eq('tenant_id', tenantId)
              .or('order_id.eq.$orderId,id.eq.$orderId')
              .maybeSingle();
          if (data != null) {
            final entity = _toEntity(OrderModel.fromMap(Map<String, dynamic>.from(data), orderId));
            _cache.put(entity);
            return entity;
          }
        }
      } catch (_) {}
    }

    return null;
  }

  @override
  Future<void> createOrder(OrderEntity order) async {
    _cache.put(order);
    _notifyStream();

    final model = _toModel(order);

    if (SupabaseService.instance.isInitialized) {
      try {
        final itemsData = model.items.map((i) => i.toMap()).toList();
        final orderMap = model.toMap()..remove('items');
        await SupabaseService.instance.insertOrder(
          tenantId: tenantId,
          orderData: orderMap,
          items: itemsData,
        );
      } catch (_) {}
    }

  }

  @override
  Future<void> updateOrderStatus(String orderId, String newStatus) async {
    final order = _cache.get(orderId);
    if (order != null) {
      final updated = order.copyWith(status: newStatus, updatedAt: DateTime.now());
      _cache.put(updated);
      _notifyStream();
    }

    if (SupabaseService.instance.isInitialized) {
      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client
              .from('orders')
              .update({
                'status': newStatus,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('tenant_id', tenantId)
              .or('order_id.eq.$orderId,id.eq.$orderId');
        }
      } catch (_) {}
    }

  }

  @override
  Future<void> deleteOrder(String orderId) async {
    _cache.remove(orderId);
    _notifyStream();

    if (SupabaseService.instance.isInitialized) {
      try {
        await SupabaseService.instance.deleteOrder(
          tenantId: tenantId,
          orderId: orderId,
        );
      } catch (_) {}
    }

  }

  @override
  Stream<List<OrderEntity>> watchRecentOrders({int limit = 20}) {
    return _streamController.stream;
  }

  void dispose() {
    _streamController.close();
  }
}
