import 'package:salesarmy/core/sync/repositories/i_sync_repository.dart';

class SyncDeltasUseCase {
  final ISyncRepository syncRepository;

  SyncDeltasUseCase({required this.syncRepository});

  Future<void> execute({
    List<String> entities = const ['shops', 'products', 'orders', 'invoices', 'payments'],
  }) async {
    // 1. Push all pending local mutations first (optimistic flush)
    await syncRepository.flushOutbox();

    // 2. Pull delta changes for each entity
    for (final entity in entities) {
      try {
        await syncRepository.pullDeltas(entity);
      } catch (_) {
        // Individual entity sync failure should not abort remaining entities
      }
    }
  }
}
