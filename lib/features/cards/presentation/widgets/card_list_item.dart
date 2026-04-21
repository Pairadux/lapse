import 'package:flutter/material.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

class CardListItem extends StatelessWidget {
  final Flashcard card;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const CardListItem({
    super.key,
    required this.card,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDue = card.dueDate.isBefore(DateTime.now());

    final (String title, String? subtitle) = switch (card) {
      TwoSidedCard c => (c.front, c.back),
      ReverseCard c => (c.front, c.back),
      ClozeCard c => (c.front, null),
    };

    return ListTile(
      onTap: onTap,
      onLongPress: onLongPress,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Spacing.md,
        vertical: Spacing.sm,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: subtitle != null ? Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ) : null,
        trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isDue)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(Spacing.radiusXs),
              ),
              child: Text(
                'Due',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.textOnPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          if (isDue) const SizedBox(width: Spacing.sm),
          const Icon(Icons.chevron_right, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
