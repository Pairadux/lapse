import 'fsrs_service.dart';
import '../domain/rating.dart';
import '../domain/study_session.dart';
import '../../cards/domain/flashcard.dart';

/// Manages study session flow and card rating
class StudySessionService {
  final FsrsService _fsrsService = FsrsService();

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
    // Apply FSRS to update card scheduling
    _fsrsService.processReview(card, rating);

    // Update rating counts
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

    // Return session with next card position and updated counts
    return StudySession(
      deckId: session.deckId,
      cards: session.cards,
      currentIndex: session.currentIndex + 1,
      completedReviews: session.completedReviews,
      startedAt: session.startedAt,
      againCount: againCount,
      hardCount: hardCount,
      goodCount: goodCount,
      easyCount: easyCount,
    );
  }
}
