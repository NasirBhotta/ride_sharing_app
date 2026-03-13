import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ride_sharing_app/features/admin/presentation/admin_login.dart';

import '../../../shared/presentation/loading_screen.dart';
import '../../auth/presentation/auth_landing_page.dart';
import '../../role/domain/user_role.dart';
import 'admin_dashboard_page.dart';

class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(message: 'Checking session...');
        }

        final user = snapshot.data;
        if (user == null) {
          return const AdminLoginPage();
        }

        final docRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: docRef.snapshots(),
          builder: (context, roleSnap) {
            if (roleSnap.connectionState == ConnectionState.waiting) {
              return const LoadingScreen(message: 'Loading admin profile...');
            }

            final data = roleSnap.data?.data();
            final role = UserRoleX.fromString(data?['role'] as String?);

            if (role == UserRole.admin) {
              return const AdminDashboardPage();
            }

            return _AccessDenied(
              onSignOut: () => FirebaseAuth.instance.signOut(),
            );
          },
        );
      },
    );
  }
}

class _AccessDenied extends StatelessWidget {
  final VoidCallback onSignOut;

  const _AccessDenied({required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Access'),
        actions: [
          TextButton(onPressed: onSignOut, child: const Text('Sign out')),
        ],
      ),
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 12),
                Text('Access denied', style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Your account does not have admin privileges.',
                  style: theme.textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
