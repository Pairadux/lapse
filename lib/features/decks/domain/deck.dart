class Deck {
  final String id;           // UUID, generated on creation
  final String userId;       // Owner of the deck
  final String name;         // Deck title (required)
  // final String? description; // Optional description
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;      // Soft delete for sync
  final List<Flashcard> cards; // Cards in the deck

  // Denormalized counts (updated when cards change)
  final int cardCount;       // Total cards in deck
  final int dueCount;        // Cards due for review
}