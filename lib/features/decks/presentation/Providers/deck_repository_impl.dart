import 'package:lapse/features/decks/domain/deck.dart';

import 'deck_repository.dart';

class LocalDeckRepository implements DeckRepository {
  LocalDeckRepository({List<Deck>? seedDecks})
      : _decks = List<Deck>.of(seedDecks ?? const []);

  final List<Deck> _decks;

  @override
  Future<List<Deck>> getAllDecks() async {
    return _decks.where((d) => !d.isDeleted).toList();
  }

  @override
  Future<void> createDeck(Deck deck) async {
    _decks.add(deck);
  }

  @override
  Future<void> updateDeck(Deck deck) async {
    final index = _decks.indexWhere((d) => d.deckID == deck.deckID);
    if (index != -1) _decks[index] = deck;
  }

  @override
  Future<void> deleteDeck(String deckId) async {
    final index = _decks.indexWhere((d) => d.deckID == deckId);
    if (index != -1) {
      _decks[index] = _decks[index].copyWith(isDeleted: true, deckName: '');
    }
  }
}
