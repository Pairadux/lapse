import 'package:lapse/features/study/application/fsrs_service.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/domain/review.dart';
import 'package:lapse/features/study/domain/study_session.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

/// Manages study session flow and card rating
class StudySessionService {
  final FsrsService _fsrsService;

  StudySessionService({FsrsService? fsrsService})
    : _fsrsService = fsrsService ?? FsrsService();

  /// Initialize a new study session
  StudySession startSession(String deckId, List<Flashcard> cards) {
    return StudySession(
      deckId: deckId,
      cards: cards,
      currentIndex: 0,
      completedReviews: [],
      startedAt: DateTime.now(),
      againCount: 0,
      hardCount: 0,
      goodCount: 0,
      easyCount: 0,
    );
  }

  /// Process card rating, update scheduling with FSRS, and advance session.
  /// Learning/relearning cards are re-queued at the end of the session.
  StudySessionResult rateCard(
    StudySession session,
    Flashcard card,
    Rating rating,
  ) {
    try {
      final result = _fsrsService.processReview(card, rating);

      return StudySessionResult(
        session: _buildUpdatedSession(
          session,
          result.review,
          rating,
          result.updatedCard,
        ),
        updatedCard: result.updatedCard,
        review: result.review,
      );
    } catch (e) {
      throw Exception('Review failed to process: $e');
    }
  }

  StudySession _buildUpdatedSession(
    StudySession session,
    Review review,
    Rating rating,
    Flashcard updatedCard,
  ) {
    int againCount = session.againCount;
    int hardCount = session.hardCount;
    int goodCount = session.goodCount;
    int easyCount = session.easyCount;

    switch (rating) {
      case Rating.again:
        againCount++;
        break;
      case Rating.hard:
        hardCount++;
        break;
      case Rating.good:
        goodCount++;
        break;
      case Rating.easy:
        easyCount++;
        break;
    }

    final updatedCompletedReviews = List<Review>.from(session.completedReviews)
      ..add(review);

    // Re-queue learning/relearning cards at the end so they reappear this session
    final updatedCards = List<Flashcard>.from(session.cards);
    final stillLearning =
        updatedCard.cardState == CardState.learning ||
        updatedCard.cardState == CardState.relearning;
    if (stillLearning) {
      updatedCards.add(updatedCard);
    }

    return StudySession(
      deckId: session.deckId,
      cards: updatedCards,
      currentIndex: session.currentIndex + 1,
      completedReviews: updatedCompletedReviews,
      startedAt: session.startedAt,
      againCount: againCount,
      hardCount: hardCount,
      goodCount: goodCount,
      easyCount: easyCount,
    );
  }
}

class StudySessionResult {
  final StudySession session;
  final Flashcard updatedCard;
  final Review review;

  StudySessionResult({
    required this.session,
    required this.updatedCard,
    required this.review,
  });
}
