import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/loading_screen.dart';
import '../../auth/presentation/auth_landing_page.dart';
import '../../rides/presentation/customer_home_page.dart';
import '../../rides/presentation/rider_home_page.dart';
import '../domain/user_role.dart';
import 'role_selection_page.dart';

class RoleGate extends StatelessWidget {
  const RoleGate({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const AuthLandingPage();
    }

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(message: 'Loading profile...');
        }

        final data = snapshot.data?.data();
        final role = UserRoleX.fromString(data?['role'] as String?);

        if (role == null) {
          return const RoleSelectionPage();
        }

        return role == UserRole.customer
            ? const CustomerHomePage()
            : const RiderHomePage();
      },
    );
  }
}
