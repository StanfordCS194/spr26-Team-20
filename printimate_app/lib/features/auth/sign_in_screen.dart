import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';

enum _Mode { signIn, signUp }

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  _Mode _mode = _Mode.signUp;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) context.go('/onboarding/profile');
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled') {
        if (mounted) setState(() {});
        return;
      }
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _emailSubmit() {
    final ctl = ref.read(authControllerProvider);
    final email = _emailCtl.text.trim();
    final pw = _passwordCtl.text;
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = 'Email and password required.');
      return;
    }
    _run(() => _mode == _Mode.signUp
        ? ctl.signUpWithEmail(email: email, password: pw, displayName: _nameCtl.text)
            .then((_) {})
        : ctl.signInWithEmail(email: email, password: pw).then((_) {}));
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ref.read(authControllerProvider);
    final showApple = kIsWeb ||
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => context.go('/intro'),
                    icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                  ),
                  const SizedBox(width: 8),
                  Text('SIGN IN', style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: PrintimateColors.border, height: 1),
              const SizedBox(height: 32),
              _ProviderButton(
                icon: Icons.g_mobiledata,
                label: 'CONTINUE WITH GOOGLE',
                onPressed: _busy ? null : () => _run(() => ctl.signInWithGoogle().then((_) {})),
              ),
              const SizedBox(height: 12),
              if (showApple) ...[
                _ProviderButton(
                  icon: Icons.apple,
                  label: 'CONTINUE WITH APPLE',
                  onPressed: _busy ? null : () => _run(() => ctl.signInWithApple().then((_) {})),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 16),
              Row(children: [
                const Expanded(child: Divider(color: PrintimateColors.border)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: Theme.of(context).textTheme.bodyMedium),
                ),
                const Expanded(child: Divider(color: PrintimateColors.border)),
              ]),
              const SizedBox(height: 24),
              if (_mode == _Mode.signUp) ...[
                Text('NAME (OPTIONAL):', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameCtl,
                  decoration: const InputDecoration(hintText: 'Your name'),
                ),
                const SizedBox(height: 16),
              ],
              Text('EMAIL:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
              const SizedBox(height: 16),
              Text('PASSWORD:', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordCtl,
                obscureText: true,
                decoration: const InputDecoration(hintText: '••••••••'),
                onSubmitted: (_) => _emailSubmit(),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent)),
                const SizedBox(height: 12),
              ],
              OutlinedButton(
                onPressed: _busy ? null : _emailSubmit,
                child: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: PrintimateColors.text),
                      )
                    : Text(_mode == _Mode.signUp ? 'CREATE ACCOUNT  →' : 'LOG IN  →'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                          _mode = _mode == _Mode.signUp ? _Mode.signIn : _Mode.signUp;
                          _error = null;
                        }),
                child: Text(
                  _mode == _Mode.signUp
                      ? 'Already have an account? Log in'
                      : "Don't have an account? Sign up",
                  style: const TextStyle(color: PrintimateColors.textDim),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProviderButton extends StatelessWidget {
  const _ProviderButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: PrintimateColors.text),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }
}
