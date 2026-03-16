import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/api_client.dart';
import '../../core/services/auth_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';

/// Personality onboarding — 3 steps:
///   1. Name your agent
///   2. Pick a personality
///   3. Confirm & go
class PersonalitySetupScreen extends ConsumerStatefulWidget {
  const PersonalitySetupScreen({super.key});

  @override
  ConsumerState<PersonalitySetupScreen> createState() =>
      _PersonalitySetupScreenState();
}

class _PersonalitySetupScreenState
    extends ConsumerState<PersonalitySetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Step 1: Agent name
  final _nameController = TextEditingController(text: 'Jems');

  // Step 2: Personality
  String _selectedPersonality = 'friendly';

  bool _saving = false;

  static const _personalities = [
    (key: 'friendly', emoji: '😊', label: 'Friendly',
     desc: 'Warm, encouraging, celebrates your wins', color: 'green'),
    (key: 'coach', emoji: '💪', label: 'Coach',
     desc: 'Motivating, pushes you to do better', color: 'pink'),
    (key: 'professional', emoji: '📋', label: 'Professional',
     desc: 'Clear, structured, no fluff', color: 'violet'),
    (key: 'zen', emoji: '🧘', label: 'Zen',
     desc: 'Calm, mindful, reflective', color: 'yellow'),
    (key: 'creative', emoji: '✨', label: 'Creative',
     desc: 'Playful, quirky, makes tasks fun', color: 'green'),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/user-settings', body: {
        'agentName': _nameController.text.trim().isEmpty
            ? 'Jems'
            : _nameController.text.trim(),
        'agentBehavior': _selectedPersonality,
        'onboardingCompleted': true,
      });
    } catch (_) {
      // Local server might not be running — proceed anyway
    }
    if (!mounted) return;
    ref.read(appStateProvider.notifier).completeOnboarding();
    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.authenticated) {
      context.go('/hub');
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final isActive = i == _currentPage;
                  final isDone = i < _currentPage;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isActive ? 28 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isActive
                            ? SpatialColors.agentGreen
                            : isDone
                                ? SpatialColors.agentGreen.withAlpha(100)
                                : SpatialColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  );
                }),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _NamePage(
                    controller: _nameController,
                    onNext: _nextPage,
                  ),
                  _PersonalityPage(
                    selected: _selectedPersonality,
                    personalities: _personalities,
                    onSelect: (key) =>
                        setState(() => _selectedPersonality = key),
                    onNext: _nextPage,
                    onBack: _prevPage,
                  ),
                  _ConfirmPage(
                    name: _nameController.text,
                    personality: _selectedPersonality,
                    personalities: _personalities,
                    saving: _saving,
                    onFinish: _finish,
                    onBack: _prevPage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Step 1: Name your agent ───

class _NamePage extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;

  const _NamePage({required this.controller, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          const AgentSphere(agentColor: 'green', size: 100, showFace: true),
          const SizedBox(height: 24),
          Text(
            'Name your assistant',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: SpatialColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Give it a name that feels right to you',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: SpatialColors.textTertiary,
            ),
          ),
          const SizedBox(height: 32),
          // Glass text field
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: SpatialColors.inputGlassBg,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: SpatialColors.glassBorder),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    color: SpatialColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Jems',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 28,
                      color: SpatialColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Spacer(flex: 3),
          _GreenPillButton(label: 'Next', onPressed: onNext),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ─── Step 2: Pick a personality ───

class _PersonalityPage extends StatelessWidget {
  final String selected;
  final List<
      ({
        String key,
        String emoji,
        String label,
        String desc,
        String color,
      })> personalities;
  final ValueChanged<String> onSelect;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const _PersonalityPage({
    required this.selected,
    required this.personalities,
    required this.onSelect,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Text(
            'Pick a vibe',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: SpatialColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'How should your assistant talk to you?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: SpatialColors.textTertiary,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: personalities.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final p = personalities[i];
                final isSelected = p.key == selected;
                return GestureDetector(
                  onTap: () => onSelect(p.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? SpatialColors.agentColor(p.color).withAlpha(25)
                          : SpatialColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected
                            ? SpatialColors.agentColor(p.color)
                            : SpatialColors.surfaceMuted,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: SpatialColors.agentColor(p.color)
                                  .withAlpha(30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            )]
                          : [const BoxShadow(
                              color: Color(0x0D000000),
                              blurRadius: 2,
                              offset: Offset(0, 1),
                            )],
                    ),
                    child: Row(
                      children: [
                        AgentSphere(
                            agentColor: p.color,
                            size: 48,
                            showFace: false),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(p.emoji,
                                      style: const TextStyle(fontSize: 18)),
                                  const SizedBox(width: 6),
                                  Text(
                                    p.label,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: SpatialColors.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                p.desc,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: SpatialColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check_circle,
                              color: SpatialColors.agentColor(p.color),
                              size: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton(
                onPressed: onBack,
                child: Text('Back',
                    style: GoogleFonts.inter(
                        color: SpatialColors.textTertiary,
                        fontWeight: FontWeight.w500)),
              ),
              const Spacer(),
              SizedBox(
                width: 160,
                child: _GreenPillButton(label: 'Next', onPressed: onNext),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Step 3: Confirm ───

class _ConfirmPage extends StatelessWidget {
  final String name;
  final String personality;
  final List<
      ({
        String key,
        String emoji,
        String label,
        String desc,
        String color,
      })> personalities;
  final bool saving;
  final VoidCallback onFinish;
  final VoidCallback onBack;

  const _ConfirmPage({
    required this.name,
    required this.personality,
    required this.personalities,
    required this.saving,
    required this.onFinish,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final p = personalities.firstWhere((x) => x.key == personality,
        orElse: () => personalities.first);
    final displayName = name.trim().isEmpty ? 'Jems' : name.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          const Spacer(flex: 2),
          AgentSphere(agentColor: p.color, size: 110, showFace: true),
          const SizedBox(height: 20),
          Text(
            'Meet $displayName',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: SpatialColors.textPrimary,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 12),
          // Personality badge pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SpatialColors.agentColor(p.color).withAlpha(25),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(
                  color: SpatialColors.agentColor(p.color).withAlpha(60)),
            ),
            child: Text(
              '${p.emoji} ${p.label}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SpatialColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            p.desc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: SpatialColors.textTertiary,
            ),
          ),
          const SizedBox(height: 24),
          // Glass note
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: SpatialColors.inputGlassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: SpatialColors.glassBorder),
                ),
                child: Text(
                  'You can always change the personality later in Settings.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: SpatialColors.textTertiary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
          const Spacer(flex: 3),
          _GreenPillButton(
            label: "Let's go!",
            loading: saving,
            onPressed: onFinish,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onBack,
            child: Text('Go back',
                style: GoogleFonts.inter(
                    color: SpatialColors.textTertiary,
                    fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Shared green gradient pill button ───

class _GreenPillButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _GreenPillButton({
    required this.label,
    this.loading = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SpatialColors.textPrimary,
                  ),
                )
              : Text(label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: SpatialColors.textPrimary,
                  )),
        ),
      ),
    );
  }
}
