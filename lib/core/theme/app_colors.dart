import 'package:flutter/material.dart';

/// Modern Blue & White Palette (matching the reference fintech/neo design)
class AppColors {
  AppColors._();

  // Primary Blues & Header
  static const Color primary = Color(0xFF00A3E0); // Vibrant Sky Blue
  static const Color primaryDark = Color(0xFF0288D1); // Deep Ocean Blue
  static const Color primaryLight = Color(0xFFE0F2FE); // Soft Pastel Blue (for grid tiles)
  static const Color primaryMuted = Color(0xFFBAE6FD);

  // Accent Colors
  static const Color accentOrange = Color(0xFFFF7A00); // Brand Orange Wave
  static const Color accentYellow = Color(0xFFFFB800); // Trophy Gold
  static const Color accentCyan = Color(0xFF00D2FF);
  static const Color accentPurple = Color(0xFF6366F1);
  static const Color secondary = Color(0xFFFF3B5C); // Crimson / Alert

  // Surfaces & Backgrounds
  static const Color headerBackground = Color(0xFF0288D1); // Top Header Curved Blue
  static const Color background = Color(0xFFF8FAFC); // Main light background
  static const Color surface = Color(0xFFFFFFFF); // Pure White Card Surface
  static const Color surfaceElevated = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF1F5F9);
  static const Color surfaceHighlight = Color(0xFFF1F5F9);
  static const Color surfaceBlueTile = Color(0xFFE1F5FE); // Soft Blue Rounded Icon Container

  // Typography & Content
  static const Color textPrimary = Color(0xFF0F172A); // Deep Navy Slate
  static const Color textSecondary = Color(0xFF64748B); // Slate Gray
  static const Color textTertiary = Color(0xFF94A3B8); // Muted Gray
  static const Color textDisabled = Color(0xFFCBD5E1);
  static const Color textOnBlue = Color(0xFFFFFFFF);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color borderInput = Color(0xFFCBD5E1); // Pill border
  static const Color borderFocus = Color(0xFF00A3E0);
  static const Color borderError = Color(0xFFFF3B5C);

  // Accent Aliases
  static const Color accentAmber = Color(0xFFFFB800); // Trophy Gold

  // Status Colors
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF00A3E0);
}
