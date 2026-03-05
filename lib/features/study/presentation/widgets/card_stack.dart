import 'package:flutter/material.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';

/// Renders a radial gradient background with 1-2 "shadow" cards behind
/// the [topCard] to create a stacked-deck illusion.
///
/// The gradient uses the app's primary (violet, bottom-left) and secondary
/// (pink, top-right) colors at low opacity — matching the Lapse logo palette.
class CardStack extends StatelessWidget {
  final Widget topCard;
  final int remainingCards;

  const CardStack({
    super.key,
    required this.topCard,
    required this.remainingCards,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.bottomLeft,
          radius: 1.8,
          colors: [
            Color(0xBF8B5CF6), // primary at ~75% opacity
            Color(0x00000000),
          ],
        ),
      ),
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.8,
            colors: [
              Color(0xBFF472B6), // secondary at ~75% opacity
              Color(0x00000000),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: _buildStack(),
        ),
      ),
    );
  }

  Widget _buildStack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final children = <Widget>[];

        // Second shadow card (deepest).
        if (remainingCards > 2) {
          final shadowW = w * 0.95;
          final shadowH = h * 0.95;
          children.add(
            Positioned(
              top: h - shadowH + 12,
              left: w - shadowW + 12,
              width: shadowW,
              height: shadowH,
              child: Opacity(
                opacity: 0.3,
                child: _ShadowCard(),
              ),
            ),
          );
        }

        // First shadow card.
        if (remainingCards > 1) {
          final shadowW = w * 0.975;
          final shadowH = h * 0.975;
          children.add(
            Positioned(
              top: h - shadowH + 6,
              left: w - shadowW + 6,
              width: shadowW,
              height: shadowH,
              child: Opacity(
                opacity: 0.5,
                child: _ShadowCard(),
              ),
            ),
          );
        }

        // Top card at origin.
        children.add(
          Positioned(
            top: 0,
            left: 0,
            width: w,
            height: h,
            child: topCard,
          ),
        );

        return Stack(clipBehavior: Clip.none, children: children);
      },
    );
  }
}

class _ShadowCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
    );
  }
}
