import 'package:fsrs/fsrs.dart' as fsrs;
import '../domain/rating.dart';
import '../../cards/domain/flashcard.dart';

/// Result of processing a review with FSRS
class FsrsResult {
  final Flashcard updatedCard;

  FsrsResult({required this.updatedCard});
}

class FsrsService {
  final fsrs.Scheduler _scheduler = fsrs.Scheduler();

  /// Process a review and return updated card state
  FsrsResult processReview(Flashcard card, Rating rating) {
    try {
      // Convert Flashcard to fsrs Card (only the fields FSRS cares about)
      final fsrsCard = _toFsrsCard(card);

      // Get scheduling result from FSRS
      final result = _scheduler.reviewCard(fsrsCard, _toFsrsRating(rating));
      final updatedFsrsCard = result.card;

      // Calculate intervals for tracking
      int elapsedDays = 0;
      int scheduledDays = 0;
      if (card.lastReview != null) {
        elapsedDays = DateTime.now().difference(card.lastReview!).inDays;
      }
      scheduledDays = updatedFsrsCard.due.difference(DateTime.now()).inDays;

      // Update card with FSRS results and tracking info

      Flashcard updatedCard = card.copyWith(
        dueDate: updatedFsrsCard.due,
        stability: updatedFsrsCard.stability ?? 0,
        difficulty: updatedFsrsCard.difficulty ?? 0,
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        cardState: _updateCardState(rating),
        reps: (card.reps) + 1,
        lapses: (rating == Rating.again) ? card.lapses + 1 : card.lapses,
        lastReview: DateTime.now(),
      );

      return FsrsResult(updatedCard: updatedCard);
    } catch (e) {
      throw Exception('Failed to process review: $e');
    }
  }

  /// Convert Flashcard to fsrs Card (only relevant fields)
  fsrs.Card _toFsrsCard(Flashcard card) {
    return fsrs.Card(
      cardId: int.tryParse(card.cardId) ?? card.cardId.hashCode,
      due: card.dueDate,
      stability: card.stability,
      difficulty: card.difficulty,
      lastReview: card.lastReview,
    );
  }

  /// Convert Rating enum to fsrs Rating
  fsrs.Rating _toFsrsRating(Rating appRating) {
    return switch (appRating) {
      Rating.again => fsrs.Rating.again,
      Rating.hard => fsrs.Rating.hard,
      Rating.good => fsrs.Rating.good,
      Rating.easy => fsrs.Rating.easy,
    };
  }

  /// Updates cardState based on rating
  CardState _updateCardState(Rating rating) {
    return switch (rating) {
      Rating.again => CardState.relearning,
      Rating.hard => CardState.learning,
      Rating.good => CardState.review,
      Rating.easy => CardState.review,
    };
  }
}
