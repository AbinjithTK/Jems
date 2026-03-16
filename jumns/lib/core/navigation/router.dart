import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/hub/hub_screen.dart';
import '../../features/schedule/schedule_screen.dart';
import '../../features/ecosystem/ecosystem_screen.dart';
import '../../features/ecosystem/mcp_connections_page.dart';
import '../../features/ecosystem/social_connections_page.dart';
import '../../features/ecosystem/marketplace_screen.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/lounge/lounge_screen.dart';
import '../../features/voice/voice_mode_screen.dart';
import '../../features/paywall/paywall_screen.dart';
import '../../features/goals/goal_detail_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/onboarding/welcome_screen.dart';
import '../../features/onboarding/personality_setup_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../../shell/spatial_shell.dart';
import '../providers/auth_provider.dart';
import '../services/auth_service.dart';
import '../state/app_state.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authNotifierProvider);
  final isDemoMode = ref.watch(demoModeProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (loc == '/splash') return null;
      if (isDemoMode) return null;
      if (loc == '/welcome' || loc == '/personality-setup') return null;

      final isAuth = authState.status == AuthStatus.authenticated;
      final isLoading = authState.status == AuthStatus.unknown;

      if (isLoading) return null;
      if (!isAuth && loc != '/login') return '/login';

      if (isAuth && loc == '/login') {
        final container = ProviderScope.containerOf(context);
        final appState = container.read(appStateProvider);
        return appState.hasCompletedOnboarding ? '/hub' : '/welcome';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LoginScreen(),
      ),
      // Spatial shell with floating dock
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => SpatialShell(child: child),
        routes: [
          GoRoute(
            path: '/hub',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HubScreen(),
            ),
          ),
          GoRoute(
            path: '/schedule',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ScheduleScreen(),
            ),
          ),
          GoRoute(
            path: '/ecosystem',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: EcosystemScreen(),
            ),
            routes: [
              GoRoute(
                path: 'mcp',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const McpConnectionsPage(),
              ),
              GoRoute(
                path: 'friends',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const SocialConnectionsPage(),
              ),
              GoRoute(
                path: 'marketplace',
                parentNavigatorKey: _rootNavigatorKey,
                builder: (context, state) => const MarketplaceScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/journal',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: JournalScreen(),
            ),
          ),
          GoRoute(
            path: '/lounge',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: LoungeScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: SettingsScreen(),
            ),
          ),
        ],
      ),
      // Full-screen overlays
      GoRoute(
        path: '/voice',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const VoiceModeScreen(),
      ),
      GoRoute(
        path: '/paywall',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PaywallScreen(),
      ),
      GoRoute(
        path: '/goal/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => GoalDetailScreen(goalId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/welcome',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/personality-setup',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const PersonalitySetupScreen(),
      ),
    ],
  );
});
