import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/presentation/Providers/deck_repository_provider.dart';

import 'card_repository_provider.dart';

final cardListProvider = StateNotifierProvider.family<
    CardListNotifier, AsyncValue<List<Flashcard>>, String>(
  (ref, deckId) => CardListNotifier(ref, deckId),
);

class CardListNotifier extends StateNotifier<AsyncValue<List<Flashcard>>> {
  CardListNotifier(this._ref, this._deckId) : super(const AsyncLoading()) {
    _loadCards();
  }

  final Ref _ref;
  final String _deckId;

  Future<void> _loadCards() async {
    state = await AsyncValue.guard(
      () => _ref.read(cardRepositoryProvider).getCardsForDeck(_deckId),
    );
  }

  Future<void> createCard(Flashcard card) async {
    state = const AsyncLoading();
    await _ref.read(cardRepositoryProvider).createCard(card);
    await _syncDeckCounts(card.deckId);
    await _loadCards();
  }

  Future<void> updateCard(Flashcard updatedCard) async {
    state = const AsyncLoading();
    await _ref.read(cardRepositoryProvider).updateCard(updatedCard);
    await _syncDeckCounts(updatedCard.deckId);
    await _loadCards();
  }

  Future<void> deleteCard(String cardId) async {
    state = const AsyncLoading();
    await _ref.read(cardRepositoryProvider).deleteCard(cardId);
    await _syncDeckCounts(_deckId);
    await _loadCards();
  }

  Future<void> _syncDeckCounts(String deckId) async {
    final cards = await _ref.read(cardRepositoryProvider).getCardsForDeck(deckId);
    final deckList = await _ref.read(deckRepositoryProvider).getAllDecks();
    final index = deckList.indexWhere((d) => d.deckID == deckId);
    if (index == -1) return;

    final updatedDeck = deckList[index].copyWith(
      cardCount: cards.length,
      dueCount: _calculateDueCount(cards),
      updatedAt: DateTime.now(),
    );
    await _ref.read(deckRepositoryProvider).updateDeck(updatedDeck);
  }

  int _calculateDueCount(List<Flashcard> cards) {
    final now = DateTime.now();
    return cards.where((card) => !card.dueDate.isAfter(now)).length;
  }
}
