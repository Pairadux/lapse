import 'fsrs_service.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/domain/review.dart';
import 'package:lapse/features/study/domain/study_session.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/study/data/review_repository.dart';

/// Manages study session flow and card rating
class StudySessionService {
  final FsrsService _fsrsService;
  final ReviewRepository _reviewRepository;
  final CardRepository _cardRepository;

  StudySessionService({
    FsrsService? fsrsService,
    required ReviewRepository reviewRepository,
    required CardRepository cardRepository,
  }) : _fsrsService = fsrsService ?? FsrsService(),
       _reviewRepository = reviewRepository,
       _cardRepository = cardRepository;

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
  Future<StudySession> rateCard(StudySession session, Flashcard card, Rating rating) async {
    try {
      /// Apply FSRS to update card scheduling
      final result = _fsrsService.processReview(card, rating);

      /// Appends Review with updated results
      final review = Review(
        cardId: card.cardId,
        reviewedAt: DateTime.now(),
        rating: rating,
        scheduledDays: result.updatedCard.scheduledDays,
        elapsedDays: result.updatedCard.elapsedDays,
        state: result.updatedCard.cardState,
      );

      // Saves history and card updates
      await Future.wait([_reviewRepository.addReview(review), _cardRepository.update(result.updatedCard)]);

      return _buildUpdatedSession(session, review, rating);
    } catch (e) {
      throw Exception('Review failed to process and save: $e');
    }
  }

  // Helper to construct the new StudySession state
  StudySession _buildUpdatedSession(StudySession session, Review review, Rating rating) {
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
