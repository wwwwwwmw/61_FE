import 'package:flutter/material.dart';

class AppColors {
  // Primary Colors
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF5F3DC4);
  static const Color primaryLight = Color(0xFF917FF9);

  // Accent Colors
  static const Color accent = Color(0xFFFF6B9D);
  static const Color accentDark = Color(0xFFE65288);
  static const Color accentLight = Color(0xFFFF8FB0);

  // Background Colors
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF0F1117); // deeper dark
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF111827); // deeper surface

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF2C3E50);
  static const Color textSecondaryLight = Color(0xFF7F8C8D);
  static const Color textPrimaryDark = Color(0xFFECF0F1);
  static const Color textSecondaryDark = Color(0xFFBDC3C7);

  // Status Colors
  static const Color success = Color(0xFF2ECC71);
  static const Color warning = Color(0xFFF39C12);
  static const Color error = Color(0xFFE74C3C);
  static const Color info = Color(0xFF3498DB);

  // Priority Colors
  static const Color priorityLow = Color(0xFF95A5A6);
  static const Color priorityMedium = Color(0xFFF39C12);
  static const Color priorityHigh = Color(0xFFE74C3C);

  // Category Colors
  static const List<Color> categoryColors = [
    Color(0xFF3498DB), // Blue
    Color(0xFF2ECC71), // Green
    Color(0xFFE74C3C), // Red
    Color(0xFFF39C12), // Orange
    Color(0xFF9B59B6), // Purple
    Color(0xFF1ABC9C), // Teal
    Color(0xFFE91E63), // Pink
    Color(0xFFFF5722), // Deep Orange
  ];

  // Gradient Colors
  static const List<Color> primaryGradient = [
    Color(0xFF6C5CE7),
    Color(0xFF917FF9),
  ];

  static const List<Color> accentGradient = [
    Color(0xFFFF6B9D),
    Color(0xFFFF8FB0),
  ];

  // Chart Colors
  static const List<Color> chartColors = [
    Color(0xFF6C5CE7),
    Color(0xFFFF6B9D),
    Color(0xFF2ECC71),
    Color(0xFFF39C12),
    Color(0xFF3498DB),
    Color(0xFF9B59B6),
    Color(0xFF1ABC9C),
    Color(0xFFE74C3C),
  ];

  // Shadow Colors
  static Color shadowLight = Colors.black.withValues(alpha: 0.1);
  static Color shadowDark = Colors.black.withValues(alpha: 0.3);
}
