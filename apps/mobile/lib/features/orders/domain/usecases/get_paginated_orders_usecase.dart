import 'package:salesarmy/features/orders/domain/entities/order_entity.dart';
import 'package:salesarmy/features/orders/domain/repositories/i_order_repository.dart';

class GetPaginatedOrdersUseCase {
  final IOrderRepository orderRepository;

  GetPaginatedOrdersUseCase({required this.orderRepository});

  Future<List<OrderEntity>> execute({
    int limit = 50,
    String? startAfterId,
    String? shopId,
  }) async {
    final boundedLimit = limit.clamp(1, 100);
    return orderRepository.getOrdersPaginated(
      limit: boundedLimit,
      startAfterId: startAfterId,
      shopId: shopId,
    );
  }
}
