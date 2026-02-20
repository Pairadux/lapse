import 'package:equatable/equatable.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/core/database/database_constants.dart';

class Review extends Equatable {
  final String cardId;
  final DateTime reviewedAt;
  final Rating rating; // 1=Again, 2=Hard, 3=Good, 4=Easy
  final int scheduledDays; // Interval assigned after this review
  final int elapsedDays; // Days since previous review
  final CardState state; // State at time of review

  const Review({
    required this.cardId,
    required this.reviewedAt,
    required this.rating,
    required this.scheduledDays,
    required this.elapsedDays,
    required this.state,
  });

  Review copyWith({DateTime? reviewedAt, Rating? rating, int? scheduledDays, int? elapsedDays, CardState? state}) {
    return Review(
      cardId: cardId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      state: state ?? this.state,
    );
  }

  // Converts Review object into a Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colCardId: cardId,
      DatabaseConstants.colReviewedAt: reviewedAt.toIso8601String(),
      DatabaseConstants.colRating: rating.index,
      DatabaseConstants.colScheduledDays: scheduledDays,
      DatabaseConstants.colElapsedDays: elapsedDays,
      DatabaseConstants.colState: state.index,
    };
  }

  // Creates a Review object from Map retrieved for SQLite
  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      cardId: map[DatabaseConstants.colCardId] as String,
      reviewedAt: DateTime.parse(map[DatabaseConstants.colReviewedAt] as String),
      rating: Rating.values[map[DatabaseConstants.colRating] as int],
      scheduledDays: map[DatabaseConstants.colScheduledDays] as int,
      elapsedDays: map[DatabaseConstants.colElapsedDays] as int,
      state: CardState.values[map[DatabaseConstants.colState] as int],
    );
  }

  @override
  List<Object?> get props => [cardId, reviewedAt, rating, scheduledDays, elapsedDays, state];
}
