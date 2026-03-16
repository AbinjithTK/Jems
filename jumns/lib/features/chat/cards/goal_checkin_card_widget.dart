import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/agent_card.dart';
import '../../../core/theme/jems_colors.dart';
import '../../../core/theme/charcoal_decorations.dart';

class GoalCheckInCardWidget extends StatelessWidget {
  final GoalCheckInCard card;
  final void Function(String action)? onAction;

  const GoalCheckInCardWidget({super.key, required this.card, this.onAction});

  @override
  Widget build(BuildContext context) {
    final progress = card.progressTarget > 0
        ? (card.progressCurrent / card.progressTarget).clamp(0.0, 1.0)
        : 0.0;
    final color = JemsColors.categoryColor(card.goalTitle);

    return CharcoalCard(
      blobColor: color,
      rotation: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BlobShape(
                color: color.withAlpha(130),
                size: 36,
                variant: 1,
                child: Text(card.categoryIcon,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(card.goalTitle,
                    style: GoogleFonts.gloriaHallelujah(
                        color: JemsColors.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
              ),
              if (card.streakDays > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: JemsColors.charcoal,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${card.streakDays}-DAY STREAK',
                      style: GoogleFonts.architectsDaughter(
                          color: JemsColors.paper,
                          fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          CharcoalProgressBar(
            progress: progress,
            fillColor: color,
          ),
          const SizedBox(height: 8),
          Text(
            '${card.progressCurrent.toInt()}/${card.progressTarget.toInt()} ${card.progressUnit}',
            style: GoogleFonts.architectsDaughter(
                color: JemsColors.ink.withAlpha(150),
                fontSize: 12,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Row(
            children: card.actions.map((action) {
              final isPrimary = action == card.actions.first;
              return Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: isPrimary
                      ? ElevatedButton(
                          onPressed: () => onAction?.call(action),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(action,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                        ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
