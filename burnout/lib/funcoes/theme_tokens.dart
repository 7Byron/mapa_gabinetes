import 'package:flutter/material.dart';

class ThemeTokens {
  // Radii
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 20.0;

  // Gradients (centralizados para coerência visual)
  static const LinearGradient gradMain = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFFA000)], // amber/gold
  );

  static const LinearGradient gradActive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF43A047), Color(0xFF00897B)], // green/teal
  );

  static const LinearGradient gradInactive = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE0E0E0), Color(0xFFEEEEEE)], // greys
  );

  static const LinearGradient gradAmberLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFFF59D)], // amber -> yellow light
  );

  static const LinearGradient gradOrangeLight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFCC80), Color(0xFFFFF59D)], // orange light -> yellow light
  );

  // Shadows
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4.0,
      offset: Offset(0.0, 2.0),
    ),
  ];

  static const List<BoxShadow> shadowMedium = [
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 8.0,
      offset: Offset(0.0, 4.0),
    ),
  ];

  static const List<BoxShadow> shadowStrong = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 20.0,
      offset: Offset(0.0, 5.0),
    ),
  ];

  // Durations
  static const Duration durFast = Duration(milliseconds: 150);
  static const Duration durNormal = Duration(milliseconds: 250);
  static const Duration durSlow = Duration(milliseconds: 500);
}

