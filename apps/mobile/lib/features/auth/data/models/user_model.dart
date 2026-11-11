class UserModel {
  final String uid;
  final String? name;
  final String? email;
  final String? mobile;
  final String? whatsappNumber;
  final String? role; // super_admin, distributor, agency_staff
  final String? tenantId;
  final String? status; // active, pending, paused, cancelled, suspended
  final String? profileImageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  UserModel({
    required this.uid,
    this.name,
    this.email,
    this.mobile,
    this.whatsappNumber,
    this.role,
    this.tenantId,
    this.status,
    this.profileImageUrl,
    this.createdAt,
    this.updatedAt,
    this.lastLoginAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      name: data['name'] ?? data['full_name'],
      email: data['email'],
      mobile: data['mobile'] ?? data['phone'],
      whatsappNumber: data['whatsappNumber'] ?? data['whatsapp_number'],
      role: data['role'],
      tenantId: data['tenantId'] ?? data['tenant_id'],
      status: data['status'] ?? data['account_status'],
      profileImageUrl: data['profileImageUrl'] ?? data['photo_url'],
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      updatedAt: _parseDateTime(data['updatedAt'] ?? data['updated_at']),
      lastLoginAt: _parseDateTime(data['lastLoginAt'] ?? data['last_login_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'mobile': mobile,
      'whatsappNumber': whatsappNumber,
      'role': role,
      'tenantId': tenantId,
      'status': status,
      'profileImageUrl': profileImageUrl,
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'updatedAt': updatedAt != null ? updatedAt!.toIso8601String() : DateTime.now().toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
    };
  }
}
