import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),
              Center(
                child: SvgPicture.asset('assets/logo.svg', width: 220),
              ),
              const SizedBox(height: 40),
              Text(
                'PRINTIMATE',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(letterSpacing: 4),
              ),
              const SizedBox(height: 24),
              Text(
                'Messages that print.\nOn paper. On purpose.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(flex: 3),
              OutlinedButton(
                onPressed: () => context.go('/auth'),
                child: const Text('GET STARTED  →'),
              ),
              const SizedBox(height: 16),
              Text(
                '═══════════════════════',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: PrintimateColors.border),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
