import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';
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
    // Rebuild when a sync cycle completes so remote changes appear.
    // Local changes are already handled by invalidateSelf() and didPopNext().
    ref.watch(syncServiceProvider.select((s) => s.lastSyncTime));

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
      // Offset pagination can skip/duplicate items if mid-list mutations
      // shift rows. Acceptable for now; keyset pagination is more robust
      // if this becomes a problem.
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
    }
  }

  Future<void> deleteChildDeck(String childDeckId) async {
    await ref.read(deckRepositoryProvider).delete(childDeckId);
    ref.invalidateSelf();
    ref.invalidate(deckListProvider);
  }

  Future<void> moveChildDeck(String childDeckId, String? newParentId) async {
    final deckRepo = ref.read(deckRepositoryProvider);
    final deck = await deckRepo.getById(childDeckId);
    if (deck == null) return;

    await deckRepo.update(
      deck.copyWith(parentId: Optional.value(newParentId)),
    );
    ref.invalidateSelf();
    if (newParentId != null) {
      ref.invalidate(deckDetailProvider(newParentId));
    }
    ref.invalidate(deckListProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
  }

  Future<void> moveCard(String cardId, String newDeckId) async {
    final cardRepo = ref.read(cardRepositoryProvider);
    final card = await cardRepo.getById(cardId);
    if (card == null) return;

    await cardRepo.update(card.copyWith(deckId: newDeckId));
    ref.invalidateSelf();
    ref.invalidate(deckListProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
  }

  Future<void> deleteCard(String cardId) async {
    await ref.read(cardRepositoryProvider).delete(cardId);
    ref.invalidate(deckListProvider);

    final current = state.asData?.value;
    if (current == null) return;

    final cardIndex = current.cards.indexWhere((c) => c.cardId == cardId);
    if (cardIndex == -1) return;

    final deletedCard = current.cards[cardIndex];
    final updatedCards = [...current.cards]..removeAt(cardIndex);
    final now = DateTime.now();
    final wasDue = !deletedCard.dueDate.isAfter(now);

    state = AsyncData(
      current.copyWith(
        cards: updatedCards,
        totalCardCount: current.totalCardCount > 0
            ? current.totalCardCount - 1
            : 0,
        totalDueCount: wasDue && current.totalDueCount > 0
            ? current.totalDueCount - 1
            : current.totalDueCount,
      ),
    );
  }
}
