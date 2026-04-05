import 'package:copy_with_extension/copy_with_extension.dart';

part 'card_browser_filters.g.dart';

/// Sort options for the card browser.
enum CardSortBy { dueDate, difficulty, created, reviewed, stability, deck }

/// Filter by card state
enum CardStateFilter { all, newCard, learning, review, relearning }

///Immutable filter/sort state for card browser list
@CopyWith()
class CardBrowserFilters {
  /// Text search query (searches the front and back of cards)
  final String searchQuery;

  /// Filters cards by parent deck ID (single deck only). If null, shows cards from all decks.
  final String? selectedDeckId;

  /// Filter cards by card state (new, learning, review, etc.)
  final CardStateFilter cardState;

  /// Sort options for the card browser.
  final CardSortBy sortBy;

  /// Sort in ascending or descending order.
  final bool sortAscending;

  CardBrowserFilters({
    this.searchQuery = '',
    this.selectedDeckId,
    this.cardState = CardStateFilter.all,
    this.sortBy = CardSortBy.dueDate,
    this.sortAscending = true,
  });
}
