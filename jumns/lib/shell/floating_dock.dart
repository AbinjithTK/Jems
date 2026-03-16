import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/providers/auth_provider.dart';
import '../core/services/voice_service.dart';
import '../core/theme/spatial_colors.dart';
import '../core/widgets/agent_sphere.dart';
import '../core/widgets/quick_chat_overlay.dart';

/// Nav tab definition (only 3 tabs now: Hub, Eco, Profile).
class _TabItem {
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _TabItem(this.route, this.icon, this.activeIcon, this.label);
}

const _leftTabs = [
  _TabItem('/hub', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Hub'),
];

const _rightTabs = [
  _TabItem('/ecosystem', Icons.widgets_outlined, Icons.widgets_rounded, 'Eco'),
  _TabItem('/settings', Icons.person_outline_rounded, Icons.person_rounded, 'Profile'),
];

/// All jem agents the user can swipe/select through.
class _JemAgent {
  final String color;
  final String route;
  final String label;
  const _JemAgent(this.color, this.route, this.label);
}

const _allJems = [
  _JemAgent('green', '/hub', 'Chat'),
  _JemAgent('yellow', '/schedule', 'Planner'),
  _JemAgent('violet', '/journal', 'Journal'),
  _JemAgent('pink', '/lounge', 'Social'),
];

/// Floating Dock — 3 tabs + centered agent sphere with swipe & radial selector.
class FloatingDock extends ConsumerStatefulWidget {
  const FloatingDock({super.key});
  @override
  ConsumerState<FloatingDock> createState() => _FloatingDockState();
}

class _FloatingDockState extends ConsumerState<FloatingDock>
    with TickerProviderStateMixin {
  bool _showQuickChat = false;
  bool _isLiveMode = false;
  bool _showRadialSelector = false;
  int _hoveredAgentIndex = -1;
  Offset _longPressOrigin = Offset.zero;

  // Current jem index (for vertical swipe cycling)
  int _currentJemIndex = 0;

  late final AnimationController _breatheCtrl;
  late final Animation<double> _breatheAnim;
  late final AnimationController _radialCtrl;
  late final Animation<double> _radialAnim;
  late final AnimationController _entranceCtrl;
  late final Animation<double> _entranceSlide;
  late final Animation<double> _entranceFade;
  // Swipe animation
  late final AnimationController _swipeCtrl;
  late Animation<double> _swipeOffset;

  @override
  void initState() {
    super.initState();
    _breatheCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));
    _breatheAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );
    _radialCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _radialAnim = CurvedAnimation(parent: _radialCtrl, curve: Curves.easeOutBack);
    _entranceCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _entranceSlide = Tween<double>(begin: 80, end: 0).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
    );
    _entranceFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _entranceCtrl, curve: const Interval(0, 0.6)),
    );
    _swipeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _swipeOffset = Tween<double>(begin: 0, end: 0).animate(_swipeCtrl);
    _entranceCtrl.forward();
    // Sync jem index with current route after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncJemIndex());
  }

  void _syncJemIndex() {
    if (!mounted) return;
    final location = GoRouterState.of(context).uri.toString();
    final idx = _allJems.indexWhere((j) => location.startsWith(j.route));
    if (idx >= 0 && idx != _currentJemIndex) {
      setState(() => _currentJemIndex = idx);
    }
  }

  @override
  void dispose() {
    _removeRadialOverlay();
    _breatheCtrl.dispose();
    _radialCtrl.dispose();
    _entranceCtrl.dispose();
    _swipeCtrl.dispose();
    super.dispose();
  }

  String get _currentAgentColor => _allJems[_currentJemIndex].color;

  String _getUserId() {
    final authState = ref.read(authNotifierProvider);
    return authState.user?.sub ?? 'demo-user';
  }

  // ── Tap / double-tap ──
  void _onSphereTap() {
    if (_isLiveMode) { _endLiveMode(); return; }
    HapticFeedback.lightImpact();
    setState(() => _showQuickChat = true);
  }

  void _onSphereDoubleTap() {
    if (_isLiveMode) { _endLiveMode(); return; }
    HapticFeedback.mediumImpact();
    setState(() { _showQuickChat = false; _isLiveMode = true; });
    _breatheCtrl.repeat(reverse: true);
    final userId = _getUserId();
    ref.read(voiceServiceProvider).startSession(
      userId: userId, agentName: _currentAgentColor, sendHi: true,
    );
  }

  void _endLiveMode() {
    ref.read(voiceServiceProvider).endSession();
    _breatheCtrl.stop();
    _breatheCtrl.reset();
    setState(() => _isLiveMode = false);
  }

  // ── Vertical swipe to cycle jems ──
  double _swipeDy = 0;

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    _swipeDy += d.delta.dy;
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_swipeDy.abs() < 20) { _swipeDy = 0; return; }
    final direction = _swipeDy < 0 ? 1 : -1; // swipe up = next, swipe down = prev
    final newIndex = (_currentJemIndex + direction).clamp(0, _allJems.length - 1);
    _swipeDy = 0;
    if (newIndex == _currentJemIndex) return;

    HapticFeedback.selectionClick();
    // Animate sphere out then in
    _swipeOffset = Tween<double>(begin: 0, end: direction * -30.0).animate(
      CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeIn),
    );
    _swipeCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() => _currentJemIndex = newIndex);
      context.go(_allJems[newIndex].route);
      _swipeOffset = Tween<double>(begin: direction * 30.0, end: 0).animate(
        CurvedAnimation(parent: _swipeCtrl, curve: Curves.easeOut),
      );
      _swipeCtrl.forward(from: 0);
    });
  }

  // ── Radial selector (long press) — uses Overlay for correct global positioning ──
  final GlobalKey _sphereKey = GlobalKey();
  Offset _sphereCenter = Offset.zero;
  OverlayEntry? _radialOverlay;

  void _onLongPressStart(LongPressStartDetails details) {
    if (_isLiveMode) return;
    HapticFeedback.heavyImpact();
    final rb = _sphereKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb != null) {
      final pos = rb.localToGlobal(Offset.zero);
      _sphereCenter = Offset(pos.dx + rb.size.width / 2, pos.dy + rb.size.height / 2);
    } else {
      _sphereCenter = details.globalPosition;
    }
    _longPressOrigin = _sphereCenter;
    _hoveredAgentIndex = -1;
    _showRadialSelector = true;
    _radialCtrl.forward(from: 0);
    _showRadialOverlay();
  }

  void _showRadialOverlay() {
    _removeRadialOverlay();
    _radialOverlay = OverlayEntry(
      builder: (_) => _RadialOverlayWidget(
        animation: _radialAnim,
        hoveredIndex: _hoveredAgentIndex,
        sphereCenter: _sphereCenter,
      ),
    );
    Overlay.of(context).insert(_radialOverlay!);
  }

  void _updateRadialOverlay() {
    _radialOverlay?.markNeedsBuild();
  }

  void _removeRadialOverlay() {
    _radialOverlay?.remove();
    _radialOverlay = null;
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_showRadialSelector) return;
    final dx = details.globalPosition.dx - _longPressOrigin.dx;
    final dy = details.globalPosition.dy - _longPressOrigin.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    if (distance < 14) {
      if (_hoveredAgentIndex != -1) {
        _hoveredAgentIndex = -1;
        _updateRadialOverlay();
      }
      return;
    }
    final angle = math.atan2(dx, -dy);
    // Detection angles match visual angles: -45°, -15°, +15°, +45° in radians
    const agentAngles = [-0.7854, -0.2618, 0.2618, 0.7854];
    int closest = -1;
    double minDiff = double.infinity;
    for (int i = 0; i < agentAngles.length; i++) {
      var diff = (angle - agentAngles[i]).abs();
      if (diff > math.pi) diff = 2 * math.pi - diff;
      if (diff < minDiff && diff < 0.55) { minDiff = diff; closest = i; }
    }
    if (closest != _hoveredAgentIndex) {
      if (closest >= 0) HapticFeedback.selectionClick();
      _hoveredAgentIndex = closest;
      _updateRadialOverlay();
    }
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_showRadialSelector) return;
    final selectedIndex = _hoveredAgentIndex;
    _showRadialSelector = false;
    _radialCtrl.reverse().then((_) {
      _removeRadialOverlay();
      if (mounted) setState(() => _hoveredAgentIndex = -1);
    });
    if (selectedIndex >= 0 && selectedIndex < _allJems.length) {
      HapticFeedback.mediumImpact();
      setState(() => _currentJemIndex = selectedIndex);
      context.go(_allJems[selectedIndex].route);
    }
  }

  // ── Which tab is active ──
  int _activeTabSide(String location) {
    // -1 = left Hub, 0 = center sphere, 1 = right Eco, 2 = right Profile
    if (location.startsWith('/ecosystem')) return 1;
    if (location.startsWith('/settings')) return 2;
    if (location.startsWith('/hub')) return -1;
    return 0; // schedule, journal, lounge → sphere is active
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final activeSide = _activeTabSide(location);
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final agentColor = _currentAgentColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Bottom nav bar ──
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: AnimatedBuilder(
            animation: _entranceCtrl,
            builder: (context, child) => Transform.translate(
              offset: Offset(0, _entranceSlide.value),
              child: Opacity(opacity: _entranceFade.value, child: child),
            ),
            child: ClipRRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  padding: EdgeInsets.only(bottom: bottomPad + 4, top: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(230),
                    border: Border(top: BorderSide(color: Colors.black.withAlpha(8))),
                  ),
                  child: Row(
                    children: [
                      // Hub tab
                      _buildTab(_leftTabs[0], activeSide == -1),
                      // Eco tab
                      _buildTab(_rightTabs[0], activeSide == 1),
                      // Agent sphere (center)
                      Expanded(
                        child: Center(
                          child: _buildCenterSphere(agentColor, activeSide == 0),
                        ),
                      ),
                      // Profile tab
                      _buildTab(_rightTabs[1], activeSide == 2),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── Jem label tooltip (shows briefly on swipe) ──

        // ── Quick chat overlay ──
        if (_showQuickChat)
          Positioned.fill(
            child: QuickChatOverlay(
              agentColor: agentColor,
              onClose: () => setState(() => _showQuickChat = false),
            ),
          ),
      ],
    );
  }

  Widget _buildTab(_TabItem tab, bool isActive) {
    final color = isActive ? SpatialColors.agentGreen : SpatialColors.textTertiary;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          context.go(tab.route);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 4 : 0,
                height: isActive ? 4 : 0,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              Icon(isActive ? tab.activeIcon : tab.icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                tab.label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: color,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterSphere(String agentColor, bool isAgentScreen) {
    final color = SpatialColors.agentColor(agentColor);
    final jem = _allJems[_currentJemIndex];

    return GestureDetector(
      onTap: _onSphereTap,
      onDoubleTap: _onSphereDoubleTap,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sphere with swipe animation
          AnimatedBuilder(
            animation: _swipeCtrl,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _swipeOffset.value),
                child: Opacity(
                  opacity: (1.0 - (_swipeOffset.value.abs() / 30.0)).clamp(0.3, 1.0),
                  child: child,
                ),
              );
            },
            child: SizedBox(
              key: _sphereKey,
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Breathing rings (live mode)
                  if (_isLiveMode)
                    AnimatedBuilder(
                      animation: _breatheAnim,
                      builder: (context, _) {
                        final v = _breatheAnim.value;
                        return Transform.scale(
                          scale: 1.0 + (v * 0.15),
                          child: Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color.withAlpha(((0.6 - v * 0.3).clamp(0, 1) * 255).toInt()),
                                width: 3,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  // Glass container + sphere
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withAlpha(200),
                      border: Border.all(
                        color: _isLiveMode ? color.withAlpha(180) : Colors.white.withAlpha(77),
                        width: _isLiveMode ? 2.5 : 1,
                      ),
                      boxShadow: _isLiveMode
                          ? [BoxShadow(color: color.withAlpha(60), blurRadius: 20, spreadRadius: 2)]
                          : [
                              BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 12),
                              BoxShadow(color: color.withAlpha(15), blurRadius: 8, offset: const Offset(0, 3)),
                            ],
                    ),
                    child: Center(
                      child: AgentSphere(agentColor: agentColor, size: 42, showFace: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Label
          Text(
            jem.label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: isAgentScreen ? FontWeight.w700 : FontWeight.w500,
              color: isAgentScreen ? color : SpatialColors.textTertiary,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Radial Agent Selector (rendered in Overlay with global coordinates) ───

class _RadialOverlayWidget extends StatelessWidget {
  final Animation<double> animation;
  final int hoveredIndex;
  final Offset sphereCenter;
  const _RadialOverlayWidget({required this.animation, required this.hoveredIndex, required this.sphereCenter});

  @override
  Widget build(BuildContext context) {
    const radius = 100.0;
    const sphereSize = 32.0;
    const hoveredSize = 40.0;
    // Angles in degrees measured from straight-up (0°).
    // Negative = left, positive = right. All point upward.
    // Tighter 90° arc: -45°, -15°, +15°, +45° to stay within screen bounds.
    const angles = [-45.0, -15.0, 15.0, 45.0];

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final progress = animation.value;
        if (progress < 0.01) return const SizedBox.shrink();

        return Stack(
          children: [
            for (int i = 0; i < _allJems.length; i++)
              _buildOption(i, progress, radius, sphereSize, hoveredSize, angles),
          ],
        );
      },
    );
  }

  Widget _buildOption(int i, double progress, double radius, double sphereSize, double hoveredSize, List<double> angles) {
    final agent = _allJems[i];
    final isHovered = i == hoveredIndex;
    final size = isHovered ? hoveredSize : sphereSize;
    final color = SpatialColors.agentColor(agent.color);

    final rad = angles[i] * math.pi / 180;
    // sin gives horizontal offset, cos gives vertical (positive cos = upward since we negate)
    final dx = math.sin(rad) * radius * progress;
    final dy = -math.cos(rad) * radius * progress; // negative = upward

    // Position relative to sphere center in global screen coords
    final left = sphereCenter.dx + dx - size / 2;
    final top = sphereCenter.dy + dy - size / 2;

    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: Opacity(
          opacity: progress.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: isHovered ? 1.0 : 0.85 + (0.15 * progress),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: isHovered
                      ? BoxDecoration(shape: BoxShape.circle, boxShadow: [
                          BoxShadow(color: color.withAlpha(60), blurRadius: 10, spreadRadius: 2),
                        ])
                      : null,
                  child: AgentSphere(agentColor: agent.color, size: size, showFace: false),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isHovered ? Colors.white.withAlpha(230) : Colors.white.withAlpha(180),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 4)],
                  ),
                  child: Text(
                    agent.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isHovered ? FontWeight.w700 : FontWeight.w600,
                      color: isHovered ? color : SpatialColors.textTertiary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
