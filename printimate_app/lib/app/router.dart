import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/auth/user_profile_repository.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/onboarding_state.dart';
import '../features/onboarding/printer_setup_screen.dart';
import '../features/onboarding/profile_screen.dart';
import '../features/pairing/provisioning_screen.dart';
import '../features/send/send_screen.dart';
import '../services/app_preferences.dart';
import '../features/friends/friending_screen.dart';
import '../features/onboarding/add_friends_screen.dart';
import '../features/friends/friend_requests.dart';
import 'theme.dart';

bool get _canProvision {
  if (kIsWeb) return false;
  return Platform.isIOS || Platform.isAndroid;
}

final routerProvider = Provider<GoRouter>((ref) {
  // Only recreate the GoRouter on sign-in/sign-out. Profile-doc and onboarding
  // changes instead bump [refresh], which re-runs redirects on the SAME router
  // instance — recreating the router here would reset navigation and unmount
  // the active screen mid-interaction (e.g. while saving a username).
  final user = ref.watch(authStateProvider).value;

  final refresh = ValueNotifier<int>(0);
  ref.onDispose(refresh.dispose);
  if (user != null) {
    ref.listen(userProfileDocProvider(user.uid), (_, _) => refresh.value++);
  }
  ref.listen(onboardingProvider, (_, _) => refresh.value++);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final loc = state.matchedLocation;

      // Read current state lazily so redirects always see the latest values.
      final auth = ref.read(authStateProvider);
      final prefs = ref.read(appPreferencesProvider);
      final profile = auth.value == null
          ? null
          : ref.read(userProfileDocProvider(auth.value!.uid));
      final hasPrinter =
          ref.read(onboardingProvider).printerId.trim().isNotEmpty;

      // Wait for Firebase Auth to hydrate before deciding anything.
      if (auth.isLoading) return loc == '/splash' ? null : '/splash';

      if (auth.value != null && profile?.isLoading == true) {
        return loc == '/splash' ? null : '/splash';
      }

      final loggedIn = auth.value != null;
      final seenTour = prefs.hasSeenIntroTour;
      final profileData = profile?.value?.data();
      final hasUsername =
          (profileData?['username'] as String?)?.trim().isNotEmpty ?? false;

      // Legacy redirects.
      const legacy = {'/profile', '/history'};
      if (legacy.contains(loc)) return loggedIn ? '/home' : '/auth';

      // Splash is only valid while auth is loading.
      if (loc == '/splash') {
        if (!loggedIn) return seenTour ? '/auth' : '/intro';
        if (!hasUsername) return '/onboarding/profile';
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
        if (!hasUsername) return '/onboarding/profile';
        if (hasPrinter) return '/home';
        return _canProvision ? '/provisioning' : '/home';
      }
      if (!hasUsername && !loc.startsWith('/onboarding')) {
        return '/onboarding/profile';
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
      GoRoute(path: '/onboarding/add_friends_screen', builder: (_, __) => const AddFriendsScreen()),
      GoRoute(path: '/provisioning', builder: (_, __) => const ProvisioningScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
      GoRoute(path: '/friends', builder: (_, __) => const FriendingScreen()),
      GoRoute(path: '/friend_requests', builder: (_, __) => const FriendRequestsScreen()),
      GoRoute(
        path: '/send',
        builder: (_, _) {
          final pid = ref.read(onboardingProvider).printerId.trim();
          return SendScreen(printerName: pid.isEmpty ? 'printer1' : pid);
        },
      ),
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
