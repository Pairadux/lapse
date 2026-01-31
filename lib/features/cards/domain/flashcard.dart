import 'package:uuid/uuid.dart';

class Flashcard {
  final String cardID;           // UUID
  String deckId;       // Parent deck
  String front;        // Question/prompt side
  String back;         // Answer side
  final DateTime createdAt;
  DateTime updatedAt;
  bool isDeleted;      // Soft delete for sync

  // FSRS scheduling state (managed by Study feature)
  DateTime dueDate;        // When next review is due
  double stability;    // Memory stability (higher = longer intervals)
  double difficulty;   // Card difficulty (1-10)
  int elapsedDays;     // Days since last review
  int scheduledDays;   // Interval from last review
  int reps;            // Total review count
  int lapses;          // Times forgotten (rated "Again")
  DateTime? lastReview;

  enum CardState {newCard, learning, review, relearning}

  Flashcard(uuid.v4(), this.deckId, this.front, this.back, this.createdAt, this.updatedAt, this.isDeleted, this.dueDate,
    this.stability, this.elapsedDays, this.scheduledDays, this.reps, this.lapses this.lastReview, this.CardState);
}