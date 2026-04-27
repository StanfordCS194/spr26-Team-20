import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/onboarding/intro_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/intro',
    redirect: (context, state) {
      final loggedIn = auth.value != null;
      final loc = state.matchedLocation;
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
    ],
  );
});
