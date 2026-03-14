import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/study/application/fsrs_service.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

void main() {
  late FsrsService fsrsService;

  setUp(() {
    fsrsService = FsrsService();
  });

  /// Factory to create a test card with sensible defaults
  Flashcard makeTestCard({
    String id = 'test-card',
    String deckId = 'test-deck',
    CardState state = CardState.newCard,
    double? stability,
    double? difficulty,
    int? step,
    DateTime? lastReview,
    int reps = 0,
    int lapses = 0,
  }) {
    final now = DateTime.now();
    return Flashcard(
      cardId: id,
      deckId: deckId,
      front: 'Q',
      back: 'A',
      createdAt: now,
      updatedAt: now,
      dueDate: now,
      stability: stability ?? 0.0,
      difficulty: difficulty ?? 0.0,
      elapsedDays: 0,
      scheduledDays: 0,
      cardState: state,
      step: step,
      reps: reps,
      lapses: lapses,
      lastReview: lastReview,
    );
  }

  group('FsrsService - Rating Paths', () {
    test('new card rated Good progresses to learning step 1', () {
      final card = makeTestCard();
      final result = fsrsService.processReview(card, Rating.good);

      expect(result.updatedCard.cardState, CardState.learning);
      expect(result.updatedCard.reps, 1);
      expect(result.updatedCard.lapses, 0);
      expect(result.updatedCard.stability, greaterThan(0));
      expect(result.updatedCard.difficulty, greaterThan(0));
    });

    test('new card rated Easy has longer initial interval than Good', () {
      final card = makeTestCard();

      final resultGood = fsrsService.processReview(card, Rating.good);
      final easyCard = makeTestCard();
      final resultEasy = fsrsService.processReview(easyCard, Rating.easy);

      expect(
        resultEasy.updatedCard.dueDate.difference(resultEasy.updatedCard.lastReview!).inDays,
        greaterThan(
          resultGood.updatedCard.dueDate.difference(resultGood.updatedCard.lastReview!).inDays,
        ),
      );
    });

    test('new card rated Hard has shorter interval than Good', () {
      final card = makeTestCard();

      final resultGood = fsrsService.processReview(card, Rating.good);
      final hardCard = makeTestCard();
      final resultHard = fsrsService.processReview(hardCard, Rating.hard);

      final intervalGood = resultGood.updatedCard.dueDate.difference(resultGood.updatedCard.lastReview!).inMinutes;
      final intervalHard = resultHard.updatedCard.dueDate.difference(resultHard.updatedCard.lastReview!).inMinutes;
      expect(intervalHard, lessThan(intervalGood));
    });

    test('new card rated Again triggers learning state', () {
      final card = makeTestCard();
      final result = fsrsService.processReview(card, Rating.again);

      expect(result.updatedCard.cardState, CardState.learning);
      expect(result.updatedCard.reps, 1);
      expect(result.updatedCard.lapses, 1);
    });
  });

  group('FsrsService - State Transitions', () {
    test('new card → learning after first review', () {
      final card = makeTestCard(state: CardState.newCard);
      final result = fsrsService.processReview(card, Rating.good);

      expect(result.updatedCard.cardState, CardState.learning);
    });

    test('learning card → review after graduation (2nd good review)', () {
      // Simulate: new → learning (Good) → review (Good)
      var card = makeTestCard(state: CardState.newCard);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.cardState, CardState.learning);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.cardState, CardState.review);
    });
    test('review card → relearning when rated Again', () {
      var card = makeTestCard(
        state: CardState.review,
        stability: 15.0,
        difficulty: 5.0,
        lastReview: DateTime.now().subtract(const Duration(days: 10)),
      );

      final result = fsrsService.processReview(card, Rating.again);
      expect(result.updatedCard.cardState, CardState.relearning);
      expect(result.review.rating, Rating.again);
    });

    test('relearning card → review after good rating', () {
      var card = makeTestCard(
        state: CardState.relearning,
        stability: 8.0,
        difficulty: 6.0,
        step: 0,
      );

      final result = fsrsService.processReview(card, Rating.good);
      expect(result.updatedCard.cardState, CardState.review);
    });
  });

  group('FsrsService - Stability & Difficulty Updates', () {
    test('stability increases when card is rated positively', () {
      final card = makeTestCard(
        state: CardState.review,
        stability: 10.0,
        difficulty: 5.0,
      );

      final resultGood = fsrsService.processReview(card, Rating.good);
      final resultEasy = fsrsService.processReview(card, Rating.easy);

      expect(resultGood.updatedCard.stability, greaterThan(card.stability));
      expect(resultEasy.updatedCard.stability, greaterThan(resultGood.updatedCard.stability));
    });

    test('stability decreases when card is rated Again', () {
      final card = makeTestCard(
        state: CardState.review,
        stability: 15.0,
        difficulty: 5.0,
      );

      final result = fsrsService.processReview(card, Rating.again);
      expect(result.updatedCard.stability, lessThan(card.stability));
    });

    test('difficulty increases when card is rated Again', () {
      final card = makeTestCard(
        state: CardState.review,
        stability: 10.0,
        difficulty: 5.0,
      );

      final result = fsrsService.processReview(card, Rating.again);
      expect(result.updatedCard.difficulty, greaterThan(card.difficulty));
    });

    test('difficulty decreases when card is rated Easy', () {
      final card = makeTestCard(
        state: CardState.review,
        stability: 10.0,
        difficulty: 5.0,
      );

      final result = fsrsService.processReview(card, Rating.easy);
      expect(result.updatedCard.difficulty, lessThan(card.difficulty));
    });
  });

  group('FsrsService - Interval Calculations', () {
    test('interval increases with stability', () {
      // Low stability
      final lowStability = makeTestCard(
        state: CardState.review,
        stability: 3.0,
        difficulty: 5.0,
      );

      // High stability
      final highStability = makeTestCard(
        state: CardState.review,
        stability: 30.0,
        difficulty: 5.0,
      );

      final resultLow = fsrsService.processReview(lowStability, Rating.good);
      final resultHigh = fsrsService.processReview(highStability, Rating.good);

      final intervalLow = resultLow.updatedCard.scheduledDays;
      final intervalHigh = resultHigh.updatedCard.scheduledDays;

      expect(intervalHigh, greaterThan(intervalLow));
    });

    test('first review interval is minimal (learning steps)', () {
      final card = makeTestCard(state: CardState.newCard);
      final result = fsrsService.processReview(card, Rating.good);

      // First learning step should be minutes, not days
      final intervalDays = result.updatedCard.scheduledDays;
      expect(intervalDays, lessThan(1));
    });

    test('review rating Good produces longer interval than Hard', () {
      final hardCard = makeTestCard(state: CardState.review, stability: 10.0, difficulty: 5.0);
      final goodCard = makeTestCard(state: CardState.review, stability: 10.0, difficulty: 5.0);

      final resultHard = fsrsService.processReview(hardCard, Rating.hard);
      final resultGood = fsrsService.processReview(goodCard, Rating.good);

      expect(resultGood.updatedCard.scheduledDays, greaterThan(resultHard.updatedCard.scheduledDays));
    });
  });

  group('FsrsService - Review Counts', () {
    test('reps increments with each review', () {
      var card = makeTestCard(reps: 0);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.reps, 1);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.reps, 2);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.reps, 3);
    });

    test('lapses increments only on Again rating', () {
      var card = makeTestCard(lapses: 0, state: CardState.review, stability: 10.0, difficulty: 5.0);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.lapses, 0);

      card = fsrsService.processReview(card, Rating.again).updatedCard;
      expect(card.lapses, 1);

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      expect(card.lapses, 1); // No increment on Good
    });

    test('lapses accumulate with multiple Again ratings', () {
      var card = makeTestCard(lapses: 0, state: CardState.review, stability: 10.0, difficulty: 5.0);

      card = fsrsService.processReview(card, Rating.again).updatedCard;
      expect(card.lapses, 1);

      card = fsrsService.processReview(card, Rating.again).updatedCard;
      expect(card.lapses, 2);
    });
  });

  group('FsrsService - Edge Cases', () {
    test('first review on completely new card initializes FSRS state', () {
      final card = makeTestCard(
        state: CardState.newCard,
        stability: 0,
        difficulty: 0,
        lastReview: null,
      );

      final result = fsrsService.processReview(card, Rating.good);
      final updated = result.updatedCard;

      expect(updated.stability, greaterThan(0));
      expect(updated.difficulty, greaterThan(0));
      expect(updated.lastReview, isNotNull);
      expect(updated.dueDate.isAfter(DateTime.now()), isTrue);
    });

    test('re-lapsed card (forgotten and back in review) updates correctly', () {
      // Simulate: was in review, forgot (lapsed), back in review after relearning
      var card = makeTestCard(
        state: CardState.review,
        stability: 20.0,
        difficulty: 5.0,
        lapses: 1,
        lastReview: DateTime.now().subtract(const Duration(days: 15)),
      );

      // Rate it good after re-entering review
      final result = fsrsService.processReview(card, Rating.good);
      expect(result.updatedCard.cardState, CardState.review);
      expect(result.updatedCard.reps, card.reps + 1);
      expect(result.updatedCard.lapses, 1); // Lapses unchanged
    });

    test('rapid successive reviews update correctly', () {
      var card = makeTestCard(state: CardState.review, stability: 10.0, difficulty: 5.0);

      // Three reviews in a row
      card = fsrsService.processReview(card, Rating.good).updatedCard;
      final stability1 = card.stability;

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      final stability2 = card.stability;

      card = fsrsService.processReview(card, Rating.good).updatedCard;
      final stability3 = card.stability;

      // Each should increase or plateau, but not decrease
      expect(stability1, greaterThanOrEqualTo(10.0));
      expect(stability2, greaterThanOrEqualTo(stability1));
      expect(stability3, greaterThanOrEqualTo(stability2));
      expect(stability3, lessThan(stability2 * 1.5)); // Sanity check: not too high
    });

    test('processReview handles null lastReview gracefully', () {
      final card = makeTestCard(
        state: CardState.newCard,
        lastReview: null,
      );

      final result = fsrsService.processReview(card, Rating.good);
      expect(result.updatedCard.lastReview, isNotNull);
      expect(result.review.elapsedDays, 0);
    });

    test('extreme ratings (easy on hard card) produce sensible results', () {
      final hardCard = makeTestCard(
        state: CardState.review,
        stability: 2.0,
        difficulty: 9.0,
      );

      final result = fsrsService.processReview(hardCard, Rating.easy);
      expect(result.updatedCard.stability, greaterThan(0));
      expect(result.updatedCard.difficulty, greaterThan(0));
      expect(result.updatedCard.difficulty, lessThan(9.0)); // Difficulty decreases on Easy
    });
  });

  group('FsrsResult', () {
    test('result contains updated card and review record', () {
      final card = makeTestCard();
      final result = fsrsService.processReview(card, Rating.good);

      expect(result.updatedCard, isNotNull);
      expect(result.review, isNotNull);
      expect(result.updatedCard.cardId, card.cardId);
      expect(result.review.cardId, card.cardId);
    });

    test('review record captures rating and state', () {
      final card = makeTestCard(state: CardState.review, stability: 10.0, difficulty: 5.0);
      final result = fsrsService.processReview(card, Rating.easy);

      expect(result.review.rating, Rating.easy);
      expect(result.review.state, CardState.review);
      expect(result.review.reviewedAt, isNotNull);
    });
  });
}