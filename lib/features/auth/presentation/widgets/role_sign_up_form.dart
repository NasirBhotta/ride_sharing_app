import 'package:flutter/material.dart';

import '../../../role/domain/user_role.dart';
import '../../data/auth_repository.dart';

class RoleSignUpForm extends StatefulWidget {
  const RoleSignUpForm({super.key, required this.role});

  final UserRole role;

  @override
  State<RoleSignUpForm> createState() => _RoleSignUpFormState();
}

class _RoleSignUpFormState extends State<RoleSignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authRepository.signUp(
        fullName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: widget.role,
      );
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthFailure catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ─────────────────────────────────────────────
            Text('Create account', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Join as a ${widget.role.label} today.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

            // ── Full name ───────────────────────────────────────────
            _FieldLabel(label: 'Full name'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'John Doe',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.badge_outlined, size: 20),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
              validator: (value) {
                if ((value ?? '').trim().isEmpty) return 'Name is required';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ── Email ───────────────────────────────────────────────
            _FieldLabel(label: 'Email address'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                hintText: 'you@example.com',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.mail_outline_rounded, size: 20),
                ),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
              ),
              validator: (value) {
                final input = (value ?? '').trim();
                if (input.isEmpty) return 'Email is required';
                if (!input.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ── Password ────────────────────────────────────────────
            _FieldLabel(label: 'Password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Min. 6 characters',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline_rounded, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed:
                      () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (value) {
                if ((value ?? '').length < 6) {
                  return 'Use at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 18),

            // ── Confirm password ────────────────────────────────────
            _FieldLabel(label: 'Confirm password'),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Re-enter password',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(left: 14, right: 10),
                  child: Icon(Icons.lock_outline_rounded, size: 20),
                ),
                prefixIconConstraints: const BoxConstraints(
                  minWidth: 0,
                  minHeight: 0,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed:
                      () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            // ── Password strength hint ──────────────────────────────
            _PasswordStrengthIndicator(password: _passwordController.text),
            const SizedBox(height: 20),

            // ── Submit ──────────────────────────────────────────────
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                      : const Text('Create account'),
            ),

            const SizedBox(height: 16),

            // ── Terms note ──────────────────────────────────────────
            Text(
              'By creating an account you agree to our Terms of Service and Privacy Policy.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }
}

// ── Password strength bar ─────────────────────────────────────────────────────

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});
  final String password;

  int get _strength {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[^A-Za-z0-9]'))) score++;
    return score;
  }

  Color _color(int strength) {
    switch (strength) {
      case 1:
        return const Color(0xFFE8344A);
      case 2:
        return const Color(0xFFFF8C00);
      case 3:
        return const Color(0xFF1A6BFF);
      case 4:
        return const Color(0xFF15BA78);
      default:
        return Colors.transparent;
    }
  }

  String _label(int strength) {
    switch (strength) {
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final strength = _strength;
    if (password.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (i) {
            final active = i < strength;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 3,
                decoration: BoxDecoration(
                  color:
                      active
                          ? _color(strength)
                          : (isDark
                              ? const Color(0xFF252A3A)
                              : const Color(0xFFE5E9F5)),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Text(
          'Password strength: ${_label(strength)}',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w500,
            color: _color(strength),
          ),
        ),
      ],
    );
  }
}
