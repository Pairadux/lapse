import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/presentation/models/card_browser_filters.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';

/// Returns all cards matching the given filters, sorted.
final filteredCardsProvider =
    FutureProvider.family<List<Flashcard>, CardBrowserFilters>((
  ref,
  filters,
) async {
  final cardRepo = ref.watch(cardRepositoryProvider);

  // Fetch cards: filter by deck (including nested children) or all
  final List<Flashcard> allCards;
  if (filters.selectedDeckId != null) {
    final deckRepo = ref.watch(deckRepositoryProvider);
    final deckIds = await deckRepo.getDescendantIds(filters.selectedDeckId!);
    allCards = await cardRepo.getByDeckIds(deckIds);
  } else {
    allCards = await cardRepo.getAllCards();
  }

  // Apply text filter (front/back search)
  var filtered = allCards;
  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    filtered =
        filtered
            .where(
              (card) =>
                  card.front.toLowerCase().contains(query) ||
                  card.back.toLowerCase().contains(query),
            )
            .toList();
  }

  // Apply card state filter
  if (filters.cardState != CardStateFilter.all) {
    filtered =
        filtered
            .where(
              (card) => _mapCardState(card.cardState) == filters.cardState,
            )
            .toList();
  }

  // Apply sorting
  filtered.sort((a, b) {
    int compare;
    switch (filters.sortBy) {
      case CardSortBy.dueDate:
        compare = a.dueDate.compareTo(b.dueDate);
      case CardSortBy.difficulty:
        compare = b.difficulty.compareTo(a.difficulty);
      case CardSortBy.created:
        compare = b.createdAt.compareTo(a.createdAt);
      case CardSortBy.reviewed:
        final aRev = a.lastReview ?? DateTime(1970);
        final bRev = b.lastReview ?? DateTime(1970);
        compare = bRev.compareTo(aRev);
      case CardSortBy.stability:
        compare = b.stability.compareTo(a.stability);
    }
    return filters.sortAscending ? compare : -compare;
  });

  return filtered;
});

/// Maps domain CardState to the filter enum.
CardStateFilter _mapCardState(CardState state) {
  switch (state) {
    case CardState.newCard:
      return CardStateFilter.newCard;
    case CardState.learning:
      return CardStateFilter.learning;
    case CardState.review:
      return CardStateFilter.review;
    case CardState.relearning:
      return CardStateFilter.relearning;
  }
}
