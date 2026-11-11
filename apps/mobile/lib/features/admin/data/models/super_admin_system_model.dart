class SuperAdminSystemModel {
  final String documentId;
  final bool isRegistrationOpen;
  final String currentAppVersion;
  final String minimumAppVersion;

  final int totalTenants;
  final int totalActiveTenants;

  final DateTime? updatedAt;

  SuperAdminSystemModel({
    required this.documentId,
    this.isRegistrationOpen = true,
    required this.currentAppVersion,
    required this.minimumAppVersion,
    this.totalTenants = 0,
    this.totalActiveTenants = 0,
    this.updatedAt,
  });

  factory SuperAdminSystemModel.fromMap(Map<String, dynamic> data, String documentId) {
    return SuperAdminSystemModel(
      documentId: documentId,
      isRegistrationOpen: data['isRegistrationOpen'] ?? true,
      currentAppVersion: data['currentAppVersion'] ?? '1.0.0',
      minimumAppVersion: data['minimumAppVersion'] ?? '1.0.0',
      totalTenants: (data['totalTenants'] as num?)?.toInt() ?? 0,
      totalActiveTenants: (data['totalActiveTenants'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.tryParse(data['updatedAt']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isRegistrationOpen': isRegistrationOpen,
      'currentAppVersion': currentAppVersion,
      'minimumAppVersion': minimumAppVersion,
      'totalTenants': totalTenants,
      'totalActiveTenants': totalActiveTenants,
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }
}
