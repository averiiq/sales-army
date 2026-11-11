class VisitModel {
  final String visitId;
  final String shopId;
  final String distributorUid;
  
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  
  final double? latitude;
  final double? longitude;
  
  final String? notes;
  final String? photoUrl;
  final bool orderPlaced;

  VisitModel({
    required this.visitId,
    required this.shopId,
    required this.distributorUid,
    required this.checkInTime,
    this.checkOutTime,
    this.latitude,
    this.longitude,
    this.notes,
    this.photoUrl,
    this.orderPlaced = false,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is String) return DateTime.tryParse(val);
    if (val is DateTime) return val;
    return null;
  }

  factory VisitModel.fromMap(Map<String, dynamic> data, String documentId) {
    return VisitModel(
      visitId: data['visitId'] ?? documentId,
      shopId: data['shopId'] ?? '',
      distributorUid: data['distributorUid'] ?? data['salesPersonUid'] ?? '',
      checkInTime: _parseDateTime(data['checkInTime'] ?? data['scheduledDate'] ?? data['createdAt']) ?? DateTime.now(),
      checkOutTime: _parseDateTime(data['checkOutTime'] ?? data['completedDate']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      notes: data['notes'],
      photoUrl: data['photoUrl'],
      orderPlaced: data['orderPlaced'] ?? data['orderTaken'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'visitId': visitId,
      'shopId': shopId,
      'distributorUid': distributorUid,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'notes': notes,
      'photoUrl': photoUrl,
      'orderPlaced': orderPlaced,
    };
  }

  VisitModel copyWith({
    String? visitId,
    String? shopId,
    String? distributorUid,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? latitude,
    double? longitude,
    String? notes,
    String? photoUrl,
    bool? orderPlaced,
  }) {
    return VisitModel(
      visitId: visitId ?? this.visitId,
      shopId: shopId ?? this.shopId,
      distributorUid: distributorUid ?? this.distributorUid,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      notes: notes ?? this.notes,
      photoUrl: photoUrl ?? this.photoUrl,
      orderPlaced: orderPlaced ?? this.orderPlaced,
    );
  }
}
