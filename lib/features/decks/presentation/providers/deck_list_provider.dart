import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/domain/deck_with_counts.dart';

final deckListProvider =
    AsyncNotifierProvider<DeckListNotifier, List<DeckWithCounts>>(
  DeckListNotifier.new,
);

class DeckListNotifier extends AsyncNotifier<List<DeckWithCounts>> {
  @override
  Future<List<DeckWithCounts>> build() {
    final repo = ref.watch(deckRepositoryProvider);
    return repo.getDecksWithCounts();
  }

  Future<void> createDeck(Deck deck) async {
    final repo = ref.read(deckRepositoryProvider);
    await repo.create(deck);
    ref.invalidateSelf();
  }

  Future<void> updateDeck(Deck deck) async {
    final repo = ref.read(deckRepositoryProvider);
    await repo.update(deck);
    ref.invalidateSelf();
  }

  Future<void> deleteDeck(String deckId) async {
    final repo = ref.read(deckRepositoryProvider);
    await repo.delete(deckId);
    ref.invalidateSelf();
  }
}
