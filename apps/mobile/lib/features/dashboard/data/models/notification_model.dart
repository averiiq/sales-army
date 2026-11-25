class NotificationModel {
  final String id;
  final String type; // 'payment_due', 'payment', 'inventory', 'order', 'sync', 'system'
  final String title;
  final String message;
  final String? targetUid;
  final bool isRead;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.targetUid,
    this.isRead = false,
    required this.createdAt,
  });

  NotificationModel copyWith({
    String? id,
    String? type,
    String? title,
    String? message,
    String? targetUid,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      targetUid: targetUid ?? this.targetUid,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      if (targetUid != null) 'targetUid': targetUid,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      // Handle Firestore Timestamp
      try {
        final toDate = (val as dynamic).toDate;
        if (toDate is Function) {
          return toDate() as DateTime;
        }
      } catch (_) {}
      return DateTime.now();
    }

    return NotificationModel(
      id: docId,
      type: map['type'] as String? ?? 'system',
      title: map['title'] as String? ?? 'SalesArmy Notification',
      message: map['message'] as String? ?? (map['detail'] as String? ?? map['summary'] as String? ?? ''),
      // Rows from the notifications table use snake_case column names.
      targetUid: (map['targetUid'] ?? map['target_uid'])?.toString(),
      isRead: (map['isRead'] ?? map['is_read']) as bool? ?? false,
      createdAt: parseDate(map['createdAt'] ?? map['created_at'] ?? map['timestamp']),
    );
  }
}
