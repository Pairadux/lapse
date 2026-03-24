/// Material Design 3 spacing constants based on 4dp baseline grid.
///
/// Use these constants throughout the app for consistent spacing.
/// All values are multiples of 4 for proper Material alignment.
///
/// Reference: https://m3.material.io/foundations/layout/understanding-layout/spacing
abstract class Spacing {
  // Base unit
  static const double unit = 4;

  // Common spacing values (multiples of 4)
  static const double xs = 4; // Extra small: tight spacing, text gaps
  static const double sm = 8; // Small: icon gaps, compact elements
  static const double md = 12; // Medium: balanced spacing
  static const double lg = 16; // Large: standard padding, card margins
  static const double xl = 24; // Extra large: section spacing
  static const double xxl = 32; // Double extra large: major sections
  static const double xxxl = 48; // Triple extra large: page margins

  // Semantic spacing
  static const double cardPadding = 16;
  static const double cardMarginH = 16;
  static const double cardMarginV = 8;
  static const double listItemSpacing = 8;
  static const double sectionSpacing = 24;
  static const double screenPadding = 16;
  static const double iconSize = 24;
  static const double iconContainerSize = 48; // Touch target minimum
  static const double buttonHeight = 48; // Touch target minimum
  static const double inputHeight = 56;

  // Border radius (also follows 4dp grid)
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusFull = 9999; // Fully rounded (pill shape)
}
