class ExpenseModel {
  final String id;
  final String title;
  final String category; // 'Fuel / Transport', 'Food & Tea', 'Warehouse & Rent', 'Packing', 'Vehicle Maintenance', 'Miscellaneous'
  final double amount;
  final String paymentMode; // 'Cash', 'UPI', 'Bank Transfer'
  final DateTime date;
  final String? notes;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    this.paymentMode = 'Cash',
    required this.date,
    this.notes,
    required this.createdAt,
  });

  ExpenseModel copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    String? paymentMode,
    DateTime? date,
    String? notes,
    DateTime? createdAt,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      date: date ?? this.date,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'paymentMode': paymentMode,
      'date': date.toIso8601String(),
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      title: map['title'] as String? ?? 'General Expense',
      category: map['category'] as String? ?? 'Miscellaneous',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMode: map['paymentMode'] as String? ?? 'Cash',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
