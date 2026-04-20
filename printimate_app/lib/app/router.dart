import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/compose/compose_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/pairing/pairing_screen.dart';
import '../features/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/history',
            builder: (context, state) => const HistoryScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/compose',
        builder: (context, state) => const ComposeScreen(),
      ),
      GoRoute(
        path: '/pair',
        builder: (context, state) => const PairingScreen(),
      ),
    ],
  );
});

class HomeShell extends StatelessWidget {
  const HomeShell({required this.child, super.key});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/settings')) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int i) {
    switch (i) {
      case 0:
        context.go('/');
      case 1:
        context.go('/history');
      case 2:
        context.go('/settings');
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indexForLocation(location),
        onDestinationSelected: (i) => _onTap(context, i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}
