import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/presentation/providers/deck_detail_state.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';

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
      cardRepo.getByDeckId(deckId),
      deckRepo.getAggregatedCounts(deckId),
    ).wait;

    if (deck == null) throw DeckNotFoundException(deckId);

    return DeckDetailState(
      deck: deck,
      ancestors: ancestors,
      children: children,
      cards: cards,
      totalCardCount: counts.cardCount,
      totalDueCount: counts.dueCount,
    );
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
