import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/ride_message.dart';
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
    await _firestore.runTransaction((transaction) async {
      final ref = _rides.doc(rideId);
      final snap = await transaction.get(ref);
      final data = snap.data();
      if (data == null) {
        throw StateError('Ride not found');
      }
      final status = data['status'] as String?;
      if (status != RideStatus.requested.name) {
        throw StateError('Ride already booked');
      }
      transaction.update(ref, {
        'status': RideStatus.booked.name,
        'riderId': riderId,
        'bookedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markArrived(String rideId) async {
    await _rides.doc(rideId).update({
      'status': RideStatus.arrived.name,
      'arrivedAt': FieldValue.serverTimestamp(),
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

  Future<void> updateCustomerLocation({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    await _rides.doc(rideId).update({
      'customerLat': lat,
      'customerLng': lng,
      'customerLocationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRiderLocation({
    required String rideId,
    required double lat,
    required double lng,
  }) async {
    await _rides.doc(rideId).update({
      'riderLat': lat,
      'riderLng': lng,
      'riderLocationUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> expandSearchRadius({
    required String rideId,
    required double newRadiusKm,
    required double maxRadiusKm,
  }) async {
    await _rides.doc(rideId).update({
      'searchRadiusKm': newRadiusKm,
      'maxRadiusKm': maxRadiusKm,
      'searchUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<RideMessage>> watchMessages(String rideId) {
    return _rides
        .doc(rideId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => RideMessage.fromDoc(doc))
              .toList(growable: false),
        );
  }

  Future<void> sendMessage({
    required String rideId,
    required String senderId,
    required String senderRole,
    required String text,
  }) async {
    await _rides.doc(rideId).collection('messages').add({
      'senderId': senderId,
      'senderRole': senderRole,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
