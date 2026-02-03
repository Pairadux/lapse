import 'package:lapse/features/decks/domain/deck.dart';


abstract class DeckRepository {
  Future<List<Deck>> getAllDecks();
  Future<void> createDeck(Deck deck);
  Future<void> updateDeck(Deck deck);
  Future<void> deleteDeck(String deckId);
}
