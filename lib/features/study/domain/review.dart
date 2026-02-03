import 'package:equatable/equatable.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/rating.dart';

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

  Review copyWith({
    String? cardId,
    DateTime? reviewedAt,
    Rating? rating,
    int? scheduledDays,
    int? elapsedDays,
    CardState? state,
  }) {
    return Review(
      cardId: cardId ?? this.cardId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      state: state ?? this.state,
    );
  }

  @override
  // TODO: implement props
  List<Object?> get props => [cardId, reviewedAt, rating, scheduledDays, elapsedDays, state];
}
