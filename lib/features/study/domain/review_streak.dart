import 'package:equatable/equatable.dart';

class ReviewStreak extends Equatable {
  final int currentStreak;
  final int longestStreak;
  final String? lastCompletedDate; // YYYY-MM-DD

  const ReviewStreak({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletedDate,
  });

  const ReviewStreak.empty()
    : currentStreak = 0,
      longestStreak = 0,
      lastCompletedDate = null;

  @override
  List<Object?> get props => [currentStreak, longestStreak, lastCompletedDate];
}
