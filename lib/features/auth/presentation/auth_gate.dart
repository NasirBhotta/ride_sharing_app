import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../shared/presentation/loading_screen.dart';
import '../../role/presentation/role_gate.dart';
import 'auth_landing_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingScreen(message: 'Checking session...');
        }

        if (snapshot.data == null) {
          return const AuthLandingPage();
        }

        return const RoleGate();
      },
    );
  }
}
