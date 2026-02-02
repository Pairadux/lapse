import 'package:equatable/equatable.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

class Deck extends Equatable {
  final String deckId; // UUID, generated on creation
  final String parentId; // ID of parent
  final String deckName; // Deck title (required)
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // Soft delete for sync
  final List<Flashcard> cards; // Cards in the deck
  // Denormalized counts (updated when cards change)
  final int cardCount; // Total cards in deck
  final int dueCount; // Cards due for review

  const Deck({
    required this.deckId,
    required this.parentId,
    required this.deckName,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.cards,
    required this.cardCount,
    required this.dueCount,
  });

  Deck copyWith({
    String? deckId,
    String? parentId,
    String? deckName,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<Flashcard>? cards,
    bool? isDeleted,
    int? cardCount,
    int? dueCount,
  }) {
    return Deck(
      deckId: deckId ?? this.deckId,
      parentId: parentId ?? this.parentId,
      deckName: deckName ?? this.deckName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      cards: cards ?? this.cards,
      cardCount: cardCount ?? this.cardCount,
      dueCount: dueCount ?? this.dueCount,
    );
  }

  @override
  // TODO: implement props
  List<Object?> get props => [deckId, parentId, deckName, createdAt, updatedAt, isDeleted, cards, cardCount, dueCount];
}
