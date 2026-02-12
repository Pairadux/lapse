import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';

final deckListProvider = AsyncNotifierProvider<DeckListNotifier, List<Deck>>(
  DeckListNotifier.new,
);

class DeckListNotifier extends AsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() {
    return ref.read(deckRepositoryProvider).getAllDecks();
  }

  Future<void> createDeck(Deck deck) async {
    state = const AsyncLoading<List<Deck>>();
    state = await AsyncValue.guard<List<Deck>>(() async {
      await ref.read(deckRepositoryProvider).createDeck(deck);
      return ref.read(deckRepositoryProvider).getAllDecks();
    });
  }

  Future<void> updateDeck(Deck deck) async {
    state = const AsyncLoading<List<Deck>>();
    state = await AsyncValue.guard<List<Deck>>(() async {
      await ref.read(deckRepositoryProvider).updateDeck(deck);
      return ref.read(deckRepositoryProvider).getAllDecks();
    });
  }

  Future<void> deleteDeck(String deckId) async {
    state = const AsyncLoading<List<Deck>>();
    state = await AsyncValue.guard<List<Deck>>(() async {
      await ref.read(deckRepositoryProvider).deleteDeck(deckId);
      return ref.read(deckRepositoryProvider).getAllDecks();
    });
  }
}
