import 'package:equatable/equatable.dart';

/// Sort options for the card browser.
enum CardSortBy {
  dueDate,
  difficulty,
  created,
  reviewed,
  stability;

  String get label => switch (this) {
    CardSortBy.dueDate => 'Due date',
    CardSortBy.difficulty => 'Difficulty',
    CardSortBy.created => 'Created',
    CardSortBy.reviewed => 'Last reviewed',
    CardSortBy.stability => 'Stability',
  };
}

/// Filter by card state.
enum CardStateFilter {
  all,
  newCard,
  learning,
  review,
  relearning;

  String get label => switch (this) {
    CardStateFilter.all => 'All',
    CardStateFilter.newCard => 'New',
    CardStateFilter.learning => 'Learning',
    CardStateFilter.review => 'Review',
    CardStateFilter.relearning => 'Relearning',
  };
}

/// Immutable filter/sort state for card browser list.
class CardBrowserFilters extends Equatable {
  /// Text search query (searches the front and back of cards).
  final String searchQuery;

  /// Filters cards by parent deck ID (single deck only). If null, shows cards from all decks.
  final String? selectedDeckId;

  /// Filter cards by card state (new, learning, review, etc.).
  final CardStateFilter cardState;

  /// Sort field for the card browser.
  final CardSortBy sortBy;

  /// Sort in ascending or descending order.
  final bool sortAscending;

  const CardBrowserFilters({
    this.searchQuery = '',
    this.selectedDeckId,
    this.cardState = CardStateFilter.all,
    this.sortBy = CardSortBy.dueDate,
    this.sortAscending = true,
  });

  @override
  List<Object?> get props => [
    searchQuery,
    selectedDeckId,
    cardState,
    sortBy,
    sortAscending,
  ];

  CardBrowserFilters copyWith({
    String? searchQuery,
    String? Function()? selectedDeckId,
    CardStateFilter? cardState,
    CardSortBy? sortBy,
    bool? sortAscending,
  }) {
    return CardBrowserFilters(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDeckId: selectedDeckId != null
          ? selectedDeckId()
          : this.selectedDeckId,
      cardState: cardState ?? this.cardState,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }
}
