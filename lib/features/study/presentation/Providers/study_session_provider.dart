import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/presentation/Providers/card_repository_provider.dart';
import 'package:lapse/features/study/domain/rating.dart';

final studySessionProvider =
    StateNotifierProvider.autoDispose<StudySessionNotifier, AsyncValue<StudySessionState>>(
  (ref) => StudySessionNotifier(ref),
);

final currentStudyCardProvider = Provider.autoDispose<Flashcard?>((ref) {
  final state = ref.watch(studySessionProvider);
  return state.asData?.value.currentCard;
});

class StudySessionState {
  const StudySessionState({
    required this.cards,
    required this.currentIndex,
    required this.showingAnswer,
    required this.ratingCounts,
  });

  final List<Flashcard> cards;
  final int currentIndex;
  final bool showingAnswer;
  final Map<Rating, int> ratingCounts;

  bool get isComplete => currentIndex >= cards.length;
  Flashcard? get currentCard => isComplete ? null : cards[currentIndex];
  int get totalReviewed => ratingCounts.values.fold(0, (a, b) => a + b);
  double get progress => cards.isEmpty ? 0.0 : (currentIndex / cards.length);

  StudySessionState copyWith({
    List<Flashcard>? cards,
    int? currentIndex,
    bool? showingAnswer,
    Map<Rating, int>? ratingCounts,
  }) {
    return StudySessionState(
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      showingAnswer: showingAnswer ?? this.showingAnswer,
      ratingCounts: ratingCounts ?? this.ratingCounts,
    );
  }
}

class StudySessionNotifier extends StateNotifier<AsyncValue<StudySessionState>> {
  StudySessionNotifier(this._ref) : super(const AsyncLoading());

  final Ref _ref;

  Future<void> startSession(List<String> deckIds) async {
    if (deckIds.isEmpty) {
      state = AsyncData(
        StudySessionState(
          cards: const [],
          currentIndex: 0,
          showingAnswer: false,
          ratingCounts: _emptyRatingCounts(),
        ),
      );
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final allCards = <Flashcard>[];
      for (final deckId in deckIds) {
        final cards = await _ref.read(cardRepositoryProvider).getCardsForDeck(deckId);
        allCards.addAll(cards);
      }

      return StudySessionState(
        cards: allCards,
        currentIndex: 0,
        showingAnswer: false,
        ratingCounts: _emptyRatingCounts(),
      );
    });
  }

  void revealAnswer() {
    final current = state.asData?.value;
    if (current == null || current.isComplete || current.showingAnswer) return;
    state = AsyncData(current.copyWith(showingAnswer: true));
  }

  Future<void> rateCurrentCard(Rating rating) async {
    final current = state.asData?.value;
    final card = current?.currentCard;
    if (current == null || card == null || !current.showingAnswer) return;

    final updatedCounts = Map<Rating, int>.from(current.ratingCounts);
    updatedCounts[rating] = (updatedCounts[rating] ?? 0) + 1;

    final updatedCard = _applyBasicScheduling(card, rating);
    await _ref.read(cardRepositoryProvider).updateCard(updatedCard);

    state = AsyncData(
      current.copyWith(
        currentIndex: current.currentIndex + 1,
        showingAnswer: false,
        ratingCounts: updatedCounts,
      ),
    );
  }

  void endSession() {
    state = const AsyncLoading();
  }

  static Map<Rating, int> _emptyRatingCounts() {
    return {
      Rating.again: 0,
      Rating.hard: 0,
      Rating.good: 0,
      Rating.easy: 0,
    };
  }

  Flashcard _applyBasicScheduling(Flashcard card, Rating rating) {
    final now = DateTime.now();
    final updated = Flashcard(
      cardID: card.cardID,
      deckId: card.deckId,
      front: card.front,
      back: card.back,
      createdAt: card.createdAt,
      updatedAt: now,
      isDeleted: card.isDeleted,
      dueDate: _nextDueDate(now, rating),
      stability: card.stability,
      difficulty: card.difficulty,
      elapsedDays: card.elapsedDays,
      scheduledDays: _scheduledDays(rating),
      reps: card.reps + 1,
      lapses: rating == Rating.again ? card.lapses + 1 : card.lapses,
      lastReview: now,
      cardState: rating == Rating.again ? CardState.learning : CardState.review,
    );
    return updated;
  }

  DateTime _nextDueDate(DateTime from, Rating rating) {
    switch (rating) {
      case Rating.again:
        return from.add(const Duration(minutes: 10));
      case Rating.hard:
        return from.add(const Duration(days: 1));
      case Rating.good:
        return from.add(const Duration(days: 3));
      case Rating.easy:
        return from.add(const Duration(days: 7));
    }
  }

  int _scheduledDays(Rating rating) {
    switch (rating) {
      case Rating.again:
        return 0;
      case Rating.hard:
        return 1;
      case Rating.good:
        return 3;
      case Rating.easy:
        return 7;
    }
  }
}
