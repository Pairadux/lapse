import 'package:lapse/features/cards/domain/flashcard.dart';

import 'card_repository.dart';

class LocalCardRepository implements CardRepository {
  LocalCardRepository({List<Flashcard>? seedCards})
      : _cards = List<Flashcard>.of(seedCards ?? const []);

  final List<Flashcard> _cards;

  @override
  Future<List<Flashcard>> getCardsForDeck(String deckId) async {
    return _cards
        .where((c) => c.deckId == deckId && !c.isDeleted)
        .toList();
  }

  @override
  Future<void> createCard(Flashcard card) async {
    _cards.add(card);
  }

  @override
  Future<void> updateCard(Flashcard card) async {
    final index = _cards.indexWhere((c) => c.cardID == card.cardID);
    if (index != -1) {
      _cards[index] = card;
    }
  }

  @override
  Future<void> deleteCard(String cardId) async {
    final index = _cards.indexWhere((c) => c.cardID == cardId);
    if (index != -1) {
      _cards[index].isDeleted = true;
      _cards[index].updatedAt = DateTime.now();
    }
  }
}
