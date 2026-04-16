import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/core/database/database_constants.dart';

enum CardState { newCard, learning, review, relearning }

enum CardType {
  twoSided, // Simple front/back text
  oneSided, // One sided card
  reverse, // two sided card that can be reviewed in either direction (front/back or back/front)
  cloze, // Cloze deletion with {{c1::answer}} syntax, one sided
}

sealed class Flashcard {

  final String cardId; // UUID
  final String deckId; // Parent deck
  final CardType cardType; // Type of card content
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // Soft delete for sync
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
    required this.cardType,
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
    this.step,
    required this.syncStatus,
    required this.userId,
  });

  Map<String, dynamic> baseMap() => {
    DatabaseConstants.colCardId: cardId,
    DatabaseConstants.colDeckId: deckId,
    DatabaseConstants.colCardType: cardType.index,
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

  Map<String, dynamic> toMap();

   Flashcard copyWith({
    String? deckId,
    CardType? cardType,
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
    int? step,
    String? userId,
    SyncStatus? syncStatus,
  });


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Flashcard && cardId == other.cardId;

  @override
  int get hashCode => cardId.hashCode;
}

class TwoSidedCard extends Flashcard {
  final String front;
  final String back;

  const TwoSidedCard({
    required super.cardId,
    required super.deckId,
    required super.createdAt,
    required super.updatedAt,
    required super.isDeleted,
    required super.dueDate,
    required super.stability,
    required super.difficulty,
    required super.elapsedDays,
    required super.scheduledDays,
    required super.reps,
    required super.lapses,
    super.lastReview,
    required super.cardState,
    super.step,
    required super.syncStatus,
    required super.userId,
    required this.front,
    required this.back,
  }) : super(cardType: CardType.twoSided);

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      DatabaseConstants.colFront: front,
      DatabaseConstants.colBack: back,
    };
  }

  @override
  TwoSidedCard copyWith({
    String? deckId,
    CardType? cardType,
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
    int? step,
    String? userId,
    SyncStatus? syncStatus,
    // subclass-specific
    String? front,
    String? back,
  }) {
    return TwoSidedCard(
      cardId: cardId,
      deckId: deckId ?? this.deckId,
      createdAt: createdAt,
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
      step: step ?? this.step,
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? this.syncStatus,
      front: front ?? this.front,
      back: back ?? this.back,
    );
  }

  static TwoSidedCard fromMap(Map<String, dynamic> map) {
    final lastReviewStr = map[DatabaseConstants.colLastReview] as String?;
    return TwoSidedCard(
      cardId: map[DatabaseConstants.colCardId] as String,
      deckId: map[DatabaseConstants.colDeckId] as String,
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
      front: map[DatabaseConstants.colFront] as String,
      back: map[DatabaseConstants.colBack] as String,
    );
  }
}

class OneSidedCard extends Flashcard {
  final String front;

  const OneSidedCard({
    required super.cardId,
    required super.deckId,
    required super.createdAt,
    required super.updatedAt,
    required super.isDeleted,
    required super.dueDate,
    required super.stability,
    required super.difficulty,
    required super.elapsedDays,
    required super.scheduledDays,
    required super.reps,
    required super.lapses,
    super.lastReview,
    required super.cardState,
    super.step,
    required super.syncStatus,
    required super.userId,
    required this.front,
  }) : super(cardType: CardType.oneSided);

  @override
  Flashcard copyWith({String? deckId, CardType? cardType, DateTime? updatedAt, bool? isDeleted, DateTime? dueDate, double? stability, double? difficulty, int? elapsedDays, int? scheduledDays, int? reps, int? lapses, DateTime? lastReview, CardState? cardState, int? step, String? userId, SyncStatus? syncStatus, String? front}) {
    return OneSidedCard(
      cardId: cardId,
      deckId: deckId ?? this.deckId,
      createdAt: createdAt,
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
      step: step ?? this.step,
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? this.syncStatus,
      // field specific
      front: front ?? this.front,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      DatabaseConstants.colFront: front,
    };
  }

  static OneSidedCard fromMap(Map<String, dynamic> map) {
    final lastReviewStr = map[DatabaseConstants.colLastReview] as String?;
    return OneSidedCard(
      cardId: map[DatabaseConstants.colCardId] as String,
      deckId: map[DatabaseConstants.colDeckId] as String,
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
      front: map[DatabaseConstants.colFront] as String,
    );
  }
}

class ReverseCard extends Flashcard {
  final String front;
  final String back;

  const ReverseCard({
    required super.cardId,
    required super.deckId,
    required super.createdAt,
    required super.updatedAt,
    required super.isDeleted,
    required super.dueDate,
    required super.stability,
    required super.difficulty,
    required super.elapsedDays,
    required super.scheduledDays,
    required super.reps,
    required super.lapses,
    super.lastReview,
    required super.cardState,
    super.step,
    required super.syncStatus,
    required super.userId,
    required this.front,
    required this.back,
  }) : super(cardType: CardType.reverse);

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      DatabaseConstants.colFront: front,
      DatabaseConstants.colBack: back,
    };
  }

  @override
  ReverseCard copyWith({
    String? deckId,
    CardType? cardType,
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
    int? step,
    String? userId,
    SyncStatus? syncStatus,
    // subclass-specific
    String? front,
    String? back,
  }) {
    return ReverseCard(
      cardId: cardId,
      deckId: deckId ?? this.deckId,
      createdAt: createdAt,
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
      step: step ?? this.step,
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? this.syncStatus,
      front: front ?? this.front,
      back: back ?? this.back,
    );
  }

  static ReverseCard fromMap(Map<String, dynamic> map) {
    final lastReviewStr = map[DatabaseConstants.colLastReview] as String?;
    return ReverseCard(
      cardId: map[DatabaseConstants.colCardId] as String,
      deckId: map[DatabaseConstants.colDeckId] as String,
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
      front: map[DatabaseConstants.colFront] as String,
      back: map[DatabaseConstants.colBack] as String,
    );
  }
}

class ClozeCard extends Flashcard {
  final String text; // {{c1::answer}} syntax

  const ClozeCard({
    required super.cardId,
    required super.deckId,
    required super.createdAt,
    required super.updatedAt,
    required super.isDeleted,
    required super.dueDate,
    required super.stability,
    required super.difficulty,
    required super.elapsedDays,
    required super.scheduledDays,
    required super.reps,
    required super.lapses,
    super.lastReview,
    required super.cardState,
    super.step,
    required super.syncStatus,
    required super.userId,
    required this.text,
  }) : super(cardType: CardType.cloze);


  @override
  Flashcard copyWith({String? deckId, CardType? cardType, DateTime? updatedAt, bool? isDeleted, DateTime? dueDate, double? stability, double? difficulty, int? elapsedDays, int? scheduledDays, int? reps, int? lapses, DateTime? lastReview, CardState? cardState, int? step, String? userId, SyncStatus? syncStatus, String? text}) {
    return ClozeCard(
      cardId: cardId,
      deckId: deckId ?? this.deckId,
      createdAt: createdAt,
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
      step: step ?? this.step,
      userId: userId ?? this.userId,
      syncStatus: syncStatus ?? this.syncStatus,
      text: text ?? this.text,
    );
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      ...baseMap(),
      DatabaseConstants.colFront: text, // Cloze text stored in 'front' column
    };
  }

  static ClozeCard fromMap(Map<String, dynamic> map) {
    final lastReviewStr = map[DatabaseConstants.colLastReview] as String?;
    return ClozeCard(
      cardId: map[DatabaseConstants.colCardId] as String,
      deckId: map[DatabaseConstants.colDeckId] as String,
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
      text: map[DatabaseConstants.colFront] as String, // Cloze text stored in 'front' column
    );
  }
}

class FlashcardMapper { // Factories cannot exist inside sealed classes so we use this
  static Flashcard fromMap(Map<String, dynamic> map) {
    final cardType = CardType.values[map[DatabaseConstants.colCardType] as int];
    switch (cardType) {
      case CardType.twoSided:
        return TwoSidedCard.fromMap(map);
      case CardType.oneSided:
        return OneSidedCard.fromMap(map);
      case CardType.reverse:
        return ReverseCard.fromMap(map);
      case CardType.cloze:
        return ClozeCard.fromMap(map);
    }
  }
}