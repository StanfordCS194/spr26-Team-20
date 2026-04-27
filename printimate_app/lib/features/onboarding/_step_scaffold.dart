import 'package:flutter/material.dart';

import '../../app/theme.dart';

class OnboardingStepScaffold extends StatelessWidget {
  const OnboardingStepScaffold({
    required this.icon,
    required this.title,
    required this.step,
    required this.child,
    super.key,
  });

  final IconData icon;
  final String title;
  final int step;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                children: [
                  Icon(icon, color: PrintimateColors.text, size: 22),
                  const SizedBox(width: 12),
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text('Step $step of 3', style: Theme.of(context).textTheme.bodyMedium),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: PrintimateColors.border),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IconBox extends StatelessWidget {
  const IconBox({required this.icon, super.key});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140, height: 140,
      decoration: BoxDecoration(
        color: PrintimateColors.surface,
        border: Border.all(color: PrintimateColors.border, width: 2),
      ),
      child: Icon(icon, size: 64, color: PrintimateColors.text),
    );
  }
}
