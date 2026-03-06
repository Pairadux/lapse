import 'package:flutter/material.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';

/// Renders a diagonal gradient background with 1-2 "shadow" cards behind
/// the [topCard] to create a stacked-deck illusion.
///
/// The gradient sweeps from primary violet (bottom-left) to secondary pink
/// (top-right) — matching the Lapse logo palette.
class CardStack extends StatelessWidget {
  final Widget topCard;
  final int remainingCards;

  /// 0.0 = idle, 1.0 = top card fully dismissed.
  /// Shadow cards fade toward full opacity as this increases.
  final double dismissProgress;

  const CardStack({
    super.key,
    required this.topCard,
    required this.remainingCards,
    this.dismissProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xBF8B5CF6), // primary violet
            Color(0xBFF472B6), // secondary pink
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: _buildStack(),
      ),
    );
  }

  Widget _buildStack() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final children = <Widget>[];

        // Shadow card sizes and offsets at rest.
        const double opacity1 = 0.5; // first shadow resting opacity
        const double opacity2 = 0.3; // second shadow resting opacity
        const double offset1 = 6.0;
        const double offset2 = 12.0;
        final shadow1W = w * 0.99;
        final shadow1H = h * 0.99;
        final shadow2W = w * 0.98;
        final shadow2H = h * 0.98;

        final t = dismissProgress;

        // Third phantom shadow — fades in during dismiss to replace
        // the second shadow as it promotes forward.
        if (remainingCards > 3 && t > 0) {
          const double opacity3 = 0.15;
          const double offset3 = 18.0;
          final shadow3W = w * 0.97;
          final shadow3H = h * 0.97;
          final curW = shadow3W + (shadow2W - shadow3W) * t;
          final curH = shadow3H + (shadow2H - shadow3H) * t;
          final curOffset = offset3 + (offset2 - offset3) * t;
          children.add(
            Positioned(
              top: h - curH + curOffset,
              left: w - curW + curOffset,
              width: curW,
              height: curH,
              child: Opacity(
                opacity: opacity3 + (opacity2 - opacity3) * t,
                child: _ShadowCard(),
              ),
            ),
          );
        }

        // Second shadow card (deepest visible at rest).
        // Slides toward first shadow's resting position as top card leaves.
        if (remainingCards > 2) {
          final curW = shadow2W + (shadow1W - shadow2W) * t;
          final curH = shadow2H + (shadow1H - shadow2H) * t;
          final curOffset = offset2 + (offset1 - offset2) * t;
          children.add(
            Positioned(
              top: h - curH + curOffset,
              left: w - curW + curOffset,
              width: curW,
              height: curH,
              child: Opacity(
                opacity: opacity2 + (opacity1 - opacity2) * t,
                child: _ShadowCard(),
              ),
            ),
          );
        }

        // First shadow card.
        // Slides into the top card's position as top card leaves.
        if (remainingCards > 1) {
          final curW = shadow1W + (w - shadow1W) * t;
          final curH = shadow1H + (h - shadow1H) * t;
          final curOffset = offset1 * (1 - t);
          children.add(
            Positioned(
              top: h - curH + curOffset,
              left: w - curW + curOffset,
              width: curW,
              height: curH,
              child: Opacity(
                opacity: opacity1 + (1.0 - opacity1) * t,
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
      // Match Flutter Card's default 4px margin so the shadow
      // aligns exactly with the real card during promotion.
      margin: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusLg),
        border: Border.all(color: AppColors.outlineVariant, width: 1),
      ),
    );
  }
}
