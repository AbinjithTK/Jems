import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/jems_colors.dart';

/// Pure function: format a date label.
String formatDateLabel(DateTime date, DateTime today) {
  final d = DateTime(date.year, date.month, date.day);
  final t = DateTime(today.year, today.month, today.day);
  final diff = t.difference(d).inDays;

  if (diff == 0) {
    return 'Today, ${DateFormat('MMM d').format(date)}';
  } else if (diff == 1) {
    return 'Yesterday';
  } else {
    return DateFormat('MMM d').format(date);
  }
}

/// Charcoal Sketch date separator: dashed lines + lavender blob badge.
class DateSeparator extends StatelessWidget {
  final String label;
  const DateSeparator({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1.5,
              color: JemsColors.ink.withAlpha(120),
              transform: Matrix4.rotationZ(2 * math.pi / 180),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Transform.rotate(
              angle: -2 * math.pi / 180,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: JemsColors.lavender.withAlpha(80),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.elliptical(64, 55),
                    topRight: Radius.elliptical(36, 58),
                    bottomLeft: Radius.elliptical(27, 42),
                    bottomRight: Radius.elliptical(73, 45),
                  ),
                ),
                child: Text(
                  label,
                  style: GoogleFonts.architectsDaughter(
                    color: JemsColors.charcoal.withAlpha(180),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1.5,
              color: JemsColors.ink.withAlpha(120),
              transform: Matrix4.rotationZ(-1 * math.pi / 180),
            ),
          ),
        ],
      ),
    );
  }
}
