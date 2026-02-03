import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/deck.dart';
import '../../data/deck_repository.dart';

// StateNotifier to manage list of decks
final deckListProvider = StateNotifierProvider<DeckListNotifier, List<Deck>>(
  (ref) => DeckListNotifier(ref.read as Reader),
);

class DeckListNotifier extends StateNotifier<List<Deck>> {
  final Reader read;

  DeckListNotifier(this.read) : super([]) {
    loadDecks();
  }

  // Load decks from repository
  Future<void> loadDecks() async {
    final decks = await read.getAllDecks();
    state = decks.where((d) => !d.isDeleted).toList(); // ignore soft-deleted
  }

  // Refresh decks manually
  Future<void> refreshDecks() async {
    await loadDecks();
  }

  // Add a new deck
  Future<void> addDeck(Deck deck) async {
    await read.createDeck(deck);
    state = [...state, deck]; // add to current state
  }

  // Update existing deck
  Future<void> updateDeck(Deck deck) async {
    await read.updateDeck(deck);
    state = [
      for (final d in state)
        if (d.deckID == deck.deckID) deck else d,
    ];
  }

  // Soft delete deck
  Future<void> deleteDeck(String deckId) async {
    await read.deleteDeck(deckId);
    state = state.where((d) => d.deckID != deckId).toList();
  }
}

class Reader {
  Future<void> deleteDeck(String deckId) async {}

  Future<void> updateDeck(Deck deck) async {}

  Future<void> createDeck(Deck deck) async {}

  Future<dynamic> getAllDecks() async {}
}
