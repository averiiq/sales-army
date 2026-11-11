enum MutationStatus {
  pending,
  processing,
  committed,
  failed,
  terminallyFailed,
}

class MutationEntity {
  final String mutationId; // UUIDv4 idempotency key
  final String entityType; // 'orders', 'payments', 'shops', 'visits'
  final String action; // 'CREATE', 'UPDATE', 'DELETE'
  final Map<String, dynamic> payload;
  final int clientTimestampEpochMs;
  final MutationStatus status;
  final int retryCount;
  final String? errorMessage;
  final int? commitTimeEpochMs;
  final int? nextRetryAtEpochMs;

  const MutationEntity({
    required this.mutationId,
    required this.entityType,
    required this.action,
    required this.payload,
    required this.clientTimestampEpochMs,
    this.status = MutationStatus.pending,
    this.retryCount = 0,
    this.errorMessage,
    this.commitTimeEpochMs,
    this.nextRetryAtEpochMs,
  });

  MutationEntity copyWith({
    String? mutationId,
    String? entityType,
    String? action,
    Map<String, dynamic>? payload,
    int? clientTimestampEpochMs,
    MutationStatus? status,
    int? retryCount,
    String? errorMessage,
    int? commitTimeEpochMs,
    int? nextRetryAtEpochMs,
  }) {
    return MutationEntity(
      mutationId: mutationId ?? this.mutationId,
      entityType: entityType ?? this.entityType,
      action: action ?? this.action,
      payload: payload ?? this.payload,
      clientTimestampEpochMs: clientTimestampEpochMs ?? this.clientTimestampEpochMs,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      errorMessage: errorMessage ?? this.errorMessage,
      commitTimeEpochMs: commitTimeEpochMs ?? this.commitTimeEpochMs,
      nextRetryAtEpochMs: nextRetryAtEpochMs ?? this.nextRetryAtEpochMs,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'mutationId': mutationId,
      'entityType': entityType,
      'action': action,
      'payload': payload,
      'clientTimestampEpochMs': clientTimestampEpochMs,
      'status': status.name,
      'retryCount': retryCount,
      'errorMessage': errorMessage,
      'commitTimeEpochMs': commitTimeEpochMs,
      'nextRetryAtEpochMs': nextRetryAtEpochMs,
    };
  }

  factory MutationEntity.fromMap(Map<String, dynamic> map) {
    return MutationEntity(
      mutationId: map['mutationId'] as String? ?? '',
      entityType: map['entityType'] as String? ?? '',
      action: map['action'] as String? ?? 'CREATE',
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      clientTimestampEpochMs: (map['clientTimestampEpochMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      status: MutationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MutationStatus.pending,
      ),
      retryCount: (map['retryCount'] as num?)?.toInt() ?? 0,
      errorMessage: map['errorMessage'] as String?,
      commitTimeEpochMs: (map['commitTimeEpochMs'] as num?)?.toInt(),
      nextRetryAtEpochMs: (map['nextRetryAtEpochMs'] as num?)?.toInt(),
    );
  }
}
