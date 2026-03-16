import 'package:flutter/material.dart';

/// Jems Spatial OS color system — pure white, glassmorphism, agent gradients.
abstract final class SpatialColors {
  // ── Backgrounds ──
  static const background = Color(0xFFFCFCFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceSubtle = Color(0xFFF8FAFC);
  static const surfaceMuted = Color(0xFFF1F5F9);

  // ── Text ──
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF334155);
  static const textTertiary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFFCBD5E1);

  // ── Agent colors (by color, not name) ──
  static const agentGreen = Color(0xFF10B981);
  static const agentYellow = Color(0xFFFACC15);
  static const agentPink = Color(0xFFF472B6);
  static const agentViolet = Color(0xFFA78BFA);

  // ── User message ──
  static const userBubble = Color(0xFF4A90E2);

  // ── Functional ──
  static const proofBadgeBg = Color(0xFFFEFCE8);
  static const proofBadgeBorder = Color(0xFFFEF9C3);
  static const proofBadgeText = Color(0xFFCA8A04);
  static const verifiedBadgeBg = Color(0xFFEFF6FF);
  static const verifiedBadgeText = Color(0xFF60A5FA);
  static const checkBg = Color(0xFFE0F2FE);

  // ── Glass ──
  static final glassBg = Colors.white.withAlpha(217); // 0.85
  static final glassBorder = Colors.white.withAlpha(128); // 0.5
  static final glassShadow = Colors.black.withAlpha(20); // 0.08
  static final inputGlassBg = Colors.white.withAlpha(179); // 0.7

  // ── Agent sphere gradients ──
  static const noorGradient = RadialGradient(
    center: Alignment(-0.3, -0.3),
    radius: 0.9,
    colors: [Color(0xFFD1FAE5), Color(0xFFA7F3D0), Color(0xFF6EE7B7)],
    stops: [0.0, 0.4, 1.0],
  );

  static const kaiGradient = RadialGradient(
    center: Alignment(-0.4, -0.4),
    radius: 1.0,
    colors: [Color(0xFFFEF08A), Color(0xFFFDDE50), Color(0xFFFACC15)],
    stops: [0.0, 0.5, 1.0],
  );

  static const sageGradient = RadialGradient(
    center: Alignment(-0.3, -0.3),
    radius: 0.9,
    colors: [Color(0xFFFCE7F3), Color(0xFFFBCFE8), Color(0xFFF8ABBC)],
    stops: [0.0, 0.5, 1.0],
  );

  static const echoGradient = RadialGradient(
    center: Alignment(-0.3, -0.3),
    radius: 0.9,
    colors: [
      Color(0xFFC4B5FD),
      Color(0xFFA889FA),
      Color(0xFF8B5CF6),
      Color(0xFF6D28D9),
    ],
    stops: [0.0, 0.3, 0.6, 1.0],
  );

  /// Get gradient for agent color key.
  static RadialGradient agentGradient(String color) => switch (color) {
        'green' || 'noor' => noorGradient,
        'yellow' || 'kai' => kaiGradient,
        'pink' || 'sage' => sageGradient,
        'violet' || 'echo' => echoGradient,
        _ => noorGradient,
      };

  /// Get label color for agent color key.
  static Color agentColor(String color) => switch (color) {
        'green' || 'noor' => agentGreen,
        'yellow' || 'kai' => const Color(0xFFFFD93D),
        'pink' || 'sage' => agentPink,
        'violet' || 'echo' => agentViolet,
        _ => agentGreen,
      };

  /// Get sphere shadow for agent color key.
  static List<BoxShadow> agentShadow(String color) => switch (color) {
        'green' || 'noor' => [BoxShadow(offset: const Offset(20, 30), blurRadius: 50, color: Colors.black.withAlpha(20))],
        'yellow' || 'kai' => [BoxShadow(offset: const Offset(10, 15), blurRadius: 25, color: const Color(0xFFFACC15).withAlpha(51))],
        'pink' || 'sage' => [BoxShadow(offset: const Offset(10, 10), blurRadius: 25, color: const Color(0xFFFFD1DC).withAlpha(102))],
        'violet' || 'echo' => [BoxShadow(offset: const Offset(10, 15), blurRadius: 25, color: const Color(0xFF8B5CF6).withAlpha(77))],
        _ => [BoxShadow(offset: const Offset(20, 30), blurRadius: 50, color: Colors.black.withAlpha(20))],
      };

  /// Map agent name to display label.
  static String agentLabel(String agent) => switch (agent) {
        'green' || 'noor' => 'NOOR',
        'yellow' || 'kai' => 'KAI',
        'pink' || 'sage' => 'SAGE',
        'violet' || 'echo' => 'ECHO',
        _ => 'NOOR',
      };
}
