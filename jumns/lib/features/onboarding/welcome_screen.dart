import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/state/app_state.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/utils/url_helper.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      // Agent sphere logo
                      const AgentSphere(agentColor: 'green', size: 120, showFace: true),
                      const SizedBox(height: 24),
                      Text(
                        'Jems',
                        style: GoogleFonts.plusJakartaSans(
                          color: SpatialColors.textPrimary,
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'YOUR AI LIFE ASSISTANT',
                        style: GoogleFonts.inter(
                          color: SpatialColors.textTertiary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                        ),
                      ),
                      const Spacer(),
                      // Feature rows with agent spheres
                      _FeatureRow(
                        agentColor: 'green',
                        title: 'Smart Conversations',
                        description: 'AI assistant that understands your life context',
                      ),
                      const SizedBox(height: 20),
                      _FeatureRow(
                        agentColor: 'yellow',
                        title: 'Goal Tracking',
                        description: 'Set goals, track progress, and build streaks',
                      ),
                      const SizedBox(height: 20),
                      _FeatureRow(
                        agentColor: 'violet',
                        title: 'Infinite Journal',
                        description: 'Capture thoughts, voice memos, and memories',
                      ),
                      const Spacer(),
                      // CTA — green gradient pill button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: SpatialColors.noorGradient,
                            borderRadius: BorderRadius.circular(9999),
                            boxShadow: [
                              BoxShadow(
                                color: SpatialColors.agentGreen.withAlpha(51),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => context.go('/personality-setup'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(9999),
                              ),
                            ),
                            child: Text('Get Started',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: SpatialColors.textPrimary,
                                )),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text('Already have an account? ',
                              style: GoogleFonts.inter(
                                  color: SpatialColors.textTertiary, fontSize: 14)),
                          GestureDetector(
                            onTap: () => context.go('/login'),
                            child: Text('Sign In',
                                style: GoogleFonts.inter(
                                    color: SpatialColors.agentGreen,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('demo_mode', true);
                          ref.read(appStateProvider.notifier).completeOnboarding();
                          ref.read(demoModeProvider.notifier).state = true;
                          if (context.mounted) context.go('/hub');
                        },
                        child: Text('Skip for now',
                            style: GoogleFonts.inter(
                                color: SpatialColors.textMuted,
                                fontSize: 13)),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          TextButton(
                            onPressed: () =>
                                openUrl(context, JemsUrls.privacyPolicy),
                            child: Text('Privacy Policy',
                                style: GoogleFonts.inter(
                                    color: SpatialColors.textMuted, fontSize: 11)),
                          ),
                          Text('·',
                              style: TextStyle(color: SpatialColors.textMuted)),
                          TextButton(
                            onPressed: () =>
                                openUrl(context, JemsUrls.termsOfService),
                            child: Text('Terms of Service',
                                style: GoogleFonts.inter(
                                    color: SpatialColors.textMuted, fontSize: 11)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final String agentColor;
  final String title;
  final String description;

  const _FeatureRow({
    required this.agentColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AgentSphere(agentColor: agentColor, size: 44, showFace: false),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: GoogleFonts.plusJakartaSans(
                      color: SpatialColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: GoogleFonts.inter(
                      color: SpatialColors.textTertiary, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }
}
