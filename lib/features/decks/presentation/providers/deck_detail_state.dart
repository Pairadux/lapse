import 'package:equatable/equatable.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/domain/deck_with_counts.dart';

/// Composite state for [DeckDetailScreen]: the current deck, its ancestor
/// chain, child decks with aggregated counts, direct cards, and totals
/// across the full subtree.
class DeckDetailState extends Equatable {
  final Deck deck;
  final List<Deck> ancestors;
  final List<DeckWithCounts> children;
  final List<Flashcard> cards;
  final int totalCardCount;
  final int totalDueCount;

  const DeckDetailState({
    required this.deck,
    required this.ancestors,
    required this.children,
    required this.cards,
    required this.totalCardCount,
    required this.totalDueCount,
  });

  @override
  List<Object?> get props => [
    deck,
    ancestors,
    children,
    cards,
    totalCardCount,
    totalDueCount,
  ];
}

/// Thrown when a deck ID resolves to null (deleted or never existed).
class DeckNotFoundException implements Exception {
  final String deckId;
  const DeckNotFoundException(this.deckId);

  @override
  String toString() => 'Deck not found: $deckId';
}
