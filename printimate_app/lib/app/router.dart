import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/onboarding_state.dart';
import '../features/onboarding/printer_setup_screen.dart';
import '../features/onboarding/profile_screen.dart';
import '../features/pairing/provisioning_screen.dart';
import '../services/app_preferences.dart';
import 'theme.dart';

bool get _canProvision {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  final prefs = ref.watch(appPreferencesProvider);
  final hasPrinter = ref.watch(
    onboardingProvider.select((s) => s.printerId.trim().isNotEmpty),
  );

  return GoRouter(
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Wait for Firebase Auth to hydrate before deciding anything.
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';

      final loggedIn = auth.value != null;
      final seenTour = prefs.hasSeenIntroTour;

      // Legacy redirects.
      const legacy = {'/profile', '/send', '/history'};
      if (legacy.contains(loc)) return loggedIn ? '/home' : '/auth';

      // Splash is only valid while auth is loading.
      if (loc == '/splash') {
        if (!loggedIn) return seenTour ? '/auth' : '/intro';
        if (!hasPrinter && _canProvision) return '/provisioning';
        return '/home';
      }

      // Not logged in: show tour once, then sign-in.
      if (!loggedIn) {
        if (!seenTour && loc != '/intro') return '/intro';
        if (seenTour && loc == '/intro') return '/auth';
        if (loc == '/intro' || loc == '/auth') return null;
        return '/auth';
      }

      // Logged in.
      // Skip the tour and auth pages once signed in.
      if (loc == '/intro' || loc == '/auth') {
        if (hasPrinter) return '/home';
        return _canProvision ? '/provisioning' : '/home';
      }
      // Force first-time pairing only where BLE provisioning is possible.
      if (!hasPrinter &&
          _canProvision &&
          loc != '/provisioning' &&
          !loc.startsWith('/onboarding')) {
        return '/provisioning';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _SplashScreen()),
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/onboarding/profile', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/onboarding/printer', builder: (_, __) => const PrinterSetupScreen()),
      GoRoute(path: '/provisioning', builder: (_, __) => const ProvisioningScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    ],
  );
});

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: PrintimateColors.background,
      body: Center(
        child: CircularProgressIndicator(color: PrintimateColors.text),
      ),
    );
  }
}
