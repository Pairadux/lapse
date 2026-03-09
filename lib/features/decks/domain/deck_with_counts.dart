import 'package:equatable/equatable.dart';
import 'package:lapse/features/decks/domain/deck.dart';

/// A deck paired with its aggregated card and due counts
/// (including all descendant decks).
class DeckWithCounts extends Equatable {
  final Deck deck;
  final int cardCount;
  final int dueCount;

  const DeckWithCounts({
    required this.deck,
    required this.cardCount,
    required this.dueCount,
  });

  @override
  List<Object?> get props => [deck, cardCount, dueCount];
}
