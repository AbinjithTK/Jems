import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/models/agent_card.dart';
import '../../../core/theme/jems_colors.dart';
import '../../../core/theme/charcoal_decorations.dart';

class HealthSnapshotCardWidget extends StatelessWidget {
  final HealthSnapshotCard card;
  final void Function(String action)? onAction;

  const HealthSnapshotCardWidget({super.key, required this.card, this.onAction});

  @override
  Widget build(BuildContext context) {
    return CharcoalCard(
      blobColor: JemsColors.coral,
      rotation: -0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.favorite, color: JemsColors.coral, size: 18),
              const SizedBox(width: 8),
              Text('HEALTH SNAPSHOT',
                  style: GoogleFonts.architectsDaughter(
                      color: JemsColors.coral,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricTile(
                icon: Icons.directions_walk,
                label: 'Steps',
                value: '${card.steps}',
                trend: card.trends['steps'],
              ),
              const SizedBox(width: 16),
              _MetricTile(
                icon: Icons.bedtime,
                label: 'Sleep',
                value: card.sleep,
                trend: card.trends['sleep'],
              ),
              if (card.heartRate != null) ...[
                const SizedBox(width: 16),
                _MetricTile(
                  icon: Icons.monitor_heart,
                  label: 'Heart',
                  value: '${card.heartRate} bpm',
                  trend: card.trends['heartRate'],
                ),
              ],
            ],
          ),
          if (card.aiNote != null) ...[
            const SizedBox(height: 12),
            Text(card.aiNote!,
                style: GoogleFonts.patrickHand(
                    color: JemsColors.ink.withAlpha(150),
                    fontSize: 14,
                    fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? trend;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: JemsColors.ink.withAlpha(150), size: 20),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.gloriaHallelujah(
                  color: JemsColors.charcoal,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.architectsDaughter(
                        color: JemsColors.ink.withAlpha(130),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
              if (trend != null) ...[
                const SizedBox(width: 2),
                Text(trend!,
                    style: GoogleFonts.architectsDaughter(
                        color: trend == '↑'
                            ? JemsColors.mint
                            : JemsColors.ink.withAlpha(130),
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
