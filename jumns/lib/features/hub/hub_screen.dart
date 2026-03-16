import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../../core/models/message.dart';
import '../../core/providers/messages_provider.dart';
import '../../core/providers/goals_provider.dart';
import '../../core/providers/tasks_provider.dart';
import '../../core/providers/reminders_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/services/ws_chat_service.dart';
import '../../core/theme/spatial_colors.dart';
import '../../core/widgets/agent_sphere.dart';
import '../../core/models/agent_card.dart';
import '../chat/cards/card_renderer.dart';

class HubScreen extends ConsumerStatefulWidget {
  const HubScreen({super.key});

  @override
  ConsumerState<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends ConsumerState<HubScreen> {
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Connect WebSocket for real-time streaming after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connectWs();
    });
  }

  void _connectWs() {
    final authState = ref.read(authNotifierProvider);
    final isDemoMode = ref.read(demoModeProvider);
    final userId = authState.user?.sub ?? (isDemoMode ? 'demo-user' : null);
    if (userId != null) {
      final ws = ref.read(wsChatServiceProvider);
      if (ws.state == WsChatState.disconnected) {
        ws.connect(userId: userId);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesNotifierProvider);
    final isLoading = ref.watch(isChatLoadingProvider);
    final isStreaming = ref.watch(isStreamingProvider);
    final ws = ref.watch(wsChatServiceProvider);

    return SafeArea(
      child: Column(
        children: [
          // Top bar — profile only, right-aligned
          Padding(
            padding: const EdgeInsets.fromLTRB(23, 19, 16, 0),
            child: Row(
              children: [
                // WS connection indicator
                if (ws.state == WsChatState.connected)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                const Spacer(),
              ],
            ),
          ),
          Expanded(
            child: messagesAsync.when(
              loading: () => _IdleHub(),
              error: (e, _) => _ErrorState(
                onRetry: () => ref.read(messagesNotifierProvider.notifier).load(),
              ),
              data: (messages) => messages.isEmpty
                  ? _IdleHub()
                  : _ConversationView(
                      messages: messages,
                      isThinking: isLoading || isStreaming,
                      streamingText: ws.streamBuffer,
                    ),
            ),
          ),
          // Input field
          _HubInput(
            onSend: _sendMessage,
            isDisabled: isLoading,
          ),
          const SizedBox(height: 80), // tab bar clearance
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final ws = ref.read(wsChatServiceProvider);
    final isWsConnected = ws.state == WsChatState.connected;

    // Only show loading spinner for REST mode (WS shows streaming text instead)
    if (!isWsConnected) {
      ref.read(isChatLoadingProvider.notifier).state = true;
    }

    try {
      await ref.read(messagesNotifierProvider.notifier).sendChat(text);
    } finally {
      if (!_disposed) {
        ref.read(isChatLoadingProvider.notifier).state = false;
        // Refresh data providers after agent may have created tasks/goals
        ref.read(goalsNotifierProvider.notifier).load();
        ref.read(tasksNotifierProvider.notifier).load();
        ref.read(remindersNotifierProvider.notifier).load();
      }
    }
  }
}

/// Idle state — centered green sphere with greeting.
class _IdleHub extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dashed orbit circle
          Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: SpatialColors.surfaceMuted,
                width: 2,
                style: BorderStyle.none,
              ),
            ),
            child: CustomPaint(
              painter: _DashedCirclePainter(),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sub-agent spheres orbiting
                    const SizedBox(height: 16),
                    const AgentSphere(agentColor: 'green', size: 180),
                    const SizedBox(height: 48),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24,
                          letterSpacing: -0.6,
                          color: SpatialColors.textTertiary,
                        ),
                        children: [
                          const TextSpan(text: 'What are we '),
                          TextSpan(
                            text: 'tackling',
                            style: TextStyle(color: SpatialColors.textSecondary),
                          ),
                          const TextSpan(text: '\n'),
                          TextSpan(
                            text: 'today?',
                            style: TextStyle(color: SpatialColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpatialColors.surfaceMuted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    const dashLength = 8.0;
    const gapLength = 6.0;
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final circumference = 2 * 3.14159 * radius;
    final dashCount = (circumference / (dashLength + gapLength)).floor();

    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i * (dashLength + gapLength)) / radius;
      final sweepAngle = dashLength / radius;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Conversation view — multi-agent visual log.
class _ConversationView extends ConsumerWidget {
  final List<Message> messages;
  final bool isThinking;
  final String streamingText;

  const _ConversationView({
    required this.messages,
    required this.isThinking,
    this.streamingText = '',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showStreaming = streamingText.isNotEmpty;
    final extraItems = (isThinking && !showStreaming ? 1 : 0) + (showStreaming ? 1 : 0);

    // Track which agent is currently streaming via the WS service
    final ws = ref.watch(wsChatServiceProvider);
    final streamingAgent = ws.streamingAuthor;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 29, vertical: 8),
      itemCount: messages.length + extraItems,
      itemBuilder: (context, index) {
        // Streaming text bubble (live typing)
        if (showStreaming && index == messages.length) {
          return _AgentMessage(
            agentName: streamingAgent,
            text: streamingText,
            isStreaming: true,
          );
        }

        // Thinking indicator
        if (index >= messages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SpatialColors.agentGradient('noor'),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Thinking...', style: GoogleFonts.inter(
                  color: SpatialColors.textTertiary,
                  fontSize: 13,
                )),
              ],
            ),
          );
        }

        final msg = messages[index];
        final agentName = msg.metadata?['agent'] as String? ?? 'noor';

        if (msg.isUser) {
          return _UserMessage(text: msg.content ?? '');
        }

        // Agent message block
        return _AgentMessage(
          agentName: agentName,
          text: msg.content ?? '',
          cardType: msg.cardType,
          cardData: msg.cardData,
        );
      },
    );
  }
}

class _UserMessage extends StatelessWidget {
  final String text;
  const _UserMessage({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 60),
          Flexible(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              decoration: BoxDecoration(
                color: SpatialColors.userBubble,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                    color: SpatialColors.userBubble.withAlpha(40),
                  ),
                ],
              ),
              child: Text(
                text,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentMessage extends StatelessWidget {
  final String agentName;
  final String text;
  final String? cardType;
  final Map<String, dynamic>? cardData;
  final bool isStreaming;

  const _AgentMessage({
    required this.agentName,
    required this.text,
    this.cardType,
    this.cardData,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = SpatialColors.agentColor(agentName);
    final gradient = SpatialColors.agentGradient(agentName);
    final label = SpatialColors.agentLabel(agentName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Agent label with simple 2D dot
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: gradient,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          // Card or text bubble
          if (cardType != null && cardData != null) ...[
            _buildCard(),
            if (text.isNotEmpty) const SizedBox(height: 8),
          ],
          if (text.isNotEmpty)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                    decoration: BoxDecoration(
                      color: SpatialColors.surfaceSubtle,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(24),
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          offset: Offset(0, 1),
                          blurRadius: 3,
                          color: Color(0x0D000000),
                        ),
                      ],
                    ),
                    child: Text(
                      text,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        height: 1.5,
                        color: SpatialColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 60),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final card = AgentCard.fromJson({
      'type': _mapCardType(cardType!),
      ...cardData!,
    });
    if (card != null) return CardRenderer(card: card);
    return const SizedBox.shrink();
  }

  String _mapCardType(String backendType) => switch (backendType) {
        'briefing' => 'daily_briefing',
        'health' => 'health_snapshot',
        'goal' || 'goal_check_in' => 'goal_check_in',
        'reminder' => 'reminder',
        'journal' || 'journal_prompt' => 'journal_prompt',
        'insight' || 'proactive' => 'insight',
        _ => backendType,
      };
}

/// Neumorphic glass input field.
class _HubInput extends StatefulWidget {
  final ValueChanged<String> onSend;
  final bool isDisabled;

  const _HubInput({required this.onSend, required this.isDisabled});

  @override
  State<_HubInput> createState() => _HubInputState();
}

class _HubInputState extends State<_HubInput> {
  final _controller = TextEditingController();
  final _attachKey = GlobalKey();
  OverlayEntry? _attachOverlay;
  final _picker = ImagePicker();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _removeAttachOverlay();
    _controller.dispose();
    super.dispose();
  }

  void _removeAttachOverlay() {
    _attachOverlay?.remove();
    _attachOverlay = null;
  }

  void _toggleAttachMenu() {
    if (_attachOverlay != null) {
      _removeAttachOverlay();
      return;
    }

    final renderBox =
        _attachKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final pos = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _attachOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeAttachOverlay,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),
          // Popup above the + button
          Positioned(
            left: pos.dx - 8,
            bottom: MediaQuery.of(context).size.height - pos.dy + 8,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(240),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, -4),
                      blurRadius: 24,
                      color: Colors.black.withAlpha(18),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _AttachOption(
                      icon: Icons.image_rounded,
                      label: 'Photo',
                      color: SpatialColors.agentGreen,
                      onTap: () { _removeAttachOverlay(); _pickImage(ImageSource.gallery); },
                    ),
                    const SizedBox(width: 20),
                    _AttachOption(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      color: SpatialColors.userBubble,
                      onTap: () { _removeAttachOverlay(); _pickImage(ImageSource.camera); },
                    ),
                    const SizedBox(width: 20),
                    _AttachOption(
                      icon: Icons.insert_drive_file_rounded,
                      label: 'File',
                      color: SpatialColors.agentViolet,
                      onTap: () { _removeAttachOverlay(); _showComingSoon('File sharing'); },
                    ),
                    const SizedBox(width: 20),
                    _AttachOption(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      color: SpatialColors.agentPink,
                      onTap: () { _removeAttachOverlay(); _showComingSoon('Location sharing'); },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_attachOverlay!);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 80);
      if (file == null) return;
      // Send as a message with the file path — backend can handle image uploads
      widget.onSend('[Image: ${file.name}]');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Image selected: ${file.name}'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: SpatialColors.textPrimary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not access image'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: SpatialColors.textPrimary,
          ),
        );
      }
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature coming soon'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: SpatialColors.textPrimary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleVoiceInput() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
      return;
    }
    final available = await _speech.initialize(
      onError: (_) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          setState(() => _isListening = false);
        }
      },
    );
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Speech recognition not available'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: SpatialColors.textPrimary,
          ),
        );
      }
      return;
    }
    setState(() => _isListening = true);
    await _speech.listen(
      onResult: (result) {
        _controller.text = result.recognizedWords;
        _controller.selection = TextSelection.fromPosition(
          TextPosition(offset: _controller.text.length),
        );
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          widget.onSend(result.recognizedWords);
          _controller.clear();
          setState(() => _isListening = false);
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 29),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: SpatialColors.inputGlassBg,
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  offset: const Offset(12, 12),
                  blurRadius: 24,
                  color: Colors.black.withAlpha(13),
                ),
                const BoxShadow(
                  offset: Offset(-12, -12),
                  blurRadius: 24,
                  color: Colors.white,
                ),
              ],
            ),
            child: Row(
              children: [
                // Add / attach button
                GestureDetector(
                  key: _attachKey,
                  onTap: _toggleAttachMenu,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(left: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: SpatialColors.surfaceMuted,
                    ),
                    child: const Icon(Icons.add_rounded, size: 18, color: SpatialColors.textTertiary),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !widget.isDisabled,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: SpatialColors.textSecondary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Talk to your Jems...',
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      hintStyle: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: SpatialColors.textSecondary.withAlpha(77),
                      ),
                    ),
                    onSubmitted: (text) {
                      widget.onSend(text);
                      _controller.clear();
                    },
                  ),
                ),
                // Mic button — speech-to-text
                GestureDetector(
                  onTap: widget.isDisabled ? null : _toggleVoiceInput,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? SpatialColors.agentGreen.withAlpha(30) : null,
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      size: 18,
                      color: _isListening ? SpatialColors.agentGreen : SpatialColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withAlpha(25),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: SpatialColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: SpatialColors.textTertiary),
          const SizedBox(height: 12),
          Text('Could not connect', style: TextStyle(color: SpatialColors.textTertiary)),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
