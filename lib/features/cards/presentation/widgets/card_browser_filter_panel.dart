import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/cards/presentation/models/card_browser_filters.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';

class CardBrowserFilterPanel extends ConsumerWidget {
  final CardBrowserFilters filters;
  final ValueChanged<CardBrowserFilters> onFiltersChanged;

  const CardBrowserFilterPanel({super.key, required this.filters, required this.onFiltersChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    final decksAsync = ref.watch(deckListProvider);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(Spacing.md),
          bottomRight: Radius.circular(Spacing.md),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sort By (Deck) - Always shown as dropdown
            Text('Sort By (Deck):', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.sm),
            decksAsync.when(
              loading: () => const SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
              error: (_, _) => const Text('Error loading decks'),
              data: (decks) {
                return DropdownButton<String?>(
                  value: filters.selectedDeckId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Decks')),
                    ...decks.map((deck) => DropdownMenuItem(value: deck.deck.deckId, child: Text(deck.deck.deckName))),
                  ],
                  onChanged: (newDeckId) {
                    onFiltersChanged(filters.copyWith(selectedDeckId: newDeckId));
                  },
                );
              },
            ),
            const SizedBox(height: Spacing.md),

            // Sort by: Dropdown on mobile, buttons on desktop
            if (isMobile) ...[
              Row(
                children: [
                  const Text('Sort by:'),
                  const Spacer(),
                  DropdownButton<CardSortBy>(
                    value: filters.sortBy,
                    items: CardSortBy.values
                        .where((sort) => sort != CardSortBy.deck)
                        .map((sort) => DropdownMenuItem(value: sort, child: Text(_sortLabel(sort))))
                        .toList(),
                    onChanged: (newSort) {
                      if (newSort != null) {
                        onFiltersChanged(filters.copyWith(sortBy: newSort));
                      }
                    },
                  ),
                ],
              ),
            ] else ...[
              Text('Sort by:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                alignment: WrapAlignment.start,
                children: CardSortBy.values
                    .where((sort) => sort != CardSortBy.deck)
                    .map(
                      (sort) => FilterChip(
                        label: Text(_sortLabel(sort)),
                        selected: filters.sortBy == sort,
                        onSelected: (_) => onFiltersChanged(filters.copyWith(sortBy: sort)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: Spacing.md),

            // Card state filter: Dropdown on mobile, chips on desktop
            if (isMobile) ...[
              Row(
                children: [
                  const Text('Card state:'),
                  const Spacer(),
                  DropdownButton<CardStateFilter>(
                    value: filters.cardState,
                    items: CardStateFilter.values
                        .map((state) => DropdownMenuItem(value: state, child: Text(_stateLabel(state))))
                        .toList(),
                    onChanged: (newState) {
                      if (newState != null) {
                        onFiltersChanged(filters.copyWith(cardState: newState));
                      }
                    },
                  ),
                ],
              ),
            ] else ...[
              Text('Card state:', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Spacing.sm),
              Wrap(
                spacing: Spacing.sm,
                alignment: WrapAlignment.start,
                children: CardStateFilter.values
                    .map(
                      (state) => FilterChip(
                        label: Text(_stateLabel(state)),
                        selected: filters.cardState == state,
                        onSelected: (_) => onFiltersChanged(filters.copyWith(cardState: state)),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: Spacing.md),

            // Sort order buttons (moved after Card State)
            Text('Order:', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              alignment: WrapAlignment.start,
              children: [
                FilterChip(
                  label: const Text('Ascending'),
                  selected: filters.sortAscending,
                  onSelected: (_) => onFiltersChanged(filters.copyWith(sortAscending: true)),
                ),
                FilterChip(
                  label: const Text('Descending'),
                  selected: !filters.sortAscending,
                  onSelected: (_) => onFiltersChanged(filters.copyWith(sortAscending: false)),
                ),
              ],
            ),
          ],
        ),
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
      CardSortBy.deck => 'Deck',
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
