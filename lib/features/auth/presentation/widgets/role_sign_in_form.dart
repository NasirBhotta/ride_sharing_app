import 'package:flutter/material.dart';

import '../../../role/domain/user_role.dart';
import '../../data/auth_repository.dart';

class RoleSignInForm extends StatefulWidget {
  const RoleSignInForm({super.key, required this.role});

  final UserRole role;

  @override
  State<RoleSignInForm> createState() => _RoleSignInFormState();
}

class _RoleSignInFormState extends State<RoleSignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authRepository.signIn(
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
            Text('Sign in', style: theme.textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text(
              'Welcome back, ${widget.role.label}.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),

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
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '••••••••',
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
                if ((value ?? '').isEmpty) return 'Password is required';
                return null;
              },
            ),
            const SizedBox(height: 28),

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
                      : const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

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
