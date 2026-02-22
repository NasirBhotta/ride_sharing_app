import 'package:flutter/material.dart';

import '../../role/domain/user_role.dart';
import 'widgets/role_sign_in_form.dart';
import 'widgets/role_sign_up_form.dart';

class RoleAuthPage extends StatelessWidget {
  const RoleAuthPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${role.label} Access'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Sign in'), Tab(text: 'Sign up')],
          ),
        ),
        body: TabBarView(
          children: [RoleSignInForm(role: role), RoleSignUpForm(role: role)],
        ),
      ),
    );
  }
}
