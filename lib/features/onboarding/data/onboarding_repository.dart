import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class OnboardingRepository {
  OnboardingRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  Future<String> uploadDocument({
    required File file,
    required String folder,
    required String filename,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('User not logged in.');
    }
    final ref = _storage
        .ref()
        .child('onboarding')
        .child(user.uid)
        .child(folder)
        .child(filename);
    final task = await ref.putFile(file);
    return task.ref.getDownloadURL();
  }

  Future<void> saveCustomerProfile(Map<String, dynamic> profile) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not logged in.');
    await _firestore.collection('users').doc(user.uid).set({
      'customerProfile': profile,
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> saveRiderProfile(Map<String, dynamic> profile) async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('User not logged in.');
    await _firestore.collection('users').doc(user.uid).set({
      'riderProfile': profile,
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
