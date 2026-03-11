import 'package:flutter/material.dart';

class OnboardingStepHeader extends StatelessWidget {
  const OnboardingStepHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.step,
    required this.totalSteps,
  });

  final String title;
  final String subtitle;
  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = step / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor:
                      theme.brightness == Brightness.dark
                          ? const Color(0xFF252A3A)
                          : const Color(0xFFE5E9F5),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$step/$totalSteps',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
