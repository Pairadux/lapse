import 'package:uuid/uuid.dart';

class Deck {
  final String deckID;           // UUID, generated on creation
  String name;         // Deck title (required)
  // final String? description; // Optional description
  final DateTime createdAt;
  DateTime updatedAt;
  bool isDeleted;      // Soft delete for sync
  List<Flashcard> cards; // Cards in the deck

  // Denormalized counts (updated when cards change)
  int cardCount;       // Total cards in deck
  int dueCount;        // Cards due for review

  Deck(uuid.v4(), this.name, DateTime.now(), this.updatedAt, this.isDeleted, this.cards, this.cardCount
    , this.dueCount);
}