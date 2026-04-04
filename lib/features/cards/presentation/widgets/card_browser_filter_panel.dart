import 'package:flutter/material.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/cards/presentation/models/card_browser_filters.dart';

class CardBrowserFilterPanel extends StatelessWidget {
  final CardBrowserFilters filters;
  final ValueChanged<CardBrowserFilters> onFiltersChanged;

  const CardBrowserFilterPanel({
    super.key,
    required this.filters,
    required this.onFiltersChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(Spacing.md),
          bottomRight: Radius.circular(Spacing.md),
        ),
      ),
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sort dropdown
          Row(
            children: [
              const Text('Sort by:'),
              const Spacer(),
              DropdownButton<CardSortBy>(
                value: filters.sortBy,
                items: CardSortBy.values
                    .map((sort) => DropdownMenuItem(
                          value: sort,
                          child: Text(_sortLabel(sort)),
                        ))
                    .toList(),
                onChanged: (newSort) {
                  if (newSort != null) {
                    onFiltersChanged(filters.copyWith(sortBy: newSort));
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Sort order toggle
          Row(
            children: [
              const Text('Order:'),
              const Spacer(),
              IconButton(
                icon: Icon(
                  filters.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
                onPressed: () => onFiltersChanged(
                  filters.copyWith(sortAscending: !filters.sortAscending),
                ),
                tooltip: filters.sortAscending
                    ? 'Sort ascending'
                    : 'Sort descending',
              ),
            ],
          ),
          const SizedBox(height: Spacing.md),

          // Card state filter chips
          Text(
            'Card state:',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: Spacing.sm),
          Wrap(
            spacing: Spacing.sm,
            children: CardStateFilter.values
                .map((state) => FilterChip(
                      label: Text(_stateLabel(state)),
                      selected: filters.cardState == state,
                      onSelected: (_) =>
                          onFiltersChanged(filters.copyWith(cardState: state)),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  String _sortLabel(CardSortBy sort) {
    return switch (sort) {
      CardSortBy.dueDate => 'Due date',
      CardSortBy.difficulty => 'Difficulty',
      CardSortBy.created => 'Created',
      CardSortBy.reviewed => 'Last reviewed',
      CardSortBy.stability => 'Stability',
    };
  }

  String _stateLabel(CardStateFilter state) {
    return switch (state) {
      CardStateFilter.all => 'All',
      CardStateFilter.newCard => 'New',
      CardStateFilter.learning => 'Learning',
      CardStateFilter.review => 'Review',
      CardStateFilter.relearning => 'Relearning',
    };
  }
}