import 'package:fsrs/fsrs.dart' as fsrs;
import '../domain/rating.dart';
import '../domain/review.dart';
import '../../cards/domain/flashcard.dart';

/// Result of processing a review with FSRS
class FsrsResult {
  final Flashcard updatedCard;
  final Review review;

  FsrsResult({required this.updatedCard, required this.review});
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

      // Helper to sanitize double values
      double safeDouble(double? value) {
        if (value == null || value.isNaN || value.isInfinite) return 0.0;
        return value;
      }

      // Calculate intervals for tracking
      int elapsedDays = 0;
      int scheduledDays = 0;
      if (card.lastReview != null) {
        elapsedDays = DateTime.now().difference(card.lastReview!).inDays;
      }

      // Safely compute scheduledDays — FSRS may produce extreme due dates for easy ratings on new cards
      final dueDiff = updatedFsrsCard.due.difference(DateTime.now()).inDays;
      scheduledDays = dueDiff.clamp(0, 36500); // Cap at ~100 years

      // Update card with FSRS results and tracking info
      final updatedCard = card.copyWith(
        dueDate: updatedFsrsCard.due,
        stability: safeDouble(updatedFsrsCard.stability),
        difficulty: safeDouble(updatedFsrsCard.difficulty),
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        cardState: _updateCardState(rating),
        reps: (card.reps) + 1,
        lapses: (rating == Rating.again) ? card.lapses + 1 : card.lapses,
        lastReview: DateTime.now(),
      );

      final review = Review(
        cardId: card.cardId,
        rating: rating,
        reviewedAt: DateTime.now(),
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        state: _updateCardState(rating),
      );

      return FsrsResult(updatedCard: updatedCard, review: review);
    } catch (e) {
      throw Exception('Failed to process review: $e');
    }
  }

  /// Convert Flashcard to fsrs Card (only relevant fields)
  /// For new cards (reps == 0), use FSRS library defaults to avoid NaN/Infinity errors
  fsrs.Card _toFsrsCard(Flashcard card) {
    if (card.reps == 0) {
      // New card — let FSRS use its own defaults
      return fsrs.Card(cardId: int.tryParse(card.cardId) ?? card.cardId.hashCode, due: card.dueDate);
    }
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
