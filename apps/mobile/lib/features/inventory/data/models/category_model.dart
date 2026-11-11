class CategoryModel {
  final String categoryId;
  final String name;
  final String? description;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CategoryModel({
    required this.categoryId,
    required this.name,
    this.description,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CategoryModel(
      categoryId: data['categoryId'] ?? documentId,
      name: data['name'] ?? '',
      description: data['description'],
      isActive: data['isActive'] ?? true,
      createdAt: DateTime.tryParse(data['createdAt']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'name': name,
      'description': description,
      'isActive': isActive,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }
}
