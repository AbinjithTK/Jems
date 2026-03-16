import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'jems_colors.dart';

// ─── Wobbly border radii (mimics hand-drawn CSS border-radius) ───

/// Primary wobbly: `255px 15px 225px 15px / 15px 225px 15px 255px`
const kCharcoalRadius = BorderRadius.only(
  topLeft: Radius.elliptical(48, 6),
  topRight: Radius.elliptical(6, 42),
  bottomLeft: Radius.elliptical(6, 48),
  bottomRight: Radius.elliptical(42, 6),
);

/// Alternate wobbly for variety
const kCharcoalRadiusAlt = BorderRadius.only(
  topLeft: Radius.elliptical(6, 42),
  topRight: Radius.elliptical(48, 6),
  bottomLeft: Radius.elliptical(42, 6),
  bottomRight: Radius.elliptical(6, 48),
);

/// Charcoal border + offset shadow decoration
BoxDecoration charcoalBorderDecoration({
  Color fill = Colors.white,
  double borderWidth = 2,
}) {
  return BoxDecoration(
    color: fill,
    borderRadius: kCharcoalRadius,
    border: Border.all(color: JemsColors.ink, width: borderWidth),
    boxShadow: const [
      BoxShadow(
        color: JemsColors.borderShadow,
        offset: Offset(2, 3),
        blurRadius: 0,
      ),
    ],
  );
}

// ─── CharcoalCard: card with wobbly border + optional blob behind ───

class CharcoalCard extends StatelessWidget {
  final Widget child;
  final Color? blobColor;
  final double rotation; // degrees
  final EdgeInsets padding;
  final EdgeInsets margin;

  const CharcoalCard({
    super.key,
    required this.child,
    this.blobColor,
    this.rotation = 0,
    this.padding = const EdgeInsets.all(20),
    this.margin = const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pastel blob behind card
          if (blobColor != null)
            Positioned.fill(
              child: Transform.rotate(
                angle: (rotation + 2) * math.pi / 180,
                child: Transform.scale(
                  scale: 1.05,
                  child: Container(
                    decoration: BoxDecoration(
                      color: blobColor!.withAlpha(60),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.elliptical(64, 55),
                        topRight: Radius.elliptical(36, 58),
                        bottomLeft: Radius.elliptical(27, 42),
                        bottomRight: Radius.elliptical(73, 45),
                      ),
                      border: Border.all(
                        color: JemsColors.ink,
                        width: 2,
                        style: BorderStyle.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          // Main card
          Transform.rotate(
            angle: rotation * math.pi / 180,
            child: Container(
              padding: padding,
              decoration: charcoalBorderDecoration(),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── BlobShape: organic blob container ───

class BlobShape extends StatelessWidget {
  final Widget child;
  final Color color;
  final double size;
  final int variant; // 0-3 for different blob shapes

  const BlobShape({
    super.key,
    required this.child,
    required this.color,
    this.size = 48,
    this.variant = 0,
  });

  BorderRadius get _radius => switch (variant) {
        1 => const BorderRadius.only(
            topLeft: Radius.elliptical(34, 49),
            topRight: Radius.elliptical(66, 62),
            bottomLeft: Radius.elliptical(70, 38),
            bottomRight: Radius.elliptical(30, 51),
          ),
        2 => const BorderRadius.only(
            topLeft: Radius.elliptical(42, 45),
            topRight: Radius.elliptical(58, 45),
            bottomLeft: Radius.elliptical(70, 55),
            bottomRight: Radius.elliptical(30, 55),
          ),
        3 => const BorderRadius.only(
            topLeft: Radius.elliptical(73, 57),
            topRight: Radius.elliptical(27, 59),
            bottomLeft: Radius.elliptical(59, 41),
            bottomRight: Radius.elliptical(41, 43),
          ),
        _ => const BorderRadius.only(
            topLeft: Radius.elliptical(64, 55),
            topRight: Radius.elliptical(36, 58),
            bottomLeft: Radius.elliptical(27, 42),
            bottomRight: Radius.elliptical(73, 45),
          ),
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: _radius,
        border: Border.all(color: JemsColors.ink, width: 2),
      ),
      child: Center(child: child),
    );
  }
}

// ─── HandDrawnCheckbox ───

class HandDrawnCheckbox extends StatelessWidget {
  final bool checked;
  final ValueChanged<bool>? onChanged;

  const HandDrawnCheckbox({
    super.key,
    required this.checked,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged?.call(!checked),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          borderRadius: kCharcoalRadius,
          border: Border.all(color: JemsColors.ink, width: 2),
          color: checked ? JemsColors.charcoal : Colors.transparent,
        ),
        child: checked
            ? CustomPaint(
                size: const Size(24, 24),
                painter: _CheckPainter(),
              )
            : null,
      ),
    );
  }
}

class _CheckPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = JemsColors.paper
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.8, size.height * 0.25);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── PaperTexture overlay ───

class PaperTexture extends StatelessWidget {
  final Widget child;

  const PaperTexture({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Noise overlay — subtle grain effect
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _NoisePainter(),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final paint = Paint()..color = Colors.black.withAlpha(8);
    for (var i = 0; i < 800; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * size.width, rng.nextDouble() * size.height),
        rng.nextDouble() * 1.2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Dashed border separator ───

class DashedSeparator extends StatelessWidget {
  final Color color;
  final double height;

  const DashedSeparator({
    super.key,
    this.color = JemsColors.ink,
    this.height = 2,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _DashedPainter(color: color, strokeWidth: height),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  _DashedPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    const dashWidth = 8.0;
    const dashSpace = 5.0;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x + dashWidth, size.height / 2),
        paint,
      );
      x += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Charcoal section header (hand-drawn style) ───

class CharcoalSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final double rotation;

  const CharcoalSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.rotation = -1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Transform.rotate(
        angle: rotation * math.pi / 180,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.gloriaHallelujah(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: JemsColors.charcoal,
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: GoogleFonts.architectsDaughter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: JemsColors.ink.withAlpha(130),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Charcoal progress bar with hatched fill ───

class CharcoalProgressBar extends StatelessWidget {
  final double progress; // 0.0 to 1.0
  final Color fillColor;
  final double height;

  const CharcoalProgressBar({
    super.key,
    required this.progress,
    this.fillColor = JemsColors.mint,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: JemsColors.surface,
        borderRadius: BorderRadius.circular(height / 2),
        border: Border.all(color: JemsColors.ink, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              color: fillColor,
              border: Border(
                right: BorderSide(color: JemsColors.ink, width: 2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
