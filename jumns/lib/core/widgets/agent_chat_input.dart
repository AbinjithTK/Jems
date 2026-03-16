import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/spatial_colors.dart';
import '../providers/agent_chat_provider.dart';
import 'agent_sphere.dart';

/// Reusable glassmorphism inline chat input for per-screen agents.
/// Sits at the bottom of schedule/journal/lounge screens.
class AgentChatInput extends ConsumerStatefulWidget {
  final String agentName;
  final String agentColor;
  final String hintText;

  const AgentChatInput({
    super.key,
    required this.agentName,
    required this.agentColor,
    this.hintText = 'Ask your agent...',
  });

  @override
  ConsumerState<AgentChatInput> createState() => _AgentChatInputState();
}

class _AgentChatInputState extends ConsumerState<AgentChatInput>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _expanded = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _animCtrl.forward() : _animCtrl.reverse();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    ref.read(agentChatProvider(widget.agentName).notifier).send(text);
    // Auto-expand to show response
    if (!_expanded) _toggle();
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(agentChatProvider(widget.agentName));
    final agentLabelColor = SpatialColors.agentColor(widget.agentColor);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Expandable chat history
        SizeTransition(
          sizeFactor: _expandAnim,
          axisAlignment: -1,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 240),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(230),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: SpatialColors.surfaceSubtle),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: chatState.messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Ask ${widget.agentName.substring(0, 1).toUpperCase()}${widget.agentName.substring(1)} anything',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            color: SpatialColors.textTertiary,
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: chatState.messages.length +
                          (chatState.isLoading ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == chatState.messages.length) {
                          return _TypingIndicator(color: agentLabelColor);
                        }
                        final msg = chatState.messages[i];
                        return _ChatBubble(
                          msg: msg,
                          agentColor: widget.agentColor,
                          agentName: widget.agentName,
                        );
                      },
                    ),
            ),
          ),
        ),
        // Glass input bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(6),
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
                    // Toggle chat history
                    GestureDetector(
                      onTap: _toggle,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: AgentDot(
                          agentColor: widget.agentColor,
                          size: 28,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        enabled: !chatState.isLoading,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: SpatialColors.textSecondary,
                        ),
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                          hintStyle: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: SpatialColors.textTertiary.withAlpha(128),
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    // Send button
                    GestureDetector(
                      onTap: chatState.isLoading ? null : _send,
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: agentLabelColor.withAlpha(chatState.isLoading ? 60 : 200),
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Single chat bubble in the agent mini-chat.
class _ChatBubble extends StatelessWidget {
  final AgentChatMessage msg;
  final String agentColor;
  final String agentName;

  const _ChatBubble({
    required this.msg,
    required this.agentColor,
    required this.agentName,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser)
            Padding(
              padding: const EdgeInsets.only(right: 6, top: 2),
              child: AgentDot(agentColor: agentColor, size: 18),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? SpatialColors.userBubble
                    : SpatialColors.surfaceSubtle.withAlpha(200),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isUser ? 20 : 4),
                  topRight: Radius.circular(isUser ? 4 : 20),
                  bottomLeft: const Radius.circular(20),
                  bottomRight: const Radius.circular(20),
                ),
              ),
              child: Text(
                msg.content,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isUser ? Colors.white : SpatialColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated typing dots.
class _TypingIndicator extends StatefulWidget {
  final Color color;
  const _TypingIndicator({required this.color});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final t = (_ctrl.value * 3 - i).clamp(0.0, 1.0);
              final y = -4 * (1 - (2 * t - 1) * (2 * t - 1));
              return Transform.translate(
                offset: Offset(0, y),
                child: Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: widget.color.withAlpha(180),
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
