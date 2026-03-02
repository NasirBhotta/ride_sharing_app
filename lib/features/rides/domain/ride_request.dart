import 'package:cloud_firestore/cloud_firestore.dart';

import 'vehicle_type.dart';

enum RideStatus { requested, booked, arrived, inProgress, completed, cancelled }

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
    required this.pickupLat,
    required this.pickupLng,
    required this.dropoffLat,
    required this.dropoffLng,
    required this.customerLat,
    required this.customerLng,
    required this.riderLat,
    required this.riderLng,
    required this.searchRadiusKm,
    required this.maxRadiusKm,
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
  final double? pickupLat;
  final double? pickupLng;
  final double? dropoffLat;
  final double? dropoffLng;
  final double? customerLat;
  final double? customerLng;
  final double? riderLat;
  final double? riderLng;
  final double searchRadiusKm;
  final double maxRadiusKm;

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
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'customerLat': customerLat,
      'customerLng': customerLng,
      'riderLat': riderLat,
      'riderLng': riderLng,
      'searchRadiusKm': searchRadiusKm,
      'maxRadiusKm': maxRadiusKm,
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
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble(),
      customerLat: (data['customerLat'] as num?)?.toDouble(),
      customerLng: (data['customerLng'] as num?)?.toDouble(),
      riderLat: (data['riderLat'] as num?)?.toDouble(),
      riderLng: (data['riderLng'] as num?)?.toDouble(),
      searchRadiusKm: (data['searchRadiusKm'] as num?)?.toDouble() ?? 2.0,
      maxRadiusKm: (data['maxRadiusKm'] as num?)?.toDouble() ?? 8.0,
    );
  }
}
