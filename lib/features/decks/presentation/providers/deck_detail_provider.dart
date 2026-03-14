import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/presentation/providers/deck_detail_state.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';

const int _cardPageSize = 50;

final deckDetailProvider =
    AsyncNotifierProvider.family<DeckDetailNotifier, DeckDetailState, String>(
  (arg) => DeckDetailNotifier(arg),
);

class DeckDetailNotifier extends AsyncNotifier<DeckDetailState> {
  DeckDetailNotifier(this.deckId);
  final String deckId;

  @override
  Future<DeckDetailState> build() async {
    final deckRepo = ref.watch(deckRepositoryProvider);
    final cardRepo = ref.watch(cardRepositoryProvider);

    final (deck, ancestors, children, cards, counts) = await (
      deckRepo.getById(deckId),
      deckRepo.getAncestors(deckId),
      deckRepo.getDecksWithCounts(parentId: deckId),
      cardRepo.getByDeckId(deckId, limit: _cardPageSize, offset: 0),
      deckRepo.getAggregatedCounts(deckId),
    ).wait;

    if (deck == null) throw DeckNotFoundException(deckId);

    return DeckDetailState(
      deck: deck,
      ancestors: ancestors,
      children: children,
      cards: cards,
      hasMoreCards: cards.length == _cardPageSize,
      isLoadingMoreCards: false,
      totalCardCount: counts.cardCount,
      totalDueCount: counts.dueCount,
    );
  }

  Future<void> loadMoreCards() async {
    final current = state.asData?.value;
    if (current == null ||
        current.isLoadingMoreCards ||
        !current.hasMoreCards) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMoreCards: true));

    try {
      final cardRepo = ref.read(cardRepositoryProvider);
      // Offset pagination can skip one item if mid-list mutations occur.
      // Acceptable for now; keyset pagination is more robust if needed.
      final nextCards = await cardRepo.getByDeckId(
        deckId,
        limit: _cardPageSize,
        offset: current.cards.length,
      );

      if (nextCards.isEmpty) {
        state = AsyncData(
          current.copyWith(
            hasMoreCards: false,
            isLoadingMoreCards: false,
          ),
        );
        return;
      }

      state = AsyncData(
        current.copyWith(
          cards: [...current.cards, ...nextCards],
          hasMoreCards: nextCards.length == _cardPageSize,
          isLoadingMoreCards: false,
        ),
      );
    } catch (_) {
      state = AsyncData(current.copyWith(isLoadingMoreCards: false));
      rethrow;
    }
  }

  Future<void> deleteChildDeck(String childDeckId) async {
    await ref.read(deckRepositoryProvider).delete(childDeckId);
    ref.invalidateSelf();
    ref.invalidate(deckListProvider);
  }

  Future<void> deleteCard(String cardId) async {
    await ref.read(cardRepositoryProvider).delete(cardId);
    ref.invalidateSelf();
    ref.invalidate(deckListProvider);
  }
}
