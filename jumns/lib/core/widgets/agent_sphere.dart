import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/spatial_colors.dart';

/// 3D clay-like agent sphere with kawaii face, gloss shine, and optional blush.
/// Agents are identified by color (green, yellow, pink, violet), not by name.
class AgentSphere extends StatelessWidget {
  final String agentColor;
  final double size;
  final bool showFace;
  final bool interactive;
  final VoidCallback? onTap;

  const AgentSphere({
    super.key,
    required this.agentColor,
    this.size = 80,
    this.showFace = true,
    this.interactive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradient = SpatialColors.agentGradient(agentColor);
    final shadows = SpatialColors.agentShadow(agentColor);
    final eyeSize = size * 0.075;
    final eyeGap = size * 0.1;
    final isPink = agentColor == 'pink';

    Widget sphere = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        boxShadow: shadows,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Kawaii face
          if (showFace)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: eyeSize,
                  height: eyeSize,
                  decoration: const BoxDecoration(
                    color: SpatialColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: eyeGap),
                Container(
                  width: eyeSize,
                  height: eyeSize,
                  decoration: const BoxDecoration(
                    color: SpatialColors.textPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          // Gloss shine
          Positioned(
            top: size * 0.12,
            left: size * 0.19,
            child: Transform.rotate(
              angle: -20 * math.pi / 180,
              child: Container(
                width: size * 0.2,
                height: size * 0.1,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(77),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ),
          // Blush marks for pink agent
          if (isPink) ...[
            Positioned(
              bottom: size * 0.25,
              left: size * 0.15,
              child: Container(
                width: size * 0.15,
                height: size * 0.075,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A8D4).withAlpha(102),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
            Positioned(
              bottom: size * 0.25,
              right: size * 0.15,
              child: Container(
                width: size * 0.15,
                height: size * 0.075,
                decoration: BoxDecoration(
                  color: const Color(0xFFF9A8D4).withAlpha(102),
                  borderRadius: BorderRadius.circular(9999),
                ),
              ),
            ),
          ],

        ],
      ),
    );

    if (interactive && onTap != null) {
      sphere = GestureDetector(onTap: onTap, child: sphere);
    }

    return sphere;
  }
}

/// Small agent indicator dot (24px) used in message labels.
class AgentDot extends StatelessWidget {
  final String agentColor;
  final double size;

  const AgentDot({super.key, required this.agentColor, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SpatialColors.agentGradient(agentColor),
      ),

    );
  }
}
