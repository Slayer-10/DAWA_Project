import 'package:flutter/material.dart';

/// Exact DAWA brand design tokens
class DawaColors {
  static const Color indigo = Color(0xFF312E81);     // Deep Royal Indigo
  static const Color purple = Color(0xFF6D28D9);     // Premium Purple
  static const Color violet = Color(0xFF8B5CF6);     // Electric Violet
  static const Color lavender = Color(0xFFA78BFA);   // Soft Lavender
  static const Color white = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF8F7FC); // Main App Background
  static const Color surface = Color(0xFFF1EDFF);    // Light Tint Surface
  static const Color text = Color(0xFF211E3B);       // Primary High-Contrast Text
  static const Color text2 = Color(0xFF77758A);      // Secondary Muted Text
  static const Color border = Color(0xFFE9E6F0);     // Subtle Divider/Border
  static const Color success = Color(0xFF24845A);    // Verified & Success Green
  static const Color amber = Color(0xFFD97706);      // Warning Amber
  static const Color danger = Color(0xFFDC2626);     // Error Red
}

class DawaSpacing {
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
}

class DawaRadii {
  static const double input = 10.0;
  static const double card = 14.0;
  static const double sheet = 20.0;
  static const double chip = 999.0; // full pill
  static const double button = 12.0;
}

class DawaShadows {
  static final List<BoxShadow> soft = [
    BoxShadow(
      color: const Color(0xFF312E81).withValues(alpha: 0.04),
      blurRadius: 12,
      offset: const Offset(0, 3),
    ),
  ];

  static final List<BoxShadow> card = [
    BoxShadow(
      color: const Color(0xFF312E81).withValues(alpha: 0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static final List<BoxShadow> nav = [
    BoxShadow(
      color: const Color(0xFF211E3B).withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, -4),
    ),
  ];
}

class DawaDurations {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration entrance = Duration(milliseconds: 300);
}

