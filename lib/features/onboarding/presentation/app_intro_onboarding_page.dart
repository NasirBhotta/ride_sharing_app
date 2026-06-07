import 'package:flutter/material.dart';

import '../data/app_intro_repository.dart';

class AppIntroOnboardingPage extends StatefulWidget {
  const AppIntroOnboardingPage({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<AppIntroOnboardingPage> createState() => _AppIntroOnboardingPageState();
}

class _AppIntroOnboardingPageState extends State<AppIntroOnboardingPage> {
  final _pageCtrl = PageController();
  final _repo = AppIntroRepository();
  int _page = 0;

  static const _slides = [
    _IntroSlide(
      icon: Icons.local_taxi_rounded,
      title: 'Book a ride in seconds',
      body: 'Set your pickup and dropoff, choose a vehicle, and request a ride nearby.',
    ),
    _IntroSlide(
      icon: Icons.near_me_rounded,
      title: 'Track your driver live',
      body: 'See real-time location updates from request to dropoff.',
    ),
    _IntroSlide(
      icon: Icons.lock_rounded,
      title: 'Chat securely during your trip',
      body: 'Message your driver or passenger with encrypted in-ride chat.',
    ),
    _IntroSlide(
      icon: Icons.rocket_launch_rounded,
      title: 'Get started',
      body: 'Create an account or sign in to book rides or start driving.',
    ),
  ];

  Future<void> _finish() async {
    await _repo.markIntroSeen();
    if (!mounted) return;
    widget.onFinished();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
      return;
    }
    _pageCtrl.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageCtrl,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Icon(
                            slide.icon,
                            size: 44,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          slide.body,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.textTheme.bodyMedium?.color,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(isLast ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroSlide {
  const _IntroSlide({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}
