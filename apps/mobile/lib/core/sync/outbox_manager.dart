import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:salesarmy/core/sync/entities/mutation_entity.dart';

/// Enqueues local mutations and tracks their lifecycle through the sync
/// pipeline.
///
/// Hardening (post C5+C6 fixes):
/// * Committed mutations are retained (not hard-deleted) for
///   [_committedRetentionMs], so a crash between the server ack and
///   [markCommitted] cannot cause a duplicate submission.
/// * Failed mutations get exponential backoff ([_backoffBaseMs] *
///   2^retry, capped at [_backoffMaxMs]). After [_maxRetries]
///   attempts a mutation is parked as [MutationStatus.terminallyFailed]
///   so the pending counter is not stuck forever.
class OutboxManager {
  static const String _storageKey = 'salesarmy_outbox_mutations_v1';

  static const int _maxRetries = 10;
  static const int _backoffBaseMs = 10 * 1000; // 10s
  static const int _backoffMaxMs = 60 * 60 * 1000; // 1h
  static const int _committedRetentionMs = 7 * 24 * 60 * 60 * 1000; // 7d

  final List<MutationEntity> _queue = [];
  final StreamController<int> _pendingCountController =
      StreamController<int>.broadcast();

  Stream<int> get pendingCountStream => _pendingCountController.stream;

  int get pendingCount => _queue
      .where((m) =>
          m.status != MutationStatus.committed &&
          m.status != MutationStatus.terminallyFailed)
      .length;

  int get terminallyFailedCount =>
      _queue.where((m) => m.status == MutationStatus.terminallyFailed).length;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(raw);
        _queue.clear();
        for (final item in decoded) {
          _queue.add(MutationEntity.fromMap(Map<String, dynamic>.from(item as Map)));
        }
      }
      await _pruneExpiredCommitted();
      _notifyCount();
    } catch (e) {
      // Corrupted queue — log and clear to prevent stuck state.
      _queue.clear();
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_storageKey);
      } catch (_) {}
      if (e is! FormatException) {
        rethrow;
      }
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final data = jsonEncode(_queue.map((e) => e.toMap()).toList());
    if (!await prefs.setString(_storageKey, data)) {
      throw StateError('Unable to persist pending changes');
    }
    _notifyCount();
  }

  Future<void> _pruneExpiredCommitted() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final before = _queue.length;
    _queue.removeWhere((m) =>
        m.status == MutationStatus.committed &&
        m.commitTimeEpochMs != null &&
        now - m.commitTimeEpochMs! > _committedRetentionMs);
    if (_queue.length != before) {
      await _persist();
    }
  }

  void _notifyCount() {
    if (!_pendingCountController.isClosed) {
      _pendingCountController.add(pendingCount);
    }
  }

  /// Returns true if the mutation was accepted, false if it was already
  /// committed (duplicate submission guard).
  Future<bool> enqueue(MutationEntity mutation) async {
    final existingIndex =
        _queue.indexWhere((m) => m.mutationId == mutation.mutationId);
    if (existingIndex != -1) {
      final existing = _queue[existingIndex];
      // Already acknowledged by server — reject the duplicate so we don't
      // re-submit and double-create the resource.
      if (existing.status == MutationStatus.committed) {
        return false;
      }
      _queue[existingIndex] = mutation;
    } else {
      _queue.add(mutation);
    }
    await _persist();
    return true;
  }

  List<MutationEntity> getPendingMutations({int limit = 50}) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return _queue
        .where((m) =>
            (m.status == MutationStatus.pending ||
                m.status == MutationStatus.failed) &&
            (m.nextRetryAtEpochMs == null || m.nextRetryAtEpochMs! <= now))
        .take(limit)
        .toList();
  }

  Future<void> markCommitted(String mutationId) async {
    final index = _queue.indexWhere((m) => m.mutationId == mutationId);
    if (index != -1) {
      // Retain as a committed-id gravestone so a replayed enqueue is
      // detected as a duplicate.
      _queue[index] = _queue[index].copyWith(
        status: MutationStatus.committed,
        commitTimeEpochMs: DateTime.now().millisecondsSinceEpoch,
        errorMessage: null,
        nextRetryAtEpochMs: null,
      );
      await _persist();
    }
  }

  Future<void> markFailed(String mutationId, String error) async {
    final index = _queue.indexWhere((m) => m.mutationId == mutationId);
    if (index == -1) return;
    final current = _queue[index];
    final nextRetry = current.retryCount + 1;
    if (nextRetry >= _maxRetries) {
      _queue[index] = current.copyWith(
        status: MutationStatus.terminallyFailed,
        retryCount: nextRetry,
        errorMessage: error,
        nextRetryAtEpochMs: null,
      );
    } else {
      final backoff = math.min(
        _backoffBaseMs * math.pow(2, nextRetry).toInt(),
        _backoffMaxMs,
      );
      _queue[index] = current.copyWith(
        status: MutationStatus.failed,
        retryCount: nextRetry,
        errorMessage: error,
        nextRetryAtEpochMs: DateTime.now().millisecondsSinceEpoch + backoff,
      );
    }
    await _persist();
  }

  /// Manually clear terminally-failed mutations (e.g. from a user-triggered
  /// "discard failed" admin action).
  Future<void> clearTerminallyFailed() async {
    final before = _queue.length;
    _queue.removeWhere((m) => m.status == MutationStatus.terminallyFailed);
    if (_queue.length != before) {
      await _persist();
    }
  }

  void dispose() {
    _pendingCountController.close();
  }
}
