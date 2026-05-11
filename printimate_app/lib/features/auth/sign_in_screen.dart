import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import 'auth_controller.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  bool _busy = false;
  String? _error;
  bool _isNewUser = false;

  bool _isFirstTimeUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('=== _isFirstTimeUser: No user found ===');
      return false;
    }
    final createdAt = user.metadata.creationTime;
    final lastSignInAt = user.metadata.lastSignInTime;
    debugPrint('=== _isFirstTimeUser: createdAt=$createdAt, lastSignInAt=$lastSignInAt ===');
    if (createdAt == null || lastSignInAt == null) {
      debugPrint('=== _isFirstTimeUser: Missing metadata ===');
      return false;
    }
    final diff = createdAt.difference(lastSignInAt).abs().inSeconds;
    debugPrint('=== _isFirstTimeUser: Time diff=$diff seconds ===');
    // If account was created within 2 seconds of last sign-in, it's a new account
    final isNew = diff <= 2;
    debugPrint('=== _isFirstTimeUser: Result=$isNew ===');
    return isNew;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted) {
        _isNewUser = _isFirstTimeUser();
        debugPrint('=== Sign in complete. Is new user: $_isNewUser ===');
        final route = _isNewUser ? '/onboarding/profile' : '/home';
        debugPrint('Navigating to: $route');
        context.go(route);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'cancelled') return;
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openEmailSheet() async {
    final ctl = ref.read(authControllerProvider);
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PrintimateColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (_) => _EmailAuthSheet(controller: ctl),
    );
    if (result == 'ok' && mounted) {
      _isNewUser = _isFirstTimeUser();
      final route = _isNewUser ? '/onboarding/profile' : '/home';
      context.go(route);
    } else if (result != null && result.isNotEmpty && result != 'ok') {
      if (mounted) setState(() => _error = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctl = ref.read(authControllerProvider);
    final showApple = kIsWeb ||
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _busy ? null : () => context.go('/intro'),
                    icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                  ),
                  const SizedBox(width: 8),
                  Text('SIGN IN', style: Theme.of(context).textTheme.headlineMedium),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: PrintimateColors.border, height: 1),
              const Spacer(),
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
              _ProviderButton(
                icon: Icons.alternate_email,
                label: 'CONTINUE WITH EMAIL',
                onPressed: _busy ? null : _openEmailSheet,
              ),
              const SizedBox(height: 20),
              if (_busy)
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PrintimateColors.text,
                    ),
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ),
              const Spacer(),
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

enum _Mode { signIn, signUp }

class _EmailAuthSheet extends StatefulWidget {
  const _EmailAuthSheet({required this.controller});
  final AuthController controller;

  @override
  State<_EmailAuthSheet> createState() => _EmailAuthSheetState();
}

class _EmailAuthSheetState extends State<_EmailAuthSheet> {
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _nameCtl = TextEditingController();
  final _passwordFocus = FocusNode();
  _Mode _mode = _Mode.signUp;
  int _step = 0;
  bool _busy = false;
  String? _error;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _nameCtl.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _continueFromEmail() {
    final email = _emailCtl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    setState(() {
      _step = 1;
      _error = null;
    });
    Future.microtask(() => _passwordFocus.requestFocus());
  }

  Future<void> _submit() async {
    final email = _emailCtl.text.trim();
    final pw = _passwordCtl.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Password required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_mode == _Mode.signUp) {
        await widget.controller.signUpWithEmail(
          email: email,
          password: pw,
          displayName: _nameCtl.text,
        );
      } else {
        await widget.controller.signInWithEmail(email: email, password: pw);
      }
      if (mounted) Navigator.of(context).pop('ok');
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = e.message ?? e.code);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSignUp = _mode == _Mode.signUp;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: PrintimateColors.background,
          border: Border(top: BorderSide(color: PrintimateColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 3,
                color: PrintimateColors.border,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (_step > 0)
                  IconButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _step = 0;
                              _error = null;
                            }),
                    icon: const Icon(Icons.arrow_back, color: PrintimateColors.text),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isSignUp ? 'CREATE ACCOUNT' : 'LOG IN',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_step == 0) ..._emailStep() else ..._passwordStep(isSignUp),
            const SizedBox(height: 16),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : (_step == 0 ? _continueFromEmail : _submit),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: PrintimateColors.text,
                      ),
                    )
                  : Text(_step == 0
                      ? 'CONTINUE  →'
                      : (isSignUp ? 'CREATE ACCOUNT  →' : 'LOG IN  →')),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _mode = isSignUp ? _Mode.signIn : _Mode.signUp;
                        _error = null;
                      }),
              child: Text(
                isSignUp
                    ? 'Already have an account? Log in'
                    : "Don't have an account? Sign up",
                style: const TextStyle(color: PrintimateColors.textDim),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _emailStep() {
    return [
      Text('EMAIL', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      TextField(
        controller: _emailCtl,
        keyboardType: TextInputType.emailAddress,
        autocorrect: false,
        autofocus: true,
        textInputAction: TextInputAction.next,
        decoration: const InputDecoration(hintText: 'you@example.com'),
        onSubmitted: (_) => _continueFromEmail(),
      ),
    ];
  }

  List<Widget> _passwordStep(bool isSignUp) {
    return [
      Text(
        _emailCtl.text.trim(),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      if (isSignUp) ...[
        Text('NAME (OPTIONAL)', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        TextField(
          controller: _nameCtl,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(hintText: 'Your name'),
        ),
        const SizedBox(height: 16),
      ],
      Text('PASSWORD', style: Theme.of(context).textTheme.labelLarge),
      const SizedBox(height: 8),
      TextField(
        controller: _passwordCtl,
        focusNode: _passwordFocus,
        obscureText: _obscure,
        autofocus: !isSignUp,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: '••••••••',
          suffixIcon: IconButton(
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: PrintimateColors.textDim,
            ),
          ),
        ),
        onSubmitted: (_) => _submit(),
      ),
    ];
  }
}
