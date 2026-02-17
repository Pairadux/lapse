import 'package:lapse/features/decks/domain/deck.dart';

abstract class DeckRepository {
  Future<List<Deck>> getAll();
  Future<void> create(Deck deck);
  Future<void> update(Deck deck);
  Future<void> delete(String deckId);
}
