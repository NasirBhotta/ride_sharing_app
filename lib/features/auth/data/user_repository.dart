import 'package:cloud_firestore/cloud_firestore.dart';

import '../../rides/domain/ride_participant_info.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<RideParticipantInfo> getCustomerSnapshot(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return _buildCustomerInfo(userId, doc.data());
  }

  Future<RideParticipantInfo> getRiderSnapshot(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return _buildRiderInfo(userId, doc.data());
  }

  RideParticipantInfo _buildCustomerInfo(
    String userId,
    Map<String, dynamic>? data,
  ) {
    final profile = data?['customerProfile'] as Map<String, dynamic>?;
    return RideParticipantInfo(
      userId: userId,
      fullName: data?['fullName'] as String? ?? 'Customer',
      phone: profile?['phone'] as String?,
      city: profile?['city'] as String?,
    );
  }

  RideParticipantInfo _buildRiderInfo(
    String userId,
    Map<String, dynamic>? data,
  ) {
    final profile = data?['riderProfile'] as Map<String, dynamic>?;
    return RideParticipantInfo(
      userId: userId,
      fullName: data?['fullName'] as String? ?? 'Rider',
      phone: profile?['phone'] as String?,
      city: profile?['city'] as String?,
      vehicleType: profile?['vehicleType'] as String?,
      vehicleModel: profile?['vehicleModel'] as String?,
      vehicleColor: profile?['vehicleColor'] as String?,
      licensePlate: profile?['licensePlate'] as String?,
    );
  }
}
