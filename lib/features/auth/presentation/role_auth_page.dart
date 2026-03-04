import 'package:flutter/material.dart';

import '../../role/domain/user_role.dart';
import 'widgets/role_sign_in_form.dart';
import 'widgets/role_sign_up_form.dart';

class RoleAuthPage extends StatelessWidget {
  const RoleAuthPage({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text('${role.label} Access'),
            ],
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF1E2235) : const Color(0xFFF0F3FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                padding: const EdgeInsets.all(4),
                indicator: BoxDecoration(
                  color: isDark ? const Color(0xFF2A3050) : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor:
                    isDark ? const Color(0xFF8B93A7) : const Color(0xFF6B7280),
                labelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                tabs: const [Tab(text: 'Sign In'), Tab(text: 'Sign Up')],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [RoleSignInForm(role: role), RoleSignUpForm(role: role)],
        ),
      ),
    );
  }
}
