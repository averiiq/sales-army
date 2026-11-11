import 'dart:math';
import 'package:salesarmy/features/orders/domain/entities/order_entity.dart';
import 'package:salesarmy/core/sync/entities/mutation_entity.dart';
import 'package:salesarmy/features/orders/domain/repositories/i_order_repository.dart';
import 'package:salesarmy/core/sync/repositories/i_sync_repository.dart';

class CreateOrderUseCase {
  final IOrderRepository orderRepository;
  final ISyncRepository syncRepository;

  CreateOrderUseCase({
    required this.orderRepository,
    required this.syncRepository,
  });

  /// Generates a RFC4122 v4 UUID without external package dependency
  String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  Future<OrderEntity> execute({
    required String shopId,
    required String createdByUid,
    required List<OrderItemEntity> items,
    String? deliveryNote,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Order cannot be created with empty items');
    }

    double subtotal = 0.0;
    double totalGst = 0.0;

    for (final item in items) {
      if (item.quantity <= 0) {
        throw ArgumentError('Invalid item quantity for product ${item.productId}');
      }
      subtotal += item.itemSubtotal;
      totalGst += item.itemGst;
    }

    final grandTotal = subtotal + totalGst;
    final now = DateTime.now();
    final mutationId = 'mut_${_generateUuidV4()}';
    final orderId = 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}-${Random().nextInt(90000) + 10000}';

    final order = OrderEntity(
      orderId: orderId,
      shopId: shopId,
      createdByUid: createdByUid,
      status: 'pending',
      items: items,
      subtotal: double.parse(subtotal.toStringAsFixed(2)),
      totalGst: double.parse(totalGst.toStringAsFixed(2)),
      grandTotal: double.parse(grandTotal.toStringAsFixed(2)),
      deliveryNote: deliveryNote,
      placedAt: now,
      createdAt: now,
      updatedAt: now,
      clientMutationId: mutationId,
    );

    // 1. Save locally with optimistic UI response
    await orderRepository.createOrder(order);

    // 2. Queue mutation in outbox for idempotent server synchronization
    await syncRepository.enqueueMutation(
      MutationEntity(
        mutationId: mutationId,
        entityType: 'orders',
        action: 'CREATE',
        payload: {
          'orderId': order.orderId,
          'shopId': order.shopId,
          'createdByUid': order.createdByUid,
          'subtotal': order.subtotal,
          'totalGst': order.totalGst,
          'grandTotal': order.grandTotal,
          'items': items.map((e) => {
            'productId': e.productId,
            'productName': e.productName,
            'quantity': e.quantity,
            'unitPrice': e.unitPrice,
            'gstRate': e.gstRate,
            'itemSubtotal': e.itemSubtotal,
            'itemGst': e.itemGst,
            'itemGrandTotal': e.itemGrandTotal,
          }).toList(),
          'deliveryNote': deliveryNote,
          'placedAt': now.toIso8601String(),
        },
        clientTimestampEpochMs: now.millisecondsSinceEpoch,
      ),
    );

    return order;
  }
}
