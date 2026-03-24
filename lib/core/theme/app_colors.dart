import 'package:flutter/material.dart';

abstract class AppColors {
  // Primary palette - Soft violet, friendly and works great on dark
  static const primary = Color(0xFF8B5CF6);
  static const primaryLight = Color(0xFFA78BFA);
  static const primaryDark = Color(0xFF7C3AED);

  // Secondary palette - Warm coral/peach for friendly accents
  static const secondary = Color(0xFFF472B6);
  static const secondaryLight = Color(0xFFF9A8D4);
  static const secondaryDark = Color(0xFFEC4899);

  // Dark theme surfaces (primary)
  static const background = Color(0xFF0F0F14);
  static const surface = Color(0xFF1A1A24);
  static const surfaceElevated = Color(0xFF252532);
  static const surfaceBright = Color(0xFF32323F);
  static const outline = Color(0xFF3D3D4D);
  static const outlineVariant = Color(0xFF2A2A38);

  // Text colors (for dark theme)
  static const textPrimary = Color(0xFFF4F4F6);
  static const textSecondary = Color(0xFFA0A0B0);
  static const textTertiary = Color(0xFF6B6B7A);
  static const textOnPrimary = Color(0xFFFFFFFF);

  // Study rating colors - softer for dark theme friendliness
  static const ratingAgain = Color(0xFFF87171); // Soft red
  static const ratingHard = Color(0xFFFBBF24); // Warm amber
  static const ratingGood = Color(0xFF4ADE80); // Soft green
  static const ratingEasy = Color(0xFF60A5FA); // Soft blue

  // Semantic colors
  static const error = Color(0xFFF87171);
  static const success = Color(0xFF4ADE80);
  static const warning = Color(0xFFFBBF24);

  // Light mode variants (secondary, if needed later)
  static const backgroundLight = Color(0xFFFAFAFC);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const surfaceElevatedLight = Color(0xFFF4F4F8);
  static const textPrimaryLight = Color(0xFF1A1A24);
  static const textSecondaryLight = Color(0xFF52525E);
}
