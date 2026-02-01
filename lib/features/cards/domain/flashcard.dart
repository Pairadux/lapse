enum CardState { newCard, learning, review, relearning }

class Flashcard {
  final String cardID; // UUID
  String deckId; // Parent deck
  String front; // Question/prompt side
  String back; // Answer side
  final DateTime createdAt;
  DateTime updatedAt;
  bool isDeleted; // Soft delete for sync

  // FSRS scheduling state (managed by Study feature)
  DateTime dueDate; // When next review is due
  double stability; // Memory stability (higher = longer intervals)
  double difficulty; // Card difficulty (1-10)
  int elapsedDays; // Days since last review
  int scheduledDays; // Interval from last review
  int reps; // Total review count
  int lapses; // Times forgotten (rated "Again")
  DateTime? lastReview;
  CardState cardState;

  Flashcard({
    required this.cardID,
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
  });
}
