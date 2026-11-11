import 'package:salesarmy/core/sync/entities/mutation_entity.dart';

abstract class ISyncRepository {
  /// Enqueues a local mutation to the outbox
  Future<void> enqueueMutation(MutationEntity mutation);

  /// Retrieves all pending mutations waiting for server push
  Future<List<MutationEntity>> getPendingMutations();

  /// Marks a mutation as successfully committed on the server
  Future<void> markMutationCommitted(String mutationId);

  /// Marks a mutation as failed with error details for backoff retry
  Future<void> markMutationFailed(String mutationId, String error);

  /// Pulls delta changes from the server since given epoch timestamp
  Future<int> pullDeltas(String entityType, {int sinceTimestamp = 0});

  /// Flushes all pending outbox mutations to the server in an atomic batch
  Future<void> flushOutbox();

  /// Reactive stream of pending mutation count for sync status indicators
  Stream<int> watchPendingMutationCount();
}
