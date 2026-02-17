import 'package:lapse/features/cards/domain/flashcard.dart';

abstract class CardRepository {
  Future<List<Flashcard>> getByDeckId(String deckId);
  Future<List<Flashcard>> getDueCards(String deckId);
  Future<void> create(Flashcard card);
  Future<void> update(Flashcard card);
  Future<void> delete(String cardId);
}
