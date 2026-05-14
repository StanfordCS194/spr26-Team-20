import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router.dart';
import 'app/theme.dart';
import 'firebase_options.dart';
import 'services/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();

  runApp(ProviderScope(
    overrides: [
      appPreferencesProvider.overrideWithValue(AppPreferences(prefs)),
    ],
    child: const PrintimateApp(),
  ));
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
