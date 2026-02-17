import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';

final cardListProvider = AsyncNotifierProvider.family<
    CardListNotifier, List<Flashcard>, String>(
  (deckId) => CardListNotifier(deckId),
);

class CardListNotifier extends AsyncNotifier<List<Flashcard>> {
  CardListNotifier(this._deckId);

  final String _deckId;

  @override
  Future<List<Flashcard>> build() {
    return ref.read(cardRepositoryProvider).getByDeckId(_deckId);
  }

  Future<void> createCard(Flashcard card) async {
    state = const AsyncLoading<List<Flashcard>>();
    state = await AsyncValue.guard<List<Flashcard>>(() async {
      await ref.read(cardRepositoryProvider).create(card);
      ref.invalidate(deckListProvider);
      return ref.read(cardRepositoryProvider).getByDeckId(_deckId);
    });
  }

  Future<void> updateCard(Flashcard card) async {
    state = const AsyncLoading<List<Flashcard>>();
    state = await AsyncValue.guard<List<Flashcard>>(() async {
      await ref.read(cardRepositoryProvider).update(card);
      ref.invalidate(deckListProvider);
      return ref.read(cardRepositoryProvider).getByDeckId(_deckId);
    });
  }

  Future<void> deleteCard(String cardId) async {
    state = const AsyncLoading<List<Flashcard>>();
    state = await AsyncValue.guard<List<Flashcard>>(() async {
      await ref.read(cardRepositoryProvider).delete(cardId);
      ref.invalidate(deckListProvider);
      return ref.read(cardRepositoryProvider).getByDeckId(_deckId);
    });
  }
}
