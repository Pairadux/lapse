import 'package:lapse/features/cards/domain/flashcard.dart';

class Deck {
  final String deckID; // UUID, generated on creation
  final String parentID; // ID of parent
  String deckName; // Deck title (required)
  // final String? description; // Optional description
  final DateTime createdAt;
  DateTime updatedAt;
  bool isDeleted; // Soft delete for sync
  List<Flashcard> cards; // Cards in the deck

  // Denormalized counts (updated when cards change)
  int cardCount; // Total cards in deck
  int dueCount; // Cards due for review

  Deck({
    required this.deckID,
    required this.parentID,
    required this.deckName,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.cards,
    required this.cardCount,
    required this.dueCount,
  });

  Deck copyWith({
    String? deckID,
    String? parentID,
    String? deckName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    List<Flashcard>? cards,
    int? cardCount,
    int? dueCount,
  }) {
    return Deck(
      deckID: deckID ?? this.deckID,
      parentID: parentID ?? this.parentID,
      deckName: deckName ?? this.deckName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      cards: cards ?? this.cards,
      cardCount: cardCount ?? this.cardCount,
      dueCount: dueCount ?? this.dueCount,
    );
  }
}
