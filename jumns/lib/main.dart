import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/navigation/router.dart';
import 'core/providers/auth_provider.dart';
import 'core/services/auth_service.dart';
import 'core/theme/spatial_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase before anything else
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Light status bar and nav bar
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // Initialize services before the app renders
  final authService = AuthService();

  // Try to restore a previous Firebase session (so the user stays logged in)
  final restoredUser = await authService.restoreSession();

  // Check if demo mode was previously enabled
  final prefs = await SharedPreferences.getInstance();
  final wasDemoMode = prefs.getBool('demo_mode') ?? false;

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
      if (wasDemoMode) demoModeProvider.overrideWith((ref) => true),
    ],
    child: const JemsApp(),
  ));
}

class JemsApp extends ConsumerWidget {
  const JemsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Jems',
      debugShowCheckedModeBanner: false,
      theme: spatialTheme(),
      routerConfig: router,
    );
  }
}
