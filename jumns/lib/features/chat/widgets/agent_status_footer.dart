import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/chat_message.dart';
import '../../../core/theme/jems_colors.dart';

class AgentStatusFooter extends StatelessWidget {
  final AgentReadyState state;
  const AgentStatusFooter({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final (label, animate) = switch (state) {
      AgentReadyState.ready => ('AGENT IS READY', false),
      AgentReadyState.thinking => ('THINKING...', true),
      AgentReadyState.working => ('WORKING...', true),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingDot(animate: animate),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.architectsDaughter(
              color: JemsColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final bool animate;
  const _PulsingDot({required this.animate});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    if (widget.animate) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(_PulsingDot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: JemsColors.mint.withAlpha(
              widget.animate ? (100 + (_controller.value * 155)).toInt() : 255,
            ),
          ),
        );
      },
    );
  }
}
