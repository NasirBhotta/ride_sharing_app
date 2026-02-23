import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_type.dart';

enum RideStatus { requested, accepted, inProgress, completed, cancelled }

class RideRequest {
  RideRequest({
    required this.id,
    required this.customerId,
    required this.riderId,
    required this.pickup,
    required this.dropoff,
    required this.status,
    required this.vehicleType,
    required this.estimatedFare,
    required this.distanceKm,
    required this.createdAt,
  });

  final String id;
  final String customerId;
  final String? riderId;
  final String pickup;
  final String dropoff;
  final RideStatus status;
  final VehicleType vehicleType;
  final double estimatedFare;
  final double distanceKm;
  final DateTime? createdAt;

  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'riderId': riderId,
      'pickup': pickup,
      'dropoff': dropoff,
      'status': status.name,
      'vehicleType': vehicleType.id,
      'estimatedFare': estimatedFare,
      'distanceKm': distanceKm,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory RideRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Ride document ${doc.id} has no data');
    }

    final statusRaw = data['status'] as String? ?? RideStatus.requested.name;
    final status = RideStatus.values.firstWhere(
      (value) => value.name == statusRaw,
      orElse: () => RideStatus.requested,
    );

    return RideRequest(
      id: doc.id,
      customerId: data['customerId'] as String? ?? '',
      riderId: data['riderId'] as String?,
      pickup: data['pickup'] as String? ?? 'Unknown pickup',
      dropoff: data['dropoff'] as String? ?? 'Unknown dropoff',
      status: status,
      vehicleType: VehicleTypeX.fromId(data['vehicleType'] as String? ?? 'car'),
      estimatedFare: (data['estimatedFare'] as num?)?.toDouble() ?? 0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
