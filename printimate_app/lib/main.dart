import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const ProviderScope(child: PrintimateApp()));
}

class PrintimateApp extends ConsumerWidget {
  const PrintimateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Printimate',
      theme: printimateTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
