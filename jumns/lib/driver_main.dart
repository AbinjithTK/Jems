import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_driver/driver_extension.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/navigation/router.dart';
import 'core/services/auth_service.dart';
import 'core/theme/spatial_theme.dart';

void main() async {
  enableFlutterDriverExtension();
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  final authService = AuthService();
  await authService.restoreSession();

  runApp(ProviderScope(
    overrides: [
      authServiceProvider.overrideWithValue(authService),
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
