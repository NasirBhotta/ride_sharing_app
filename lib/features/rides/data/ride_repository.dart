import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:typed_data';

import '../domain/ride_message.dart';
import '../domain/ride_request.dart';
import 'encryption_service.dart';
import 'ride_key_manager.dart';

class RideRepository {
  RideRepository({
    FirebaseFirestore? firestore,
    EncryptionService? encryptionService,
    RideKeyManager? keyManager,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptionService = encryptionService ?? EncryptionService(),
        _keyManager = keyManager ?? RideKeyManager();

  final FirebaseFirestore _firestore;
  final EncryptionService _encryptionService;
  final RideKeyManager _keyManager;

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
    required String customerId,
    required Uint8List riderMasterKey,
    required Uint8List customerMasterKey,
    double? riderLat,
    double? riderLng,
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
      final update = <String, dynamic>{
        'status': RideStatus.booked.name,
        'riderId': riderId,
        'bookedAt': FieldValue.serverTimestamp(),
      };
      if (riderLat != null && riderLng != null) {
        update['riderLat'] = riderLat;
        update['riderLng'] = riderLng;
        update['riderLocationUpdatedAt'] = FieldValue.serverTimestamp();
      }
      transaction.update(ref, update);
    });

    // After ride is booked, initialize encryption keys
    await _keyManager.initializeRideEncryption(
      rideId: rideId,
      riderId: riderId,
      customerId: customerId,
      riderMasterKey: riderMasterKey,
      customerMasterKey: customerMasterKey,
    );

    // Subscribe to notification topic for this ride
    await FirebaseMessaging.instance.subscribeToTopic('ride_$rideId');
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
    // Clear key from cache when ride ends
    _keyManager.clearRideKeyFromCache(rideId);
    // Unsubscribe from topic
    await FirebaseMessaging.instance.unsubscribeFromTopic('ride_$rideId');
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
    required Uint8List rideKey,
  }) async {
    // Encrypt the message text
    final encryptedText = _encryptionService.encrypt(text, rideKey);

    await _rides.doc(rideId).collection('messages').add({
      'senderId': senderId,
      'senderRole': senderRole,
      'encryptedText': encryptedText,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
