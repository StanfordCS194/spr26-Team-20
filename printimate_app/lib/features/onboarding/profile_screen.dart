import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '_step_scaffold.dart';
import 'onboarding_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameCtl;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: ref.read(onboardingProvider).name);
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _nameCtl.text.trim();
    if (name.isEmpty) return;
    ref.read(onboardingProvider.notifier).setName(name);
    await ref.read(authControllerProvider).updateDisplayName(name);
    if (mounted) context.go('/onboarding/printer');
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _nameCtl.text.trim().isNotEmpty;
    return OnboardingStepScaffold(
      icon: Icons.person_outline,
      title: 'CREATE PROFILE',
      step: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: IconBox(icon: Icons.person_outline)),
          const SizedBox(height: 24),
          Text('WELCOME TO RECEIPT PRINTER',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            "Send messages that print directly to your\nfriends' receipt printers",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),
          Text('YOUR NAME:', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtl,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => canContinue ? _continue() : null,
            decoration: const InputDecoration(hintText: 'Enter your name...'),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: canContinue ? _continue : null,
            child: const Text('CONTINUE  →'),
          ),
        ],
      ),
    );
  }
}
