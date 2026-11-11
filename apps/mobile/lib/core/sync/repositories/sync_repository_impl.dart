import 'dart:async';
import 'package:salesarmy/core/sync/entities/mutation_entity.dart';
import 'package:salesarmy/core/sync/repositories/i_sync_repository.dart';
import 'package:salesarmy/core/sync/outbox_manager.dart';
import 'package:salesarmy/core/services/supabase_service.dart';

class SyncRepositoryImpl implements ISyncRepository {
  final String tenantId;
  final OutboxManager outboxManager;

  SyncRepositoryImpl({
    required this.tenantId,
    required this.outboxManager,
  });

  @override
  Future<void> enqueueMutation(MutationEntity mutation) async {
    // enqueue() returns false if a committed mutation with the same id
    // already exists — swallowing the duplicate here keeps call sites
    // idempotent after a crash between server ack and local commit.
    await outboxManager.enqueue(
      mutation.copyWith(payload: {...mutation.payload, 'tenantId': tenantId}),
    );
  }

  @override
  Future<List<MutationEntity>> getPendingMutations() async {
    return outboxManager.getPendingMutations().where((m) => m.payload['tenantId'] == tenantId).toList();
  }

  @override
  Future<void> markMutationCommitted(String mutationId) async {
    await outboxManager.markCommitted(mutationId);
  }

  @override
  Future<void> markMutationFailed(String mutationId, String error) async {
    await outboxManager.markFailed(mutationId, error);
  }

  @override
  Future<int> pullDeltas(String entityType, {int sinceTimestamp = 0}) async {
    return 0;
  }

  @override
  Future<void> flushOutbox() async {
    final pending = await getPendingMutations();
    if (pending.isEmpty) return;
    for (final mutation in pending) {
      try {
        final service = SupabaseService.instance;
        if (service.client == null || service.currentUser == null) throw StateError('An authenticated connection is required to sync');
        if (mutation.action.toUpperCase() != 'CREATE') throw UnsupportedError('Unsupported sync action: ${mutation.action}');
        final data = Map<String, dynamic>.from(mutation.payload);
        switch (mutation.entityType) {
          case 'orders':
            await service.insertOrder(tenantId: tenantId, orderData: data,
              items: (data['items'] as List).map((v) => Map<String, dynamic>.from(v as Map)).toList());
          case 'invoices':
            await service.insertInvoice(tenantId: tenantId, invoiceData: data);
          case 'payments':
            await service.insertPayment(tenantId: tenantId, paymentData: data);
          default:
            throw UnsupportedError('Unsupported sync entity: ${mutation.entityType}');
        }
        await outboxManager.markCommitted(mutation.mutationId);
      } catch (e) {
        await outboxManager.markFailed(mutation.mutationId, e.toString());
      }
    }
  }

  @override
  Stream<int> watchPendingMutationCount() {
    return outboxManager.pendingCountStream;
  }
}
