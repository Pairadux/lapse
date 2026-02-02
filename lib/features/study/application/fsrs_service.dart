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
      card.dueDate = updatedFsrsCard.due;
      card.stability = updatedFsrsCard.stability ?? 0;
      card.difficulty = updatedFsrsCard.difficulty ?? 0;
      card.elapsedDays = elapsedDays;
      card.scheduledDays = scheduledDays;
      card.reps = (card.reps) + 1;
      if (rating == Rating.again) {
        card.lapses = (card.lapses) + 1;
      }
      card.lastReview = DateTime.now();

      return FsrsResult(updatedCard: card);
    } catch (e) {
      throw Exception('Failed to process review: $e');
    }
  }

  /// Convert Flashcard to fsrs Card (only relevant fields)
  fsrs.Card _toFsrsCard(Flashcard card) {
    return fsrs.Card(
      cardId: int.tryParse(card.cardID) ?? card.cardID.hashCode,
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
}
