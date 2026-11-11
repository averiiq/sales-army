import 'package:salesarmy/features/orders/domain/entities/order_entity.dart';

abstract class IOrderRepository {
  /// Fetches orders with cursor pagination, optional shop filtering
  Future<List<OrderEntity>> getOrdersPaginated({
    int limit = 50,
    String? startAfterId,
    String? shopId,
  });

  /// Retrieves a single order by ID
  Future<OrderEntity?> getOrderById(String orderId);

  /// Optimistically writes order locally, queues idempotent mutation
  Future<void> createOrder(OrderEntity order);

  /// Updates order status (e.g. pending -> confirmed -> delivered)
  Future<void> updateOrderStatus(String orderId, String newStatus);

  /// Deletes an order locally and from remote store
  Future<void> deleteOrder(String orderId);

  /// Reactive stream strictly bounded to recent orders for the dashboard
  Stream<List<OrderEntity>> watchRecentOrders({int limit = 20});
}
