import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';
import 'package:lapse/features/study/application/study_session_service.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/domain/study_session.dart';

final studySessionProvider =
    AsyncNotifierProvider.autoDispose<StudySessionNotifier, StudySession?>(
      StudySessionNotifier.new,
    );

final currentStudyCardProvider = Provider.autoDispose<Flashcard?>((ref) {
  final session = ref.watch(studySessionProvider).asData?.value;
  return session?.currentCard;
});

class StudySessionNotifier extends AsyncNotifier<StudySession?> {
  late final StudySessionService _service;

  @override
  Future<StudySession?> build() async {
    _service = StudySessionService();
    return null;
  }

  Future<void> startSession(List<String> deckIds) async {
    if (deckIds.isEmpty) {
      state = const AsyncData(null);
      return;
    }

    state = const AsyncLoading<StudySession?>();
    state = await AsyncValue.guard<StudySession?>(() async {
      final allCards = <Flashcard>[];
      for (final deckId in deckIds) {
        final cards = await ref
            .read(cardRepositoryProvider)
            .getDueCards(deckId);
        allCards.addAll(cards);
      }

      final sessionDeckId = deckIds.length == 1
          ? deckIds.first
          : 'multi:${deckIds.join(",")}';
      final session = _service.startSession(sessionDeckId, allCards);
      return session;
    });
  }

  Future<void> rateCurrentCard(Rating rating) async {
    final session = state.asData?.value;
    final card = session?.currentCard;
    if (session == null || card == null) return;

    state = await AsyncValue.guard<StudySession?>(() async {
      final result = _service.rateCard(session, card, rating);
      await ref.read(cardRepositoryProvider).update(result.updatedCard);
      ref.invalidate(deckListProvider);
      return result.session;
    });
  }

  void endSession() {
    state = const AsyncData(null);
  }
}
