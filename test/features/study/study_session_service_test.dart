import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/features/study/application/study_session_service.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/domain/study_session.dart';

void main() {
  group('StudySessionResult', () {
    test('packages updated card, review, and session', () {
      // Arrange: create a sample card, session, and rating
      final card = Flashcard(
        cardId: 'test-id',
        front: 'Front',
        back: 'Back',
        deckId: 'deck-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        isDeleted: false,
        dueDate: DateTime.now(),
        stability: 0.0,
        difficulty: 0.0,
        elapsedDays: 0,
        scheduledDays: 0,
        reps: 0,
        lapses: 0,
        lastReview: null,
        cardState: CardState.newCard,
      );

      final session = StudySession(
        deckId: 'deck-1',
        cards: [card],
        currentIndex: 0,
        completedReviews: [],
        startedAt: DateTime.now(),
        againCount: 0,
        hardCount: 0,
        goodCount: 0,
        easyCount: 0,
      );

      final rating = Rating.good;
      final service = StudySessionService();

      final result = service.rateCard(session, card, rating);

      expect(result.updatedCard, isNotNull);
      expect(result.updatedCard.cardId, equals(card.cardId));
      expect(result.updatedCard.reps, greaterThan(card.reps));
      expect(result.updatedCard.cardState, equals(CardState.review));

      expect(result.review, isNotNull);
      expect(result.review.cardId, equals(card.cardId));
      expect(result.review.rating, equals(rating));
      expect(result.review.reviewedAt.isAfter(card.updatedAt), isTrue);

      expect(result.session, isNotNull);
      expect(result.session.deckId, equals(session.deckId));
      expect(result.session.currentIndex, equals(session.currentIndex + 1));
      expect(result.session.completedReviews.length, equals(session.completedReviews.length + 1));
      expect(result.session.goodCount, equals(session.goodCount + 1));
      // TODO: Add more specific field checks as needed
    });
  });
}
