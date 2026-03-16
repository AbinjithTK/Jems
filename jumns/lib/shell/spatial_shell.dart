import 'package:flutter/material.dart';
import '../core/theme/spatial_colors.dart';
import 'floating_dock.dart';

/// Spatial OS root shell — white background + floating dock overlay.
/// Replaces the old RootShell with bottom tab bar.
class SpatialShell extends StatelessWidget {
  final Widget child;
  const SpatialShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpatialColors.background,
      body: Stack(
        children: [
          // Screen content with bottom padding for dock
          Positioned.fill(
            child: child,
          ),
          // Floating dock overlay (fills screen for voice/chat overlays)
          const Positioned.fill(
            child: FloatingDock(),
          ),
        ],
      ),
    );
  }
}
