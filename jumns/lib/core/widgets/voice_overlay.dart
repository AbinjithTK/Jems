import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/voice_service.dart';
import '../theme/spatial_colors.dart';
import 'agent_sphere.dart';

/// Full-screen voice overlay shown during Gemini Live voice sessions.
///
/// Displays a large pulsing agent sphere with state indicator
/// ("Listening...", "Speaking...") and audio waveform visualization.
class VoiceOverlay extends ConsumerStatefulWidget {
  final String agentColor;
  final VoidCallback onEnd;

  const VoiceOverlay({
    super.key,
    required this.agentColor,
    required this.onEnd,
  });

  @override
  ConsumerState<VoiceOverlay> createState() => _VoiceOverlayState();
}

class _VoiceOverlayState extends ConsumerState<VoiceOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _waveController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final voiceService = ref.watch(voiceServiceProvider);
    final sessionState = voiceService.state;
    final color = SpatialColors.agentColor(widget.agentColor);
    final label = widget.agentColor[0].toUpperCase() + widget.agentColor.substring(1);

    final stateText = switch (sessionState) {
      VoiceSessionState.connecting => 'Connecting...',
      VoiceSessionState.listening => 'Listening...',
      VoiceSessionState.agentSpeaking => 'Speaking...',
      VoiceSessionState.error => 'Connection lost',
      _ => '',
    };

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onTap: () {}, // absorb taps
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: Colors.white.withAlpha(230),
              child: SafeArea(
                child: Column(
                  children: [
                    // Close button
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: GestureDetector(
                          onTap: widget.onEnd,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: SpatialColors.surfaceMuted,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: SpatialColors.textTertiary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Pulsing agent sphere
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withAlpha(60),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: AgentSphere(
                          agentColor: widget.agentColor,
                          size: 160,
                          showFace: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Agent name label
                    Text(
                      label.toUpperCase(),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // State indicator
                    Text(
                      stateText,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: SpatialColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Audio waveform visualization
                    AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, _) {
                        return CustomPaint(
                          size: const Size(200, 40),
                          painter: _WaveformPainter(
                            progress: _waveController.value,
                            color: color,
                            isActive: sessionState == VoiceSessionState.listening ||
                                sessionState == VoiceSessionState.agentSpeaking,
                          ),
                        );
                      },
                    ),
                    const Spacer(),
                    // Release hint
                    Padding(
                      padding: const EdgeInsets.only(bottom: 60),
                      child: Text(
                        'Release to end',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: SpatialColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Simple animated waveform bars.
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isActive;

  _WaveformPainter({
    required this.progress,
    required this.color,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isActive ? color.withAlpha(180) : color.withAlpha(60)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3;

    const barCount = 20;
    final barSpacing = size.width / barCount;

    for (var i = 0; i < barCount; i++) {
      final x = i * barSpacing + barSpacing / 2;
      final phase = (progress * 2 * math.pi) + (i * 0.4);
      final amplitude = isActive ? 0.8 : 0.2;
      final height = (math.sin(phase) * amplitude + 1) * size.height / 3;
      final y1 = size.height / 2 - height;
      final y2 = size.height / 2 + height;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.isActive != isActive;
}
