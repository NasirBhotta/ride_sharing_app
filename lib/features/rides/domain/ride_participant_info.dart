class RideParticipantInfo {
  const RideParticipantInfo({
    required this.userId,
    required this.fullName,
    this.phone,
    this.city,
    this.vehicleType,
    this.vehicleModel,
    this.vehicleColor,
    this.licensePlate,
  });

  final String userId;
  final String fullName;
  final String? phone;
  final String? city;
  final String? vehicleType;
  final String? vehicleModel;
  final String? vehicleColor;
  final String? licensePlate;

  bool get isRider => vehicleType != null;

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fullName': fullName,
      if (phone != null) 'phone': phone,
      if (city != null) 'city': city,
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (vehicleColor != null) 'vehicleColor': vehicleColor,
      if (licensePlate != null) 'licensePlate': licensePlate,
    };
  }

  factory RideParticipantInfo.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const RideParticipantInfo(userId: '', fullName: 'Unknown');
    }
    return RideParticipantInfo(
      userId: data['userId'] as String? ?? '',
      fullName: data['fullName'] as String? ?? 'Unknown',
      phone: data['phone'] as String?,
      city: data['city'] as String?,
      vehicleType: data['vehicleType'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehicleColor: data['vehicleColor'] as String?,
      licensePlate: data['licensePlate'] as String?,
    );
  }
}
