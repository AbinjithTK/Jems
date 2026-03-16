import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _sphereController;
  late final AnimationController _fadeController;
  late final Animation<double> _sphereScale;
  late final Animation<double> _titleOpacity;
  late final Animation<double> _subtitleOpacity;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _sphereController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _sphereScale = CurvedAnimation(
      parent: _sphereController,
      curve: Curves.elasticOut,
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );
    _subtitleOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );

    // Start animations
    _sphereController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _fadeController.forward();
    });

    _waitAndNavigate();
  }

  Future<void> _waitAndNavigate() async {
    // Ensure minimum splash duration for animations
    await Future.delayed(const Duration(milliseconds: 2400));
    if (!mounted || _navigated) return;

    // Wait for auth to resolve from unknown → authenticated/unauthenticated
    // Poll every 100ms, timeout after 10s to avoid infinite hang
    const maxWait = Duration(seconds: 10);
    const pollInterval = Duration(milliseconds: 100);
    var elapsed = Duration.zero;

    while (mounted && !_navigated && elapsed < maxWait) {
      final authState = ref.read(authNotifierProvider);
      if (authState.status != AuthStatus.unknown) break;
      await Future.delayed(pollInterval);
      elapsed += pollInterval;
    }

    if (!mounted || _navigated) return;
    _navigated = true;

    final authState = ref.read(authNotifierProvider);
    final isDemoMode = ref.read(demoModeProvider);

    if (isDemoMode) {
      context.go('/hub');
    } else if (authState.status == AuthStatus.authenticated) {
      final appState = ref.read(appStateProvider);
      context.go(appState.hasCompletedOnboarding ? '/hub' : '/welcome');
    } else {
      // If still unknown after timeout, treat as unauthenticated
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _sphereController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated agent sphere as logo
            ScaleTransition(
              scale: _sphereScale,
              child: const AgentSphere(agentColor: 'green', size: 120, showFace: true),
            ),
            const SizedBox(height: 28),
            // Title
            FadeTransition(
              opacity: _titleOpacity,
              child: Text(
                'Jems',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: SpatialColors.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            FadeTransition(
              opacity: _subtitleOpacity,
              child: Text(
                'YOUR AI LIFE ASSISTANT',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: SpatialColors.textTertiary,
                  letterSpacing: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
