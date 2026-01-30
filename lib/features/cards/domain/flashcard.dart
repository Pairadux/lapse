import 'package:uuid/uuid.dart';

class Flashcard {
  final String cardID;           // UUID
  final String deckId;       // Parent deck
  final String front;        // Question/prompt side
  final String back;         // Answer side
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;      // Soft delete for sync

  // FSRS scheduling state (managed by Study feature)
  final DateTime due;        // When next review is due
  final double stability;    // Memory stability (higher = longer intervals)
  final double difficulty;   // Card difficulty (1-10)
  final int elapsedDays;     // Days since last review
  final int scheduledDays;   // Interval from last review
  final int reps;            // Total review count
  final int lapses;          // Times forgotten (rated "Again")
  final DateTime? lastReview;

  enum CardState {newCard, learning, review, relearning}

  const Flashcard(uuid.v4(), this.deckId, this.front, this.back, this.createdAt, this.updatedAt, this.isDeleted, this.due,
    this.stability, this.elapsedDays, this.scheduledDays, this.reps, this.lapses this.lastReview, this.CardState);
}