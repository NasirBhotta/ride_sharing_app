import 'package:flutter/material.dart';

class OnboardingFieldLabel extends StatelessWidget {
  const OnboardingFieldLabel({super.key, required this.label});

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
