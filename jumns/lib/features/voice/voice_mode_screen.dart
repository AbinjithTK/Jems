import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/providers/messages_provider.dart';
import '../../core/theme/jems_colors.dart';
import '../../core/theme/charcoal_decorations.dart';

class VoiceModeScreen extends ConsumerStatefulWidget {
  const VoiceModeScreen({super.key});

  @override
  ConsumerState<VoiceModeScreen> createState() => _VoiceModeScreenState();
}

class _VoiceModeScreenState extends ConsumerState<VoiceModeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _orbController;
  late final AnimationController _waveController;
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isAvailable = false;
  bool _isListening = false;
  String _transcription = '';
  String _aiResponse = '';
  double _confidence = 0.0;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) setState(() => _isListening = false);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
        }
      },
    );
    if (mounted) setState(() {});
  }

  void _startListening() {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available')),
      );
      return;
    }
    setState(() {
      _transcription = '';
      _aiResponse = '';
      _isListening = true;
    });
    _speech.listen(
      onResult: (result) {
        if (mounted) {
          setState(() {
            _transcription = result.recognizedWords;
            _confidence = result.confidence;
          });
          // Auto-send when speech is final
          if (result.finalResult && _transcription.isNotEmpty) {
            _sendTranscription();
          }
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
      localeId: 'en_US',
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
    if (_transcription.isNotEmpty) {
      _sendTranscription();
    }
  }

  Future<void> _sendTranscription() async {
    if (_transcription.isEmpty || _isSending) return;
    setState(() => _isSending = true);

    try {
      final result = await ref
          .read(messagesNotifierProvider.notifier)
          .sendChat(_transcription);
      if (mounted) {
        setState(() {
          _aiResponse = result?.content ?? 'Done.';
          _isSending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _aiResponse = 'Could not get a response.';
          _isSending = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _orbController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JemsColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar — charcoal sketch style
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: BlobShape(
                      color: JemsColors.surface,
                      size: 40,
                      child: const Icon(Icons.close_rounded,
                          color: JemsColors.charcoal, size: 20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: _isListening
                          ? JemsColors.mint.withAlpha(60)
                          : JemsColors.lavender.withAlpha(60),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.elliptical(14, 10),
                        topRight: Radius.elliptical(10, 14),
                        bottomLeft: Radius.elliptical(10, 14),
                        bottomRight: Radius.elliptical(14, 10),
                      ),
                      border: Border.all(color: JemsColors.ink, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening
                                ? JemsColors.mint
                                : JemsColors.ink.withAlpha(100),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isListening
                              ? 'LISTENING'
                              : (_isSending ? 'THINKING' : 'READY'),
                          style: GoogleFonts.architectsDaughter(
                            color: JemsColors.charcoal,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),

            // User transcription
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: _transcription.isNotEmpty
                    ? charcoalBorderDecoration(fill: JemsColors.surface)
                    : null,
                child: Text(
                  _transcription.isEmpty
                      ? (_isListening ? 'Listening...' : 'Tap the mic to speak')
                      : '"$_transcription"',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.gloriaHallelujah(
                    color: JemsColors.charcoal,
                    fontSize: _transcription.isEmpty ? 16 : 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Animated orb
            SizedBox(
              width: 160,
              height: 160,
              child: AnimatedBuilder(
                animation: _orbController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _OrbPainter(
                      _orbController.value,
                      isActive: _isListening,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('JEMS',
                style: GoogleFonts.architectsDaughter(
                    color: JemsColors.charcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1)),
            const SizedBox(height: 8),
            // AI response
            if (_aiResponse.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: charcoalBorderDecoration(
                      fill: JemsColors.mint.withAlpha(40)),
                  child: Text(
                    _aiResponse.length > 200
                        ? '${_aiResponse.substring(0, 200)}...'
                        : _aiResponse,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.patrickHand(
                        color: JemsColors.ink, fontSize: 15, height: 1.4),
                  ),
                ),
              ),
            if (_isSending)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: JemsColors.charcoal.withAlpha(150),
                  ),
                ),
              ),
            const Spacer(flex: 2),
            // Waveform
            if (_isListening)
              SizedBox(
                height: 40,
                child: AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size(MediaQuery.of(context).size.width, 40),
                      painter: _WaveformPainter(_waveController.value),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: BlobShape(
                    color: JemsColors.surface,
                    size: 48,
                    variant: 1,
                    child: const Icon(Icons.keyboard_rounded,
                        color: JemsColors.charcoal, size: 24),
                  ),
                ),
                // Main mic button
                GestureDetector(
                  onTap: _isListening ? _stopListening : _startListening,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: _isListening
                          ? JemsColors.coral
                          : JemsColors.mint,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.elliptical(64, 55),
                        topRight: Radius.elliptical(36, 58),
                        bottomLeft: Radius.elliptical(27, 42),
                        bottomRight: Radius.elliptical(73, 45),
                      ),
                      border: Border.all(color: JemsColors.ink, width: 2),
                      boxShadow: const [
                        BoxShadow(
                          color: JemsColors.borderShadow,
                          offset: Offset(2, 3),
                          blurRadius: 0,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: JemsColors.charcoal,
                      size: 32,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _showVoiceOptions(context),
                  child: BlobShape(
                    color: JemsColors.surface,
                    size: 48,
                    variant: 2,
                    child: const Icon(Icons.more_horiz_rounded,
                        color: JemsColors.charcoal, size: 24),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isListening ? 'TAP TO STOP' : 'TAP TO SPEAK',
              style: GoogleFonts.architectsDaughter(
                  color: JemsColors.ink.withAlpha(100),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5),
            ),
            if (!_isAvailable)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Speech recognition unavailable on this device',
                    style: GoogleFonts.architectsDaughter(
                        color: JemsColors.coral,
                        fontSize: 10,
                        fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showVoiceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: JemsColors.paper,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.speed, color: JemsColors.charcoal),
              title: Text('Speech Rate',
                  style: GoogleFonts.architectsDaughter(
                      color: JemsColors.charcoal,
                      fontWeight: FontWeight.w700)),
              subtitle: Text('Normal',
                  style: GoogleFonts.patrickHand(
                      color: JemsColors.ink.withAlpha(130))),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Icon(Icons.record_voice_over,
                  color: JemsColors.charcoal),
              title: Text('Voice Style',
                  style: GoogleFonts.architectsDaughter(
                      color: JemsColors.charcoal,
                      fontWeight: FontWeight.w700)),
              subtitle: Text('Default',
                  style: GoogleFonts.patrickHand(
                      color: JemsColors.ink.withAlpha(130))),
              onTap: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }
}


// ─── Custom painters (charcoal sketch style) ───

class _OrbPainter extends CustomPainter {
  final double progress;
  final bool isActive;
  _OrbPainter(this.progress, {this.isActive = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;

    // Outer glow — mint when active, lavender when idle
    final glowColor =
        isActive ? JemsColors.mint.withAlpha(30) : JemsColors.lavender.withAlpha(20);
    canvas.drawCircle(
      center,
      radius + 15,
      Paint()
        ..color = glowColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    // Charcoal border ring
    canvas.drawCircle(
      center,
      radius + 2,
      Paint()
        ..color = JemsColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Main orb fill
    final orbColor = isActive ? JemsColors.mint : JemsColors.lavender;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [orbColor.withAlpha(200), orbColor.withAlpha(60)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Orbiting dots
    for (var i = 0; i < 3; i++) {
      final angle = progress * 2 * math.pi + (i * 2 * math.pi / 3);
      final dotCenter = Offset(
        center.dx + (radius + 8) * math.cos(angle),
        center.dy + (radius + 8) * math.sin(angle),
      );
      canvas.drawCircle(
        dotCenter,
        4,
        Paint()..color = isActive ? JemsColors.charcoal : JemsColors.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_OrbPainter old) => true;
}

class _WaveformPainter extends CustomPainter {
  final double progress;
  _WaveformPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 40;
    final barWidth = size.width / barCount - 2;
    final rng = math.Random(42);

    for (var i = 0; i < barCount; i++) {
      final baseHeight = rng.nextDouble() * 0.6 + 0.2;
      final wave =
          math.sin((i / barCount + progress) * 2 * math.pi) * 0.3 + 0.7;
      final height = baseHeight * wave * size.height;
      final x = i * (barWidth + 2);
      final y = (size.height - height) / 2;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, barWidth, height),
            const Radius.circular(2)),
        Paint()..color = JemsColors.charcoal.withAlpha((150 * wave).toInt()),
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) => true;
}
