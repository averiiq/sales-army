class SyncCursorEntity {
  final String entityType;
  final int lastSyncedAtEpochMs;
  final String? lastEvaluatedKey;
  final int version;

  const SyncCursorEntity({
    required this.entityType,
    required this.lastSyncedAtEpochMs,
    this.lastEvaluatedKey,
    this.version = 1,
  });

  SyncCursorEntity copyWith({
    String? entityType,
    int? lastSyncedAtEpochMs,
    String? lastEvaluatedKey,
    int? version,
  }) {
    return SyncCursorEntity(
      entityType: entityType ?? this.entityType,
      lastSyncedAtEpochMs: lastSyncedAtEpochMs ?? this.lastSyncedAtEpochMs,
      lastEvaluatedKey: lastEvaluatedKey ?? this.lastEvaluatedKey,
      version: version ?? this.version,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'entityType': entityType,
      'lastSyncedAtEpochMs': lastSyncedAtEpochMs,
      'lastEvaluatedKey': lastEvaluatedKey,
      'version': version,
    };
  }

  factory SyncCursorEntity.fromMap(Map<String, dynamic> map) {
    return SyncCursorEntity(
      entityType: map['entityType'] as String? ?? '',
      lastSyncedAtEpochMs: (map['lastSyncedAtEpochMs'] as num?)?.toInt() ?? 0,
      lastEvaluatedKey: map['lastEvaluatedKey'] as String?,
      version: (map['version'] as num?)?.toInt() ?? 1,
    );
  }
}
