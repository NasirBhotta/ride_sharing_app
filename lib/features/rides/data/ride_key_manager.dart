import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'encryption_service.dart';

class RideKeyManager {
  final FirebaseFirestore _firestore;
  final EncryptionService _encryptionService;

  // Cache for decrypted keys: userId -> masterKey
  static final Map<String, Uint8List> _masterKeyCache = {};

  // Cache for ride message keys: rideId -> decrypted key
  static final Map<String, Uint8List> _rideKeyCache = {};

  RideKeyManager({
    FirebaseFirestore? firestore,
    EncryptionService? encryptionService,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _encryptionService = encryptionService ?? EncryptionService();

  /// Get the ride's message key by decrypting it with user's master key
  /// This is called when displaying/sending messages
  Future<Uint8List> getRideMessageKey({
    required String rideId,
    required String userId,
    required String userRole,
    required Uint8List masterKey,
  }) async {
    // Check cache first
    if (_rideKeyCache.containsKey(rideId)) {
      return _rideKeyCache[rideId]!;
    }

    try {
      final rideDoc = await _firestore.collection('rides').doc(rideId).get();
      final data = rideDoc.data();

      if (data == null) {
        throw StateError('Ride $rideId not found');
      }

      // Get the appropriate encrypted key based on user role
      final encryptedKeyField = userRole == 'rider' ? 'riderEncryptedRideKey' : 'customerEncryptedRideKey';
      final encryptedKeyBase64 = data[encryptedKeyField] as String?;

      if (encryptedKeyBase64 == null) {
        throw StateError('No encryption key for this ride. Ride may not have started.');
      }

      // Decrypt the key using master key
      final rideKey = _encryptionService.decryptKey(encryptedKeyBase64, masterKey);

      // Cache it
      _rideKeyCache[rideId] = rideKey;

      return rideKey;
    } catch (e) {
      throw Exception('Failed to get ride message key: $e');
    }
  }

  /// Initialize encryption for a new ride (called when ride is accepted)
  /// Generates a random key and encrypts it for both rider and customer
  Future<void> initializeRideEncryption({
    required String rideId,
    required String riderId,
    required String customerId,
    required Uint8List riderMasterKey,
    required Uint8List customerMasterKey,
  }) async {
    try {
      // Generate a random symmetric key for this ride's messages
      final messageKey = _encryptionService.generateRandomKey();

      // Encrypt the message key with each user's master key
      final riderEncryptedKey = _encryptionService.encryptKey(messageKey, riderMasterKey);
      final customerEncryptedKey = _encryptionService.encryptKey(messageKey, customerMasterKey);

      // Update the ride document with encrypted keys
      await _firestore.collection('rides').doc(rideId).update({
        'riderEncryptedRideKey': riderEncryptedKey,
        'customerEncryptedRideKey': customerEncryptedKey,
        'messageEncryptionKeyId': '1', // Version for future key rotation
        'encryptionInitializedAt': FieldValue.serverTimestamp(),
      });

      // Cache the key
      _rideKeyCache[rideId] = messageKey;
    } catch (e) {
      throw Exception('Failed to initialize ride encryption: $e');
    }
  }

  /// Clear cached keys (call this on logout)
  void clearCache() {
    _masterKeyCache.clear();
    _rideKeyCache.clear();
  }

  /// Clear specific ride key from cache (call when ride completes)
  void clearRideKeyFromCache(String rideId) {
    _rideKeyCache.remove(rideId);
  }

  /// Store user's master key in cache (after derivation/login)
  void cacheMasterKey(String userId, Uint8List masterKey) {
    _masterKeyCache[userId] = masterKey;
  }

  /// Get cached master key (if available)
  Uint8List? getCachedMasterKey(String userId) {
    return _masterKeyCache[userId];
  }
}
