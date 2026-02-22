import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../role/domain/user_role.dart';

class AuthRepository {
  AuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  Future<void> signIn({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = credential.user?.uid;
      if (userId == null) {
        throw const AuthFailure('Unable to read account details.');
      }

      final snapshot = await _firestore.collection('users').doc(userId).get();
      final savedRole = UserRoleX.fromString(
        snapshot.data()?['role'] as String?,
      );

      if (savedRole == null) {
        throw const AuthFailure('Account role is missing. Contact support.');
      }

      if (savedRole != role) {
        await _auth.signOut();
        throw AuthFailure(
          'This account is registered as ${savedRole.label}. Use the correct login path.',
        );
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_mapAuthError(error));
    }
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final userId = credential.user?.uid;
      if (userId == null) {
        throw const AuthFailure('Unable to create account. Try again.');
      }

      await _firestore.collection('users').doc(userId).set({
        'fullName': fullName,
        'email': email,
        'role': role.value,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_mapAuthError(error));
    } on FirebaseException catch (_) {
      throw const AuthFailure(
        'Account created, but profile setup failed. Please log in again.',
      );
    }
  }

  Future<void> signOut() {
    return _auth.signOut();
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Use a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}

class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;
}
