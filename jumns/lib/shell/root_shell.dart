import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/jems_colors.dart';

class RootShell extends StatelessWidget {
  final Widget child;
  const RootShell({super.key, required this.child});

  static int _indexFromLocation(String location) {
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/goals')) return 2;
    if (location.startsWith('/toolkit')) return 3;
    if (location.startsWith('/settings')) return 4;
    return 0;
  }

  static const _tabs = [
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chat'),
    (Icons.check_circle_outline_rounded, Icons.check_circle_rounded, 'Tasks'),
    (Icons.flag_outlined, Icons.flag_rounded, 'Goals'),
    (Icons.handyman_outlined, Icons.handyman_rounded, 'Toolkit'),
    (Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
  ];

  static const _routes = ['/chat', '/tasks', '/goals', '/toolkit', '/settings'];

  // Each active tab gets a pastel blob color
  static const _blobColors = [
    JemsColors.markerBlue,
    JemsColors.lavender,
    JemsColors.mint,
    JemsColors.lavender,
    JemsColors.lavender,
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);

    return Scaffold(
      backgroundColor: JemsColors.paper,
      body: child,
      bottomNavigationBar: _CharcoalNavBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(_routes[i]),
      ),
    );
  }
}

class _CharcoalNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CharcoalNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: JemsColors.paper.withAlpha(240),
        border: const Border(
          top: BorderSide(
            color: JemsColors.ink,
            width: 2,
            style: BorderStyle.solid,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              final isActive = i == currentIndex;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: SizedBox(
                  width: 68,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Blob-shaped active indicator behind icon
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isActive)
                            Transform.rotate(
                              angle: -3 * math.pi / 180,
                              child: Container(
                                width: 48,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: RootShell._blobColors[i].withAlpha(100),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.elliptical(40, 55),
                                    topRight: Radius.elliptical(60, 45),
                                    bottomLeft: Radius.elliptical(70, 60),
                                    bottomRight: Radius.elliptical(30, 40),
                                  ),
                                ),
                              ),
                            ),
                          Icon(
                            isActive
                                ? RootShell._tabs[i].$2
                                : RootShell._tabs[i].$1,
                            color: isActive
                                ? JemsColors.charcoal
                                : JemsColors.ink.withAlpha(150),
                            size: isActive ? 26 : 24,
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        RootShell._tabs[i].$3,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.architectsDaughter(
                          color: isActive
                              ? JemsColors.charcoal
                              : JemsColors.ink.withAlpha(150),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
