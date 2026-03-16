import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../providers/auth_provider.dart';
import '../providers/messages_provider.dart';
import '../theme/spatial_colors.dart';
import 'agent_sphere.dart';

/// Quick chat overlay — pops up on agent sphere tap.
///
/// Glass container with agent sphere, name, text input, and recent messages.
class QuickChatOverlay extends ConsumerStatefulWidget {
  final String agentColor;
  final VoidCallback onClose;
  final VoidCallback? onVoiceTap;

  const QuickChatOverlay({
    super.key,
    required this.agentColor,
    required this.onClose,
    this.onVoiceTap,
  });

  @override
  ConsumerState<QuickChatOverlay> createState() => _QuickChatOverlayState();
}

class _QuickChatOverlayState extends ConsumerState<QuickChatOverlay> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await ref.read(messagesNotifierProvider.notifier).sendChat(text);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = SpatialColors.agentColor(widget.agentColor);
    final label = widget.agentColor[0].toUpperCase() + widget.agentColor.substring(1);
    final messagesAsync = ref.watch(messagesNotifierProvider);

    return GestureDetector(
      onTap: widget.onClose,
      child: Material(
        color: Colors.black.withAlpha(30),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {}, // absorb taps on the card itself
            child: Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 110,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 360, maxWidth: 380),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(230),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withAlpha(180)),
                      boxShadow: [
                        BoxShadow(
                          offset: const Offset(0, 10),
                          blurRadius: 40,
                          color: Colors.black.withAlpha(20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header: agent sphere + name
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Row(
                            children: [
                              AgentSphere(agentColor: widget.agentColor, size: 36, showFace: true),
                              const SizedBox(width: 12),
                              Text(
                                label.toUpperCase(),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.1,
                                  color: color,
                                ),
                              ),
                              const Spacer(),
                              // Gemini Live voice button
                              if (widget.onVoiceTap != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: GestureDetector(
                                    onTap: widget.onVoiceTap,
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            color.withAlpha(180),
                                            color,
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: color.withAlpha(60),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.mic_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              GestureDetector(
                                onTap: widget.onClose,
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: SpatialColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Recent messages (last 3)
                        messagesAsync.when(
                          loading: () => const SizedBox(height: 40),
                          error: (_, __) => const SizedBox(height: 40),
                          data: (messages) {
                            final recent = messages.length > 3
                                ? messages.sublist(messages.length - 3)
                                : messages;
                            if (recent.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                                child: Text(
                                  'Say something to $label...',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    color: SpatialColors.textTertiary,
                                  ),
                                ),
                              );
                            }
                            return Flexible(
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                itemCount: recent.length,
                                itemBuilder: (_, i) {
                                  final msg = recent[i];
                                  final isUser = msg.isUser;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Align(
                                      alignment: isUser
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        constraints: const BoxConstraints(maxWidth: 260),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isUser
                                              ? SpatialColors.userBubble.withAlpha(230)
                                              : SpatialColors.surfaceSubtle,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          msg.content ?? '',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: isUser
                                                ? Colors.white
                                                : SpatialColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                        // Input
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: SpatialColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(9999),
                              border: Border.all(color: Colors.white),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controller,
                                    autofocus: true,
                                    enabled: !_sending,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 14,
                                      color: SpatialColors.textSecondary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Message $label...',
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 10,
                                      ),
                                      hintStyle: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        color: SpatialColors.textMuted,
                                      ),
                                    ),
                                    onSubmitted: (_) => _send(),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: _send,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: color,
                                      ),
                                      child: Icon(
                                        _sending
                                            ? Icons.hourglass_top_rounded
                                            : Icons.arrow_upward_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
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
        ),
      ),
    );
  }
}
