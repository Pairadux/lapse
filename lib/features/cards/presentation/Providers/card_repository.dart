import 'package:lapse/features/cards/domain/flashcard.dart';

abstract class CardRepository {
  Future<List<Flashcard>> getCardsForDeck(String deckId);
  Future<void> createCard(Flashcard card);
  Future<void> updateCard(Flashcard card);
  Future<void> deleteCard(String cardId);
}
