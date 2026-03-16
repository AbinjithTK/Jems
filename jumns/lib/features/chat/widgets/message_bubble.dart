import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/jems_colors.dart';

/// Charcoal Sketch message bubbles with rich inline badges for plan summaries.
///
/// Detects patterns like "2 milestones", "52 tasks", "3 reminders" and renders
/// them as colorful blob-shaped badges inline with the text.
class MessageBubble extends StatelessWidget {
  final String text;
  final bool isUser;
  final String? imageUrl;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isUser,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.82 : 0.88),
        ),
        decoration: BoxDecoration(
          color: isUser
              ? JemsColors.markerBlue.withAlpha(200)
              : JemsColors.surface,
          borderRadius: isUser
              ? const BorderRadius.only(
                  topLeft: Radius.elliptical(48, 10),
                  topRight: Radius.elliptical(10, 42),
                  bottomLeft: Radius.elliptical(10, 48),
                  bottomRight: Radius.elliptical(42, 10),
                )
              : const BorderRadius.only(
                  topLeft: Radius.elliptical(10, 42),
                  topRight: Radius.elliptical(48, 10),
                  bottomLeft: Radius.elliptical(42, 10),
                  bottomRight: Radius.elliptical(10, 48),
                ),
          border: Border.all(color: JemsColors.ink, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(25),
              offset: isUser
                  ? const Offset(4, 4)
                  : const Offset(-2, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (imageUrl != null && imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl!.startsWith('http')
                      ? Image.network(imageUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox())
                      : Image.file(File(imageUrl!),
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
            if (text.isNotEmpty)
              isUser ? _plainText(text) : _richAssistantContent(text),
          ],
        ),
      ),
    );
  }

  Widget _plainText(String t) {
    return Text(
      t,
      style: GoogleFonts.architectsDaughter(
        color: JemsColors.charcoal,
        fontSize: 15,
        height: 1.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  /// Renders assistant text with colorful inline badges for plan items.
  Widget _richAssistantContent(String t) {
    // Check if this looks like a plan summary (has milestone/task/reminder counts)
    final hasPlanItems = _planBadgePattern.hasMatch(t);

    if (!hasPlanItems) return _plainText(t);

    // Split text around badge patterns and build rich inline content
    final spans = <InlineSpan>[];
    var lastEnd = 0;

    for (final match in _planBadgePattern.allMatches(t)) {
      // Add text before this match
      if (match.start > lastEnd) {
        spans.add(InlineSpan.text(t.substring(lastEnd, match.start)));
      }
      final count = match.group(1)!;
      final label = match.group(2)!.toLowerCase();
      spans.add(InlineSpan.badge(count, label));
      lastEnd = match.end;
    }
    // Trailing text
    if (lastEnd < t.length) {
      spans.add(InlineSpan.text(t.substring(lastEnd)));
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 6,
      children: spans.map((s) {
        if (s.isBadge) {
          return _PlanBadge(count: s.count!, label: s.label!);
        }
        return Text(
          s.text!,
          style: GoogleFonts.architectsDaughter(
            color: JemsColors.charcoal,
            fontSize: 15,
            height: 1.5,
            fontWeight: FontWeight.w700,
          ),
        );
      }).toList(),
    );
  }
}

/// Pattern: "2 milestones", "52 tasks", "3 reminders", "1 goal"
final _planBadgePattern = RegExp(
  r'(\d+)\s+(milestones?|tasks?|reminders?|goals?|steps?|habits?)',
  caseSensitive: false,
);

class InlineSpan {
  final String? text;
  final String? count;
  final String? label;
  final bool isBadge;

  InlineSpan.text(this.text) : count = null, label = null, isBadge = false;
  InlineSpan.badge(this.count, this.label) : text = null, isBadge = true;
}

/// Colorful blob-shaped badge for plan item counts.
class _PlanBadge extends StatelessWidget {
  final String count;
  final String label;

  const _PlanBadge({required this.count, required this.label});

  static Color _color(String label) {
    final l = label.toLowerCase();
    if (l.startsWith('milestone')) return JemsColors.amber;
    if (l.startsWith('task') || l.startsWith('step')) return JemsColors.mint;
    if (l.startsWith('reminder')) return JemsColors.lavender;
    if (l.startsWith('goal')) return JemsColors.coral;
    if (l.startsWith('habit')) return JemsColors.markerBlue;
    return JemsColors.markerBlue;
  }

  static IconData _icon(String label) {
    final l = label.toLowerCase();
    if (l.startsWith('milestone')) return Icons.flag_rounded;
    if (l.startsWith('task') || l.startsWith('step')) return Icons.check_circle_outline_rounded;
    if (l.startsWith('reminder')) return Icons.notifications_active_rounded;
    if (l.startsWith('goal')) return Icons.emoji_events_rounded;
    if (l.startsWith('habit')) return Icons.loop_rounded;
    return Icons.star_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(label);
    final icon = _icon(label);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(180),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.elliptical(14, 10),
          topRight: Radius.elliptical(10, 14),
          bottomLeft: Radius.elliptical(10, 14),
          bottomRight: Radius.elliptical(14, 10),
        ),
        border: Border.all(color: JemsColors.ink, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30000000),
            offset: Offset(1, 2),
            blurRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: JemsColors.charcoal),
          const SizedBox(width: 4),
          Text(
            count,
            style: GoogleFonts.gloriaHallelujah(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: JemsColors.charcoal,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.architectsDaughter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: JemsColors.charcoal,
            ),
          ),
        ],
      ),
    );
  }
}
