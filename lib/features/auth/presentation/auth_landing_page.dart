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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Brand mark ──────────────────────────────────────
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withOpacity(0.30),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_car_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // ── Headline ────────────────────────────────────────
                  Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you would like to continue ',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 40),

                  // ── Customer card ───────────────────────────────────
                  _RoleCard(
                    onTap: () => _openRoleAuth(context, UserRole.customer),
                    icon: Icons.person_rounded,
                    title: 'I\'m a Passenger',
                    subtitle: 'Book rides, track drivers, manage trips',
                    isPrimary: true,
                  ),
                  const SizedBox(height: 14),

                  // ── Driver card ─────────────────────────────────────
                  _RoleCard(
                    onTap: () => _openRoleAuth(context, UserRole.rider),
                    icon: Icons.directions_car_rounded,
                    title: 'I\'m a Driver',
                    subtitle: 'Accept requests, navigate routes, earn more',
                    isPrimary: false,
                  ),

                  const SizedBox(height: 40),

                  // ── Footer note ─────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color:
                            isDark
                                ? const Color(0xFF8B93A7)
                                : const Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'End-to-end encrypted & secure',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role selection card ───────────────────────────────────────────────────────

class _RoleCard extends StatefulWidget {
  const _RoleCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isPrimary,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isPrimary;

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    final cardBg =
        widget.isPrimary
            ? primary
            : (isDark ? const Color(0xFF181C26) : Colors.white);

    final cardBorder =
        widget.isPrimary
            ? BorderSide.none
            : BorderSide(
              color: isDark ? const Color(0xFF252A3A) : const Color(0xFFE5E9F5),
              width: 1.5,
            );

    final titleColor =
        widget.isPrimary
            ? Colors.white
            : (isDark ? const Color(0xFFF1F3FA) : const Color(0xFF0D1021));

    final subtitleColor =
        widget.isPrimary
            ? Colors.white.withOpacity(0.72)
            : (isDark ? const Color(0xFF8B93A7) : const Color(0xFF6B7280));

    final iconBg =
        widget.isPrimary
            ? Colors.white.withOpacity(0.18)
            : (isDark ? const Color(0xFF1E2235) : const Color(0xFFEAF0FF));

    final iconColor = widget.isPrimary ? Colors.white : primary;

    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.reverse(),
        onTapUp: (_) {
          _ctrl.forward();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.forward(),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.fromBorderSide(cardBorder),
            boxShadow:
                widget.isPrimary
                    ? [
                      BoxShadow(
                        color: primary.withOpacity(0.28),
                        blurRadius: 28,
                        offset: const Offset(0, 10),
                      ),
                    ]
                    : [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.25 : 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: subtitleColor,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color:
                    widget.isPrimary
                        ? Colors.white.withOpacity(0.7)
                        : subtitleColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
