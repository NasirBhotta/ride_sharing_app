import 'package:flutter/material.dart';

import '../../../shared/presentation/loading_screen.dart';
import '../../auth/presentation/auth_gate.dart';
import '../data/app_intro_repository.dart';
import 'app_intro_onboarding_page.dart';

class AppLaunchGate extends StatefulWidget {
  const AppLaunchGate({super.key});

  @override
  State<AppLaunchGate> createState() => _AppLaunchGateState();
}

class _AppLaunchGateState extends State<AppLaunchGate> {
  final _repo = AppIntroRepository();
  bool _loading = true;
  bool _showIntro = false;
  bool _justFinishedIntro = false;

  @override
  void initState() {
    super.initState();
    _resolveLaunchRoute();
  }

  Future<void> _resolveLaunchRoute() async {
    final seen = await _repo.hasSeenIntro();
    if (!mounted) return;
    setState(() {
      _showIntro = !seen;
      _loading = false;
    });
  }

  void _onIntroFinished() {
    setState(() {
      _showIntro = false;
      _justFinishedIntro = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingScreen(message: 'Starting app...');
    }

    if (_showIntro) {
      return AppIntroOnboardingPage(onFinished: _onIntroFinished);
    }

    return AuthGate(showGetStartedCopy: _justFinishedIntro);
  }
}
