import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';

final deckListProvider = AsyncNotifierProvider<DeckListNotifier, List<Deck>>(
  DeckListNotifier.new,
);

class DeckListNotifier extends AsyncNotifier<List<Deck>> {
  @override
  Future<List<Deck>> build() {
    return ref.read(deckRepositoryProvider).getAll();
  }

  Future<void> createDeck(Deck deck) async {
    state = await AsyncValue.guard<List<Deck>>(() async {
      await ref.read(deckRepositoryProvider).create(deck);
      return ref.read(deckRepositoryProvider).getAll();
    });
  }

  Future<void> updateDeck(Deck deck) async {
    state = await AsyncValue.guard<List<Deck>>(() async {
      await ref.read(deckRepositoryProvider).update(deck);
      return ref.read(deckRepositoryProvider).getAll();
    });
  }

  Future<void> deleteDeck(String deckId) async {
    state = await AsyncValue.guard<List<Deck>>(() async {
      await ref.read(deckRepositoryProvider).delete(deckId);
      return ref.read(deckRepositoryProvider).getAll();
    });
  }
}
