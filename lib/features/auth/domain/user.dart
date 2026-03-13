import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ride_sharing_app/features/role/domain/user_role.dart';

class AppUser {
  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.onboardingCompleted,
  });

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final bool onboardingCompleted;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('User document ${doc.id} has no data');
    }

    return AppUser(
      id: doc.id,
      fullName: data['fullName'] as String? ?? '',
      email: data['email'] as String? ?? '',
      role: UserRoleX.fromString(data['role'] as String?) ?? UserRole.customer,
      onboardingCompleted: data['onboardingCompleted'] as bool? ?? false,
    );
  }
}
