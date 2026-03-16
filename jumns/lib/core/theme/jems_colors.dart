import 'package:flutter/material.dart';

/// Jems "Charcoal Sketch" palette — warm cream paper + charcoal ink + pastel blobs.
///
/// Design language: hand-drawn notebook feel with thick charcoal borders,
/// wobbly organic shapes, and pastel accent blobs floating behind cards.
abstract final class JemsColors {
  // ── Paper (backgrounds) ──
  static const paper = Color(0xFFFDFBF7); // warm cream
  static const paperDark = Color(0xFFE8E6E1); // warm gray
  static const surface = Color(0xFFFFFFFF);

  // ── Ink (text & borders) ──
  static const charcoal = Color(0xFF1A1A1A); // primary text
  static const ink = Color(0xFF2D2D2D); // borders, secondary text

  // ── Pastel accents ──
  static const coral = Color(0xFFFF9CA1);
  static const mint = Color(0xFF8CEDCA);
  static const lavender = Color(0xFFDCD3FF);
  static const markerBlue = Color(0xFFA5C9FF); // user message bubbles
  static const amber = Color(0xFFFFE082);
  static const smearRed = Color(0xFFFFB3B3);

  // ── Functional ──
  static const error = Color(0xFFEF4444);
  static const success = Color(0xFF34D399);

  // ── Charcoal border shadow ──
  static const borderShadow = Color(0xCC000000); // rgba(0,0,0,0.8)

  /// Category color mapping for goals/cards
  static Color categoryColor(String category) => switch (category.toLowerCase()) {
        'health' || 'fitness' => mint,
        'learning' || 'education' => markerBlue,
        'finance' || 'money' => amber,
        'personal' => lavender,
        'professional' || 'work' || 'career' => coral,
        _ => markerBlue,
      };

  /// Accent rotation for decorative blob backgrounds
  static const blobColors = [mint, markerBlue, lavender, coral, amber];
}
