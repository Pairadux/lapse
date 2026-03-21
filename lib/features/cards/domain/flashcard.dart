import 'package:equatable/equatable.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:uuid/uuid.dart';
import 'package:lapse/core/database/database_constants.dart';

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
  final int? step; // Learning step progress (null for new/review cards, 0+ for learning/relearning)
  final SyncStatus syncStatus; // Synced, pending, conflict
  final String userId; // For multi-user support (optional)

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
    this.step,
    this.syncStatus = SyncStatus.synced,
    this.userId = '',
  });

  /// Creates a new card with auto-generated ID, timestamps, and FSRS defaults.
  factory Flashcard.newCard({required String deckId, required String front, required String back}) {
    final now = DateTime.now();
    return Flashcard(
      cardId: const Uuid().v4(),
      deckId: deckId,
      front: front,
      back: back,
      dueDate: now,
      stability: 0.0,
      difficulty: 0.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      cardState: CardState.newCard,
      createdAt: now,
      updatedAt: now,
      syncStatus: SyncStatus.synced,
      userId: '',
    );
  }

  // Sentinel to distinguish "not provided" from "set to null" for nullable int fields.
  static const int _stepUnset = -1;

  Flashcard copyWith({
    String? deckId,
    String? front,
    String? back,
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
    int? step = _stepUnset,
    String? userId,
    SyncStatus? syncStatus,
  }) {
    return Flashcard(
      cardId: cardId, // cardId cannot be changed
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
      createdAt: createdAt, // immutable — set at creation
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
      step: step == _stepUnset ? this.step : step,
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Serializes to a DB-ready column map.
  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colCardId: cardId,
      DatabaseConstants.colDeckId: deckId,
      DatabaseConstants.colFront: front,
      DatabaseConstants.colBack: back,
      DatabaseConstants.colCreatedAt: createdAt.toUtc().toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt.toUtc().toIso8601String(),
      DatabaseConstants.colIsDeleted: isDeleted ? 1 : 0,
      DatabaseConstants.colDueDate: dueDate.toUtc().toIso8601String(),
      DatabaseConstants.colStability: stability,
      DatabaseConstants.colDifficulty: difficulty,
      DatabaseConstants.colElapsedDays: elapsedDays,
      DatabaseConstants.colScheduledDays: scheduledDays,
      DatabaseConstants.colReps: reps,
      DatabaseConstants.colLapses: lapses,
      DatabaseConstants.colLastReview: lastReview?.toUtc().toIso8601String(),
      DatabaseConstants.colCardState: cardState.index,
      DatabaseConstants.colStep: step,
      DatabaseConstants.colUserId: userId,
      DatabaseConstants.colSyncStatus: syncStatus.name,
    };
  }

  /// Deserializes from a DB column map.
  factory Flashcard.fromMap(Map<String, dynamic> map) {
    final lastReviewStr = map[DatabaseConstants.colLastReview] as String?;
    return Flashcard(
      cardId: map[DatabaseConstants.colCardId] as String,
      deckId: map[DatabaseConstants.colDeckId] as String,
      front: map[DatabaseConstants.colFront] as String,
      back: map[DatabaseConstants.colBack] as String,
      createdAt: DateTime.parse(map[DatabaseConstants.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[DatabaseConstants.colUpdatedAt] as String),
      isDeleted: map[DatabaseConstants.colIsDeleted] == 1,
      dueDate: DateTime.parse(map[DatabaseConstants.colDueDate] as String),
      stability: (map[DatabaseConstants.colStability] as num).toDouble(),
      difficulty: (map[DatabaseConstants.colDifficulty] as num).toDouble(),
      elapsedDays: map[DatabaseConstants.colElapsedDays] as int,
      scheduledDays: map[DatabaseConstants.colScheduledDays] as int,
      reps: map[DatabaseConstants.colReps] as int,
      lapses: map[DatabaseConstants.colLapses] as int,
      lastReview: lastReviewStr != null ? DateTime.parse(lastReviewStr) : null,
      cardState: CardState.values[map[DatabaseConstants.colCardState] as int],
      step: map[DatabaseConstants.colStep] as int?,
      userId: map[DatabaseConstants.colUserId] as String,
      syncStatus: SyncStatus.values.byName(map[DatabaseConstants.colSyncStatus] as String),
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
    step,
    userId,
    syncStatus,
  ];
}
