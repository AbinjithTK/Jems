import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/spatial_colors.dart';

/// Frosted glass container with backdrop blur and soft border.
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blurAmount;
  final double borderRadius;
  final EdgeInsets? padding;
  final double? width;
  final double? height;

  const GlassContainer({
    super.key,
    required this.child,
    this.blurAmount = 10,
    this.borderRadius = 9999,
    this.padding,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
        child: Container(
          width: width,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: SpatialColors.glassBg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: SpatialColors.glassBorder),
            boxShadow: [
              BoxShadow(
                offset: const Offset(0, 8),
                blurRadius: 32,
                color: SpatialColors.glassShadow,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
