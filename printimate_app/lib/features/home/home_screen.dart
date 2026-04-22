import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Printimate')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No printers paired yet.\n\nTap + to pair a new printer,\nor use the compose button to send a test.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'pair',
            onPressed: () => context.push('/pair'),
            icon: const Icon(Icons.add),
            label: const Text('Pair'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'compose',
            onPressed: () => context.push('/compose'),
            icon: const Icon(Icons.edit),
            label: const Text('Compose'),
          ),
        ],
      ),
    );
  }
}
