import 'fsrs_service.dart';
import '../domain/rating.dart';
import '../domain/review.dart';
import '../domain/study_session.dart';
import '../../cards/domain/flashcard.dart';

class StudySessionResult {
  final StudySession session;
  final Flashcard updatedCard;

  const StudySessionResult({required this.session, required this.updatedCard});
}

/// Manages study session flow and card rating
class StudySessionService {
  final FsrsService _fsrsService;

  StudySessionService({FsrsService? fsrsService}) : _fsrsService = fsrsService ?? FsrsService();

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

  /// Process card rating, update scheduling with FSRS, and advance session
  StudySessionResult rateCard(StudySession session, Flashcard card, Rating rating) {
    final fsrsResult = _fsrsService.processReview(card, rating);
    final updatedCard = fsrsResult.updatedCard;

    int againCount = session.againCount;
    int hardCount = session.hardCount;
    int goodCount = session.goodCount;
    int easyCount = session.easyCount;

    switch (rating) {
      case Rating.again:
        againCount++;
      case Rating.hard:
        hardCount++;
      case Rating.good:
        goodCount++;
      case Rating.easy:
        easyCount++;
    }

    final review = Review(
      cardId: updatedCard.cardId,
      reviewedAt: DateTime.now(),
      rating: rating,
      scheduledDays: updatedCard.scheduledDays,
      elapsedDays: updatedCard.elapsedDays,
      state: updatedCard.cardState,
    );

    final updatedCompletedReviews = List<Review>.from(session.completedReviews)..add(review);

    final updatedSession = StudySession(
      deckId: session.deckId,
      cards: session.cards,
      currentIndex: session.currentIndex + 1,
      completedReviews: updatedCompletedReviews,
      startedAt: session.startedAt,
      againCount: againCount,
      hardCount: hardCount,
      goodCount: goodCount,
      easyCount: easyCount,
    );

    return StudySessionResult(session: updatedSession, updatedCard: updatedCard);
  }
}
