import 'package:flutter/material.dart';

/// Walkman-inspired monochrome palette: black canvas, silver-gray text,
/// hairline separators, and a single warm amber accent used sparingly
/// (playing state, spectrum bars, active toggles).
class UiColors {
  UiColors._();

  static const Color bg = Color(0xFF0A0A0B);        // main canvas (near-black)
  static const Color surface = Color(0xFF141415);   // rows, bars, placeholders
  static const Color line = Color(0xFF262627);      // hairline separators
  static const Color text = Color(0xFFE6E6E6);      // primary text (silver)
  static const Color textDim = Color(0xFF9A9A9A);   // secondary text
  static const Color textFaint = Color(0xFF5C5C5E); // tertiary text
  static const Color accent = Color(0xFFD8A657);    // warm amber
}
