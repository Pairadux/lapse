import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/empty_state_widget.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/presentation/models/card_browser_filters.dart';
import 'package:lapse/features/cards/presentation/providers/card_browser_provider.dart';
import 'package:lapse/features/cards/presentation/widgets/card_browser_filter_panel.dart';
import 'package:lapse/features/cards/presentation/widgets/card_list_item.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';

class CardBrowserScreen extends ConsumerStatefulWidget {
  const CardBrowserScreen({super.key});

  @override
  ConsumerState<CardBrowserScreen> createState() => _CardBrowserScreenState();
}

class _CardBrowserScreenState extends ConsumerState<CardBrowserScreen> {
  final _searchController = TextEditingController();
  bool _showFilters = false;

  late CardBrowserFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = const CardBrowserFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateFilters(CardBrowserFilters newFilters) {
    setState(() {
      _filters = newFilters;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filteredCards = ref.watch(filteredCardsProvider(_filters));
    final decksAsync = ref.watch(deckListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('All Cards')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(Spacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cards...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _updateFilters(
                            _filters.copyWith(searchQuery: ''),
                          );
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Spacing.radiusSm),
                ),
              ),
              onChanged: (value) {
                _updateFilters(_filters.copyWith(searchQuery: value));
              },
            ),
          ),

          // Filter toggle + card count with summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: filteredCards.when(
                    data: (cards) {
                      final summary = decksAsync.when(
                        loading: () => _buildFilterSummary(null),
                        error: (_, _) => _buildFilterSummary(null),
                        data: (decks) {
                          String? deckName;
                          if (_filters.selectedDeckId != null) {
                            deckName = decks
                                .firstWhere(
                                  (d) =>
                                      d.deck.deckId ==
                                      _filters.selectedDeckId,
                                  orElse: () => decks.first,
                                )
                                .deck
                                .deckName;
                          }
                          return _buildFilterSummary(deckName);
                        },
                      );
                      final suffix =
                          summary.isNotEmpty ? ' ($summary)' : '';
                      return Text(
                        '${cards.length} cards$suffix',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                    loading: () => Text(
                      '... cards',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    error: (_, _) => Text(
                      '0 cards',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sort/Filter',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    IconButton(
                      icon: Icon(
                        _showFilters
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      onPressed: () =>
                          setState(() => _showFilters = !_showFilters),
                      tooltip: 'Toggle filters',
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Filter panel (collapsible)
          if (_showFilters)
            CardBrowserFilterPanel(
              filters: _filters,
              onFiltersChanged: _updateFilters,
            ),

          // Cards list
          Expanded(
            child: filteredCards.when(
              loading: () => const Center(child: LoadingIndicator()),
              error: (error, st) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.lg),
                  child: Text('Error: $error'),
                ),
              ),
              data: (cards) {
                if (cards.isEmpty) {
                  return Center(
                    child: EmptyStateWidget(
                      icon: Icons.style_outlined,
                      title: 'No cards found',
                      subtitle: _buildEmptySubtitle(),
                      actionLabel: 'Clear filters',
                      onAction: () {
                        _searchController.clear();
                        _updateFilters(const CardBrowserFilters());
                      },
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(
                    bottom: Spacing.sm + 80,
                  ),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return CardListItem(
                      card: card,
                      onTap: () {
                        context.push(
                          Routes.cardPath(card.deckId, card.cardId),
                          extra: card,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _buildEmptySubtitle() {
    if (_filters.searchQuery.isNotEmpty) {
      return 'Try adjusting your search query';
    }
    if (_filters.selectedDeckId != null) {
      return 'This deck has no cards';
    }
    if (_filters.cardState != CardStateFilter.all) {
      return 'No cards in this state';
    }
    return 'Create your first deck to get started';
  }

  String _buildFilterSummary(String? deckName) {
    final parts = <String>[];

    if (_filters.selectedDeckId != null && deckName != null) {
      parts.add(deckName);
    } else if (_filters.selectedDeckId == null) {
      parts.add('All Decks');
    }

    if (_filters.sortBy != CardSortBy.dueDate) {
      parts.add(_filters.sortBy.label);
    }

    if (_filters.cardState != CardStateFilter.all) {
      parts.add(_filters.cardState.label);
    }

    if (_filters.sortBy != CardSortBy.dueDate) {
      parts.add(_filters.sortAscending ? 'ascending' : 'descending');
    } else if (!_filters.sortAscending) {
      parts.add('descending');
    }

    return parts.join(', ');
  }
}
