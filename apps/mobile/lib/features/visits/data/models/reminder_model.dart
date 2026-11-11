class ReminderModel {
  final String reminderId;
  final String shopId;
  final String? shopName;
  final String assignedToUid;
  
  final DateTime dueDate;
  final String description;
  final String? title;
  final String purpose; // 'payment', 'visit', 'reorder', 'cheque', 'invoice', 'general'
  final String priority; // 'high', 'medium', 'normal'
  final String? note;
  final bool isCompleted;
  
  final DateTime? createdAt;

  ReminderModel({
    required this.reminderId,
    required this.shopId,
    this.shopName,
    required this.assignedToUid,
    required this.dueDate,
    required this.description,
    this.title,
    this.purpose = 'payment',
    this.priority = 'medium',
    this.note,
    this.isCompleted = false,
    this.createdAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory ReminderModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ReminderModel(
      reminderId: data['reminderId'] ?? documentId,
      shopId: data['shopId'] ?? '',
      shopName: data['shopName'] as String?,
      assignedToUid: data['assignedToUid'] ?? data['assignedTo'] ?? '',
      dueDate: _parseDateTime(data['dueDate'] ?? data['dueAt']) ?? DateTime.now(),
      description: data['description'] ?? '',
      title: data['title'] as String?,
      purpose: data['purpose'] ?? 'payment',
      priority: data['priority'] ?? 'medium',
      note: data['note'] as String?,
      isCompleted: data['isCompleted'] == true || data['status'] == 'completed',
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reminderId': reminderId,
      'shopId': shopId,
      if (shopName != null) 'shopName': shopName,
      'assignedToUid': assignedToUid,
      'dueDate': dueDate.toIso8601String(),
      'description': description,
      if (title != null) 'title': title,
      'purpose': purpose,
      'priority': priority,
      if (note != null) 'note': note,
      'isCompleted': isCompleted,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }

  ReminderModel copyWith({
    String? reminderId,
    String? shopId,
    String? shopName,
    String? assignedToUid,
    DateTime? dueDate,
    String? description,
    String? title,
    String? purpose,
    String? priority,
    String? note,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return ReminderModel(
      reminderId: reminderId ?? this.reminderId,
      shopId: shopId ?? this.shopId,
      shopName: shopName ?? this.shopName,
      assignedToUid: assignedToUid ?? this.assignedToUid,
      dueDate: dueDate ?? this.dueDate,
      description: description ?? this.description,
      title: title ?? this.title,
      purpose: purpose ?? this.purpose,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
