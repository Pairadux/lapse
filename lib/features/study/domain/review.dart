import 'package:lapse/features/cards/domain/flashcard.dart';

class Review {
  final String cardID;
  DateTime reviewedAt;
  int rating; // 1=Again, 2=Hard, 3=Good, 4=Easy
  int scheduledDays; // Interval assigned after this review
  int elapsedDays; // Days since previous review
  CardState state; // State at time of review

  Review({
    required this.cardID,
    required this.reviewedAt,
    required this.rating,
    required this.scheduledDays,
    required this.elapsedDays,
    required this.state,
  });
}
