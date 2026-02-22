import 'package:flutter/material.dart';

import '../../role/domain/user_role.dart';
import 'role_auth_page.dart';

class AuthLandingPage extends StatelessWidget {
  const AuthLandingPage({super.key});

  void _openRoleAuth(BuildContext context, UserRole role) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => RoleAuthPage(role: role)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ride Sharing')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose how you want to use the app.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _openRoleAuth(context, UserRole.customer),
                  icon: const Icon(Icons.person),
                  label: const Text('I am a Customer'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openRoleAuth(context, UserRole.rider),
                  icon: const Icon(Icons.directions_car),
                  label: const Text('I am a Rider'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
