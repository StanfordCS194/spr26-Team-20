<<<<<<< Updated upstream
=======
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
>>>>>>> Stashed changes
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/onboarding/intro_screen.dart';
<<<<<<< Updated upstream
import '../features/send/send_screen.dart';
// Onboarding flow temporarily skipped — kept commented for re-enable later.
// import '../features/compose/compose_screen.dart';
// import '../features/history/history_screen.dart';
// import '../features/home/home_screen.dart';
// import '../features/onboarding/add_friends_screen.dart';
// import '../features/onboarding/printer_setup_screen.dart';
// import '../features/onboarding/profile_screen.dart';
// import '../features/pairing/pairing_screen.dart';
// import '../features/settings/settings_screen.dart';
=======
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
>>>>>>> Stashed changes

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
<<<<<<< Updated upstream
      final publicRoute = loc == '/intro' || loc == '/auth';
      if (!loggedIn && !publicRoute) return '/intro';
      if (loggedIn && publicRoute) return '/send';
      return null;
    },
    routes: [
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const SignInScreen()),
      GoRoute(path: '/send', builder: (_, __) => const SendScreen()),
      // Onboarding routes — disabled for now.
      // GoRoute(path: '/onboarding/profile', builder: (_, __) => const ProfileScreen()),
      // GoRoute(path: '/onboarding/printer', builder: (_, __) => const PrinterSetupScreen()),
      // GoRoute(path: '/onboarding/friends', builder: (_, __) => const AddFriendsScreen()),
      // ShellRoute(
      //   builder: (context, state, child) => HomeShell(child: child),
      //   routes: [
      //     GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      //     GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
      //     GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      //   ],
      // ),
      // GoRoute(path: '/compose', builder: (_, __) => const ComposeScreen()),
      // GoRoute(path: '/pair', builder: (_, __) => const PairingScreen()),
=======

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
>>>>>>> Stashed changes
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
