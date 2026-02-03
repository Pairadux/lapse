import 'package:equatable/equatable.dart';

enum CardState { newCard, learning, review, relearning }

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
  final CardState cardState;

  const Flashcard({
    required this.cardId,
    required this.deckId,
    required this.front,
    required this.back,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    required this.dueDate,
    required this.stability,
    required this.difficulty,
    required this.elapsedDays,
    required this.scheduledDays,
    required this.reps,
    required this.lapses,
    this.lastReview,
    required this.cardState,
  });

  Flashcard copyWith({
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
    CardState? cardState,
  }) {
    return Flashcard(
      cardId: cardId, // cardId cannot be changed
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
    );
  }

  @override
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
  ];
}
