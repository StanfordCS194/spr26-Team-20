import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '_step_scaffold.dart';
import 'onboarding_state.dart';

class PrinterSetupScreen extends ConsumerStatefulWidget {
  const PrinterSetupScreen({super.key});

  @override
  ConsumerState<PrinterSetupScreen> createState() => _PrinterSetupScreenState();
}

class _PrinterSetupScreenState extends ConsumerState<PrinterSetupScreen> {
  late final TextEditingController _idCtl;

  @override
  void initState() {
    super.initState();
    _idCtl = TextEditingController(text: ref.read(onboardingProvider).printerId);
  }

  @override
  void dispose() {
    _idCtl.dispose();
    super.dispose();
  }

  void _connect() {
    final id = _idCtl.text.trim();
    if (id.isEmpty) return;
    ref.read(onboardingProvider.notifier).setPrinterId(id);
    // TODO: actually attempt printer pairing/MQTT registration here.
    context.go('/onboarding/friends');
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _idCtl.text.trim().isNotEmpty;
    return OnboardingStepScaffold(
      icon: Icons.print_outlined,
      title: 'PRINTER SETUP',
      step: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: IconBox(icon: Icons.print_outlined)),
          const SizedBox(height: 24),
          Text('CONNECT YOUR PRINTER',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Enter your receipt printer ID to receive\nmessages',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 36),
          Text('PRINTER ID:', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _idCtl,
            onChanged: (_) => setState(() {}),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'e.g., PRT-12345-ABCD'),
          ),
          const SizedBox(height: 8),
          Text("Find this on your printer's setup screen",
              style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          OutlinedButton(
            onPressed: canContinue ? _connect : null,
            child: const Text('📡  CONNECT PRINTER'),
          ),
        ],
      ),
    );
  }
}
