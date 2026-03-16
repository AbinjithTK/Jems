import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/jems_colors.dart';

/// Charcoal Sketch header: blob-shaped avatar with lavender arc + handwritten title.
class AgentHeader extends StatelessWidget implements PreferredSizeWidget {
  final String agentName;
  final String status;

  const AgentHeader({
    super.key,
    required this.agentName,
    required this.status,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: JemsColors.ink,
              width: 2,
              style: BorderStyle.solid,
            ),
          ),
        ),
        child: Row(
          children: [
            // Avatar: blob shape with lavender arc decoration
            SizedBox(
              width: 48,
              height: 48,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Lavender arc behind
                  Positioned(
                    left: -6,
                    top: -6,
                    child: CustomPaint(
                      size: const Size(56, 56),
                      painter: _LavenderArcPainter(),
                    ),
                  ),
                  // Blob avatar
                  Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: JemsColors.surface,
                        border: Border.all(color: JemsColors.ink, width: 2),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.elliptical(40, 50),
                          topRight: Radius.elliptical(60, 40),
                          bottomLeft: Radius.elliptical(70, 60),
                          bottomRight: Radius.elliptical(30, 50),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'J',
                          style: GoogleFonts.gloriaHallelujah(
                            color: JemsColors.charcoal,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.rotate(
                    angle: -1 * math.pi / 180,
                    child: Text(
                      agentName,
                      style: GoogleFonts.gloriaHallelujah(
                        color: JemsColors.charcoal,
                        fontWeight: FontWeight.w700,
                        fontSize: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Transform.rotate(
                    angle: 1 * math.pi / 180,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: JemsColors.mint,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: JemsColors.ink,
                              width: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: GoogleFonts.architectsDaughter(
                            color: JemsColors.ink.withAlpha(150),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Overflow menu — blob shape
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(64, 55),
                  topRight: Radius.elliptical(36, 58),
                  bottomLeft: Radius.elliptical(27, 42),
                  bottomRight: Radius.elliptical(73, 45),
                ),
                border: Border.all(color: JemsColors.ink, width: 2),
              ),
              child: const Center(
                child: Icon(
                  Icons.more_horiz_rounded,
                  color: JemsColors.charcoal,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LavenderArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JemsColors.lavender.withAlpha(130)
      ..style = PaintingStyle.fill;

    final strokePaint = Paint()
      ..color = JemsColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Draw a partial arc (lavender fill)
    canvas.drawArc(rect, -math.pi * 0.8, math.pi * 0.9, false, paint);
    canvas.drawArc(rect, -math.pi * 0.8, math.pi * 0.9, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
