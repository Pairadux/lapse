import 'package:uuid/uuid.dart';

class Deck {
  final String deckID;           // UUID, generated on creation
  final String userId;       // Owner of the deck (from user.dart)
  final String name;         // Deck title (required)
  // final String? description; // Optional description
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;      // Soft delete for sync
  final List<Flashcard> cards; // Cards in the deck

  // Denormalized counts (updated when cards change)
  final int cardCount;       // Total cards in deck
  final int dueCount;        // Cards due for review

  const Deck(uuid.v4(), this,userId, this.name, DateTime.now(), this.updatedAt, this.isDeleted, this.cards, this.cardCount
    , this.dueCount);
}