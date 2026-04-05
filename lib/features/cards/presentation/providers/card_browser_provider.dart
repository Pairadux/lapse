import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/presentation/models/card_browser_filters.dart';

/// Returns all cards matching the given filters, sorted, and paginated.
final filteredCardsProvider = FutureProvider.family<List<Flashcard>, CardBrowserFilters>((ref, filters) async {
  final cardRepo = ref.watch(cardRepositoryProvider);

  // Fetch all non-deleted cards (with nested if deck is selected)
  final allCards = filters.selectedDeckId != null
      ? await cardRepo.getByDeckIdWithNested(filters.selectedDeckId!)
      : await cardRepo.getAllCards();

  // Apply text filter (front/back search)
  var filtered = allCards;
  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    filtered = filtered
        .where((card) => card.front.toLowerCase().contains(query) || card.back.toLowerCase().contains(query))
        .toList();
  }

  // Apply card state filter
  if (filters.cardState != CardStateFilter.all) {
    filtered = filtered.where((card) => _mapCardState(card.cardState) == filters.cardState).toList();
  }

  // Apply sorting
  filtered.sort((a, b) {
    int compare = 0;
    switch (filters.sortBy) {
      case CardSortBy.dueDate:
        compare = a.dueDate.compareTo(b.dueDate);
        break;
      case CardSortBy.difficulty:
        compare = (b.difficulty).compareTo(a.difficulty);
        break;
      case CardSortBy.created:
        compare = (b.createdAt).compareTo(a.createdAt);
        break;
      case CardSortBy.reviewed:
        final aRev = a.lastReview ?? DateTime(1970);
        final bRev = b.lastReview ?? DateTime(1970);
        compare = bRev.compareTo(aRev);
        break;
      case CardSortBy.stability:
        // Stability: memory retention strength (higher = more stable/memorized)
        compare = (b.stability).compareTo(a.stability);
        break;
      case CardSortBy.deck:
        compare = a.deckId.compareTo(b.deckId);
        break;
    }
    return filters.sortAscending ? compare : -compare;
  });

  return filtered;
});

/// Returns the total count of cards matching the given filters.
final filteredCardsCountProvider = FutureProvider.family<int, CardBrowserFilters>((ref, filters) async {
  final cardRepo = ref.watch(cardRepositoryProvider);

  final allCards = filters.selectedDeckId != null
      ? await cardRepo.getByDeckIdWithNested(filters.selectedDeckId!)
      : await cardRepo.getAllCards();

  var filtered = allCards;
  if (filters.searchQuery.isNotEmpty) {
    final query = filters.searchQuery.toLowerCase();
    filtered = filtered
        .where((card) => card.front.toLowerCase().contains(query) || card.back.toLowerCase().contains(query))
        .toList();
  }

  if (filters.cardState != CardStateFilter.all) {
    filtered = filtered.where((card) => _mapCardState(card.cardState) == filters.cardState).toList();
  }

  return filtered.length;
});

// Helper to map FlashcardState to CardStateFilter for filtering.
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
