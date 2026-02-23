import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/ride_request.dart';

class RideRepository {
  RideRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _rides =>
      _firestore.collection('rides');

  Future<String> requestRide(RideRequest request) async {
    final doc = await _rides.add(request.toFirestore());
    return doc.id;
  }

  Stream<RideRequest> watchRide(String rideId) {
    return _rides
        .doc(rideId)
        .snapshots()
        .map((doc) => RideRequest.fromDoc(doc));
  }

  Future<void> cancelRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideStatus.cancelled.name,
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<RideRequest>> watchRequestedRides() {
    return _rides
        .where('status', isEqualTo: RideStatus.requested.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RideRequest.fromDoc(doc))
              .toList(growable: false),
        );
  }

  Future<void> acceptRide({
    required String rideId,
    required String riderId,
  }) async {
    await _rides.doc(rideId).update({
      'status': RideStatus.accepted.name,
      'riderId': riderId,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> startRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideStatus.inProgress.name,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeRide(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideStatus.completed.name,
      'completedAt': FieldValue.serverTimestamp(),
    });
  }
}
