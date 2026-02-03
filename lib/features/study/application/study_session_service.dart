import 'fsrs_service.dart';
import '../domain/rating.dart';
import '../domain/review.dart';
import '../domain/study_session.dart';
import '../../cards/domain/flashcard.dart';

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
  StudySession rateCard(StudySession session, Flashcard card, Rating rating) {
    /// Apply FSRS to update card scheduling
    _fsrsService.processReview(card, rating);

    /// Update rating counts
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

    /// Appends Review with updated results
    final review = Review(
      cardId: card.cardId,
      reviewedAt: DateTime.now(),
      rating: rating,
      scheduledDays: card.scheduledDays,
      elapsedDays: card.elapsedDays,
      state: card.cardState,
    );

    /// Creates a new list containing the existing review with the new ones
    final updatedCompletedReviews = List<Review>.from(session.completedReviews)..add(review);

    /// Return session with next card position and updated counts
    return StudySession(
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
  }
}
