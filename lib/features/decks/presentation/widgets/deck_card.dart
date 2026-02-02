import 'package:flutter/material.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/decks/domain/deck.dart';

class DeckCard extends StatelessWidget {
  final Deck deck;
  final bool hasChildren;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const DeckCard({
    super.key,
    required this.deck,
    required this.onTap,
    this.hasChildren = false,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: Spacing.cardMarginH,
        vertical: Spacing.cardMarginV,
      ),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(Spacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: Row(
            children: [
              _buildIcon(),
              const SizedBox(width: Spacing.lg),
              Expanded(child: _buildContent(context)),
              if (deck.dueCount > 0) _buildDueBadge(context),
              const SizedBox(width: Spacing.sm),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return Container(
      width: Spacing.iconContainerSize,
      height: Spacing.iconContainerSize,
      decoration: BoxDecoration(
        color: hasChildren
            ? AppColors.primaryDark.withValues(alpha: 0.2)
            : AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
      ),
      child: Icon(
        hasChildren ? Icons.folder : Icons.style,
        color: hasChildren ? AppColors.primary : AppColors.textSecondary,
        size: Spacing.iconSize,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          deck.deckName,
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          '${deck.cardCount} cards',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildDueBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
      ),
      child: Text(
        '${deck.dueCount} due',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
