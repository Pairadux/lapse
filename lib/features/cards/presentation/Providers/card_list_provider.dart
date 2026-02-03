import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/presentation/Providers/deck_repository_provider.dart';

import 'card_repository_provider.dart';

final cardListProvider =
    AsyncNotifierProviderFamily<CardListNotifier, List<Flashcard>, String>(
  CardListNotifier.new,
);

class CardListNotifier extends AsyncNotifier<List<Flashcard>> {
  late final _cardRepository = ref.read(cardRepositoryProvider);
  late final _deckRepository = ref.read(deckRepositoryProvider);
  late final String _deckId;

  @override
  Future<List<Flashcard>> build(String deckId) async {
    _deckId = deckId;
    return _cardRepository.getCardsForDeck(deckId);
  }

  Future<void> createCard(Flashcard card) async {
    state = const AsyncLoading<List<Flashcard>>().copyWithPrevious(state);
    await _cardRepository.createCard(card);
    await _syncDeckCounts(card.deckId);
    state = await AsyncValue.guard(() => _cardRepository.getCardsForDeck(_deckId));
  }

  Future<void> updateCard(Flashcard updatedCard) async {
    state = const AsyncLoading<List<Flashcard>>().copyWithPrevious(state);
    await _cardRepository.updateCard(updatedCard);
    await _syncDeckCounts(updatedCard.deckId);
    state = await AsyncValue.guard(() => _cardRepository.getCardsForDeck(_deckId));
  }

  Future<void> deleteCard(String cardId) async {
    state = const AsyncLoading<List<Flashcard>>().copyWithPrevious(state);
    await _cardRepository.deleteCard(cardId);
    await _syncDeckCounts(_deckId);
    state = await AsyncValue.guard(() => _cardRepository.getCardsForDeck(_deckId));
  }

  Future<void> _syncDeckCounts(String deckId) async {
    final cards = await _cardRepository.getCardsForDeck(deckId);
    final deckList = await _deckRepository.getAllDecks();
    final deckMatches = deckList.where((d) => d.deckID == deckId).toList();
    if (deckMatches.isEmpty) return;

    final dueCount = _calculateDueCount(cards);
    final updated = deckMatches.first.copyWith(
      cardCount: cards.length,
      dueCount: dueCount,
      updatedAt: DateTime.now(),
    );
    await _deckRepository.updateDeck(updated);
  }

  int _calculateDueCount(List<Flashcard> cards) {
    final now = DateTime.now();
    return cards.where((c) => !c.dueDate.isAfter(now)).length;
  }
}
