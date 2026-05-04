import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/intro_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/intro',
    redirect: (context, state) {
      final loggedIn = auth.value != null;
      final loc = state.matchedLocation;
      const legacy = {'/profile', '/send', '/history'};
      if (legacy.contains(loc)) return loggedIn ? '/home' : '/intro';
      final publicRoute = loc == '/intro' || loc == '/auth';
      if (!loggedIn && !publicRoute) return '/intro';
      if (loggedIn && publicRoute) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/intro', builder: (ctx, st) => const IntroScreen()),
      GoRoute(path: '/auth', builder: (ctx, st) => const SignInScreen()),
      GoRoute(path: '/home', builder: (ctx, st) => const HomeShell()),
    ],
  );
});
