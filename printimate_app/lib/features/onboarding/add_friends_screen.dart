import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '_step_scaffold.dart';
import 'onboarding_state.dart';

class _Suggestion {
  const _Suggestion(this.id, this.name, this.printerId);
  final String id;
  final String name;
  final String printerId;
}

const _suggestions = [
  _Suggestion('1', 'Sarah Chen', 'PRT-98765'),
  _Suggestion('2', 'Mike Thompson', 'PRT-44231'),
  _Suggestion('3', 'Emily Rodriguez', 'PRT-77812'),
];

class AddFriendsScreen extends ConsumerStatefulWidget {
  const AddFriendsScreen({super.key});

  @override
  ConsumerState<AddFriendsScreen> createState() => _AddFriendsScreenState();
}

class _AddFriendsScreenState extends ConsumerState<AddFriendsScreen> {
  final _selected = <String>{};

  void _finish() {
    ref.read(onboardingProvider.notifier).setFriends(_selected.toList());
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingStepScaffold(
      icon: Icons.group_outlined,
      title: 'ADD FRIENDS',
      step: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: IconBox(icon: Icons.person_add_alt_outlined)),
          const SizedBox(height: 24),
          Text('SELECT FRIENDS',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Text(
            'Choose contacts who have receipt printers',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView.separated(
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final s = _suggestions[i];
                final selected = _selected.contains(s.id);
                return InkWell(
                  onTap: () => setState(() {
                    selected ? _selected.remove(s.id) : _selected.add(s.id);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: PrintimateColors.surface,
                      border: Border.all(
                        color: selected ? PrintimateColors.text : PrintimateColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.name, style: Theme.of(context).textTheme.bodyLarge),
                              Text(s.printerId, style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          ),
                        ),
                        Icon(
                          selected ? Icons.check_box_outlined : Icons.check_box_outline_blank,
                          color: PrintimateColors.text,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _selected.isEmpty ? null : _finish,
            child: Text('ADD ${_selected.length} FRIENDS'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _finish,
            child: const Text('SKIP FOR NOW'),
          ),
        ],
      ),
    );
  }
}
