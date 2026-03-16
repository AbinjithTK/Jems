import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/agent_card.dart';
import '../../../core/theme/jems_colors.dart';
import '../../../core/theme/charcoal_decorations.dart';

class JournalPromptCardWidget extends StatelessWidget {
  final JournalPromptCard card;
  final void Function(String action)? onAction;

  const JournalPromptCardWidget({super.key, required this.card, this.onAction});

  @override
  Widget build(BuildContext context) {
    return CharcoalCard(
      blobColor: JemsColors.lavender,
      rotation: -0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_stories,
                  color: JemsColors.lavender, size: 18),
              const SizedBox(width: 8),
              Text('JOURNAL PROMPT',
                  style: GoogleFonts.architectsDaughter(
                      color: JemsColors.charcoal,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(card.promptText,
              style: GoogleFonts.gloriaHallelujah(
                  color: JemsColors.charcoal,
                  fontSize: 15,
                  fontWeight: FontWeight.w500)),
          if (card.daySummary.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...card.daySummary.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ',
                        style: GoogleFonts.patrickHand(
                            color: JemsColors.ink.withAlpha(130))),
                    Expanded(
                      child: Text(item,
                          style: GoogleFonts.patrickHand(
                              color: JemsColors.ink.withAlpha(150),
                              fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // Mood selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['😢', '😕', '😐', '🙂', '😄'].map((emoji) {
              return GestureDetector(
                onTap: () => onAction?.call('mood:$emoji'),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => onAction?.call('save_journal'),
            child: const Text('Save to Memory'),
          ),
        ],
      ),
    );
  }
}
