import 'package:equatable/equatable.dart';
import 'package:lapse/features/study/domain/rating.dart';

class Flashcard extends Equatable {
  final String cardId; // UUID
  final String deckId; // Parent deck
  final String front; // Question/prompt side
  final String back; // Answer side
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // Soft delete for sync

  // FSRS scheduling state (managed by Study feature)
  final DateTime dueDate; // When next review is due
  final double stability; // Memory stability (higher = longer intervals)
  final double difficulty; // Card difficulty (1-10)
  final int elapsedDays; // Days since last review
  final int scheduledDays; // Interval from last review
  final int reps; // Total review count
  final int lapses; // Times forgotten (rated "Again")
  final DateTime? lastReview;
  final int cardState;
  final Rating? rating;

  const Flashcard({
    required this.cardId,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    required this.dueDate,
    required this.stability,
    required this.difficulty,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.reps,
    required this.lapses,
    this.lastReview,
    required this.cardState,
    this.rating,
  });

  Flashcard copyWith({
    String? cardId,
    String? deckId,
    String? front,
    String? back,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    DateTime? dueDate,
    double? stability,
    double? difficulty,
    int? elapsedDays,
    int? scheduledDays,
    int? reps,
    int? lapses,
    DateTime? lastReview,
    int? cardState,
    Rating? rating,
  }) {
    return Flashcard(
      cardId: cardId ?? this.cardId,
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      dueDate: dueDate ?? this.dueDate,
      stability: stability ?? this.stability,
      difficulty: difficulty ?? this.difficulty,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      reps: reps ?? this.reps,
      lapses: lapses ?? this.lapses,
      lastReview: lastReview ?? this.lastReview,
      cardState: cardState ?? this.cardState,
      rating: rating ?? this.rating,
    );
  }

  @override
  // TODO: implement props
  List<Object?> get props => [
    cardId,
    deckId,
    front,
    back,
    createdAt,
    updatedAt,
    isDeleted,
    dueDate,
    stability,
    difficulty,
    elapsedDays,
    scheduledDays,
    reps,
    lapses,
    lastReview,
    cardState,
    rating,
  ];
}
