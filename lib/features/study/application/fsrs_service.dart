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
      final fsrsCard = _toFsrsCard(card);
      final result = _scheduler.reviewCard(fsrsCard, _toFsrsRating(rating));
      final updatedFsrsCard = result.card;
      final now = DateTime.now();

      double safeDouble(double? value) {
        if (value == null || value.isNaN || value.isInfinite) return 0.0;
        return value;
      }

      final elapsedDays = card.lastReview != null
          ? now.difference(card.lastReview!).inDays
          : 0;

      // Cap at ~100 years — FSRS can produce extreme due dates for easy ratings on new cards
      final scheduledDays = updatedFsrsCard.due
          .difference(now)
          .inDays
          .clamp(0, 36500);

      final newState = _fromFsrsState(updatedFsrsCard.state);

      final updatedCard = card.copyWith(
        dueDate: updatedFsrsCard.due,
        stability: safeDouble(updatedFsrsCard.stability),
        difficulty: safeDouble(updatedFsrsCard.difficulty),
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        cardState: newState,
        step: updatedFsrsCard.step,
        reps: card.reps + 1,
        lapses: (rating == Rating.again) ? card.lapses + 1 : card.lapses,
        lastReview: now,
      );

      final review = Review(
        cardId: card.cardId,
        rating: rating,
        reviewedAt: now,
        elapsedDays: elapsedDays,
        scheduledDays: scheduledDays,
        state: newState,
      );

      return FsrsResult(updatedCard: updatedCard, review: review);
    } catch (e) {
      throw Exception('Failed to process review: $e');
    }
  }

  /// Convert Flashcard to fsrs Card, passing state and step for non-new cards
  /// so FSRS knows where the card is in the learning sequence.
  fsrs.Card _toFsrsCard(Flashcard card) {
    final cardId = int.tryParse(card.cardId) ?? card.cardId.hashCode;

    if (card.cardState == CardState.newCard) {
      return fsrs.Card(cardId: cardId, due: card.dueDate);
    }

    return fsrs.Card(
      cardId: cardId,
      due: card.dueDate,
      state: _toFsrsState(card.cardState),
      step: card.step,
      stability: card.stability,
      difficulty: card.difficulty,
      lastReview: card.lastReview,
    );
  }

  fsrs.Rating _toFsrsRating(Rating appRating) {
    return switch (appRating) {
      Rating.again => fsrs.Rating.again,
      Rating.hard => fsrs.Rating.hard,
      Rating.good => fsrs.Rating.good,
      Rating.easy => fsrs.Rating.easy,
    };
  }

  fsrs.State _toFsrsState(CardState appState) {
    return switch (appState) {
      CardState.newCard => fsrs.State.learning,
      CardState.learning => fsrs.State.learning,
      CardState.review => fsrs.State.review,
      CardState.relearning => fsrs.State.relearning,
    };
  }

  CardState _fromFsrsState(fsrs.State fsrsState) {
    return switch (fsrsState) {
      fsrs.State.learning => CardState.learning,
      fsrs.State.review => CardState.review,
      fsrs.State.relearning => CardState.relearning,
    };
  }
}
