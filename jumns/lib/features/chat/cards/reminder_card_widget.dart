import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/agent_card.dart';
import '../../../core/theme/jems_colors.dart';
import '../../../core/theme/charcoal_decorations.dart';

class ReminderCardWidget extends StatelessWidget {
  final ReminderCard card;
  final void Function(String action)? onAction;

  const ReminderCardWidget({
    super.key,
    required this.card,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 1 * math.pi / 180,
      child: CharcoalCard(
        blobColor: JemsColors.amber,
        rotation: 0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: JemsColors.amber, size: 18),
                const SizedBox(width: 8),
                Text('UPCOMING REMINDER',
                    style: GoogleFonts.architectsDaughter(
                        color: JemsColors.charcoal,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 12),
            Text(card.title,
                style: GoogleFonts.gloriaHallelujah(
                    color: JemsColors.charcoal,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time,
                    color: JemsColors.ink.withAlpha(130), size: 14),
                const SizedBox(width: 4),
                Text(card.time,
                    style: GoogleFonts.architectsDaughter(
                        color: JemsColors.ink.withAlpha(150),
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                if (card.linkedGoal != null) ...[
                  const SizedBox(width: 12),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: JemsColors.charcoal,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(card.linkedGoal!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.architectsDaughter(
                              color: JemsColors.paper,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: card.actions.map((action) {
                final isPrimary = action == 'Done';
                return isPrimary
                    ? ElevatedButton(
                        onPressed: () => onAction?.call(action),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(action,
                            style: const TextStyle(fontSize: 13)),
                      )
                    : OutlinedButton(
                        onPressed: () => onAction?.call(action),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(action,
                            style: const TextStyle(fontSize: 13)),
                      );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
