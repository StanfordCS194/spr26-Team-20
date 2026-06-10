import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';
import '../auth/user_profile_repository.dart';

import '_step_scaffold.dart';
import 'onboarding_state.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _nameCtl;
  late final TextEditingController _usernameCtl;
  String? _usernameError;
  bool _checkingUsername = false;

  @override
  void initState() {
    super.initState();
    _nameCtl = TextEditingController(text: ref.read(onboardingProvider).name);
    _usernameCtl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _usernameCtl.dispose();
    super.dispose();
  }
  static const _minLength = 3;
  static const _maxLength = 20;
  static final _validChars = RegExp(r'^[a-zA-Z0-9_]+$');

  String? _validateUsername(String value) {
    if (value.length < _minLength) return 'At least $_minLength characters.';
    if (value.length > _maxLength) return 'At most $_maxLength characters.';
    if (!_validChars.hasMatch(value)) return 'Letters, numbers, and underscores only.';
    return null;
  }

  Future<void> _continue() async {
    final name = _nameCtl.text.trim();
    final username = _usernameCtl.text.trim();
    if (name.isEmpty) return;

    final validationError = _validateUsername(username);
    if (validationError != null) {
      setState(() => _usernameError = validationError);
      return;
    }
    setState(() { _checkingUsername = true; _usernameError = null; });

    final repo = ref.read(userProfileRepositoryProvider);
    final taken = await repo.isUsernameTaken(username);
    if (taken) {
      setState(() { _usernameError = 'That username is already taken.'; _checkingUsername = false; });
      return;
    }
    
    setState(() => _checkingUsername = false);
    ref.read(onboardingProvider.notifier).setName(name);
    await ref.read(authControllerProvider).updateDisplayName(name);
    await repo.setUsername(ref.read(authControllerProvider).currentUser!.uid, username);
    if (mounted) context.go('/onboarding/printer');
  }

  @override
  Widget build(BuildContext context) {
    final canContinue = _nameCtl.text.trim().isNotEmpty &&
        _usernameCtl.text.trim().length >= _minLength &&
        !_checkingUsername;
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
          const SizedBox(height: 16),
          Text('USERNAME:', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _usernameCtl,
            onChanged: (_) => setState(() => _usernameError = null),
            textInputAction: TextInputAction.done,
            maxLength: _maxLength,
            onSubmitted: (_) => canContinue ? _continue() : null,
            decoration: InputDecoration(
              prefixText: '@',
              hintText: 'yourname',
              errorText: _usernameError,
            ),
          ),
          if (_usernameError != null)
            Text(
              _usernameError!,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(color: Colors.red),
            ),
          const Spacer(),
          OutlinedButton(
            onPressed: canContinue ? _continue : null,
            child: _checkingUsername
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('CONTINUE  →'),
          ),
        ],
      ),
    );
  }
}
