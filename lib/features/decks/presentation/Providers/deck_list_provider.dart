import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'deck_repository_provider.dart';

/*
  Deck list state powered by a repository.
*/
final deckListProvider =
    AsyncNotifierProvider<DeckListNotifier, List<Deck>>(
  DeckListNotifier.new,
);

class DeckListNotifier extends AsyncNotifier<List<Deck>> {
  late final _repository = ref.read(deckRepositoryProvider);

  @override
  Future<List<Deck>> build() async {
    return _repository.getAllDecks();
  }

  Future<void> createDeck(Deck deck) async {
    state = const AsyncLoading<List<Deck>>().copyWithPrevious(state);
    await _repository.createDeck(deck);
    state = await AsyncValue.guard(_repository.getAllDecks);
  }

  Future<void> updateDeck(Deck updatedDeck) async {
    state = const AsyncLoading<List<Deck>>().copyWithPrevious(state);
    await _repository.updateDeck(updatedDeck);
    state = await AsyncValue.guard(_repository.getAllDecks);
  }

  Future<void> deleteDeck(String deckId) async {
    state = const AsyncLoading<List<Deck>>().copyWithPrevious(state);
    await _repository.deleteDeck(deckId);
    state = await AsyncValue.guard(_repository.getAllDecks);
  }
}
