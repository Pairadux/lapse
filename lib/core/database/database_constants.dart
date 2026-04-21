/// Compile-time constants for the SQLite schema.
abstract final class DatabaseConstants {
  static const String databaseName = 'lapse.db';
  static const int databaseVersion = 6;

  // -- Table names --
  static const String tableDecks = 'decks';
  static const String tableCards = 'cards';
  static const String tableReviews = 'reviews';
  static const String tableReviewSessionSummary = 'review_session_summary';

  // -- Deck columns --
  static const String colDeckId = 'deck_id';
  static const String colParentId = 'parent_id';
  static const String colDeckName = 'deck_name';

  // -- Card columns --
  static const String colCardId = 'card_id';
  static const String colCardType = 'card_type';
  static const String colFront = 'front';
  static const String colBack = 'back';
  static const String colDueDate = 'due_date';
  static const String colStability = 'stability';
  static const String colDifficulty = 'difficulty';
  static const String colElapsedDays = 'elapsed_days';
  static const String colScheduledDays = 'scheduled_days';
  static const String colReps = 'reps';
  static const String colLapses = 'lapses';
  static const String colLastReview = 'last_review';
  static const String colCardState = 'card_state';
  static const String colStep = 'step';
  static const String colPairID = 'pair_id';

  // -- Review columns --
  static const String colReviewId = 'review_id';
  static const String colReviewedAt = 'reviewed_at';
  static const String colRating = 'rating';
  static const String colState = 'state';

  // -- Review session summary columns --
  static const String colSessionId = 'id';
  static const String colDate = 'date';
  static const String colStartedAt = 'started_at';
  static const String colEndedAt = 'ended_at';
  static const String colTotalReviews = 'total_reviews';
  static const String colAgainCount = 'again_count';
  static const String colHardCount = 'hard_count';
  static const String colGoodCount = 'good_count';
  static const String colEasyCount = 'easy_count';
  static const String colNewCount = 'new_count';
  static const String colLearningCount = 'learning_count';
  static const String colReviewCount = 'review_count';
  static const String colDurationMs = 'duration_ms';

  // -- Shared columns --
  static const String colCreatedAt = 'created_at';
  static const String colUpdatedAt = 'updated_at';
  static const String colIsDeleted = 'is_deleted';
  static const String colSyncStatus = 'sync_status';
  static const String colUserId = 'user_id';

  // ── CREATE TABLE DDL ──────────────────────────────────────────────

  static const String createDecksTable =
      '''
    CREATE TABLE $tableDecks (
      $colDeckId    TEXT PRIMARY KEY,
      $colParentId  TEXT,
      $colDeckName  TEXT NOT NULL,
      $colUserId    TEXT NOT NULL,
      $colCreatedAt TEXT NOT NULL,
      $colUpdatedAt TEXT NOT NULL,
      $colIsDeleted INTEGER NOT NULL DEFAULT 0,
      $colSyncStatus   TEXT NOT NULL DEFAULT 'synced'
    )
  ''';

  static const String createCardsTable =
      '''
    CREATE TABLE $tableCards (
      $colCardId        TEXT PRIMARY KEY,
      $colDeckId        TEXT NOT NULL REFERENCES $tableDecks($colDeckId) ON DELETE CASCADE,
      $colCardType      INTEGER NOT NULL DEFAULT 0,
      $colFront         TEXT NOT NULL,
      $colBack          TEXT NOT NULL,
      $colCreatedAt     TEXT NOT NULL,
      $colUpdatedAt     TEXT NOT NULL,
      $colIsDeleted     INTEGER NOT NULL DEFAULT 0,
      $colDueDate       TEXT NOT NULL,
      $colStability     REAL NOT NULL DEFAULT 0.0,
      $colDifficulty    REAL NOT NULL DEFAULT 0.0,
      $colElapsedDays   INTEGER NOT NULL DEFAULT 0,
      $colScheduledDays INTEGER NOT NULL DEFAULT 0,
      $colReps          INTEGER NOT NULL DEFAULT 0,
      $colLapses        INTEGER NOT NULL DEFAULT 0,
      $colLastReview    TEXT,
      $colCardState     INTEGER NOT NULL DEFAULT 0,
      $colStep          INTEGER,
      $colUserId        TEXT NOT NULL,
      $colSyncStatus    TEXT NOT NULL DEFAULT 'synced',
      $colPairID        TEXT DEFAULT ''

    )
  ''';

  static const String createReviewsTable =
      '''
    CREATE TABLE $tableReviews (
      $colReviewId      TEXT PRIMARY KEY,
      $colCardId        TEXT NOT NULL REFERENCES $tableCards($colCardId) ON DELETE CASCADE,
      $colReviewedAt    TEXT NOT NULL,
      $colRating        INTEGER NOT NULL,
      $colScheduledDays INTEGER NOT NULL,
      $colElapsedDays   INTEGER NOT NULL,
      $colState         INTEGER NOT NULL,
      $colUserId        TEXT,
      $colSyncStatus    TEXT NOT NULL DEFAULT 'synced'
    )
  ''';

  static const String createReviewSessionSummaryTable =
      '''
    CREATE TABLE $tableReviewSessionSummary (
      $colSessionId       TEXT PRIMARY KEY,
      $colUserId          TEXT NOT NULL DEFAULT '',
      $colDate            TEXT NOT NULL,
      $colStartedAt       TEXT NOT NULL,
      $colEndedAt         TEXT NOT NULL,
      $colTotalReviews    INTEGER NOT NULL DEFAULT 0,
      $colAgainCount      INTEGER NOT NULL DEFAULT 0,
      $colHardCount       INTEGER NOT NULL DEFAULT 0,
      $colGoodCount       INTEGER NOT NULL DEFAULT 0,
      $colEasyCount       INTEGER NOT NULL DEFAULT 0,
      $colNewCount        INTEGER NOT NULL DEFAULT 0,
      $colLearningCount   INTEGER NOT NULL DEFAULT 0,
      $colReviewCount     INTEGER NOT NULL DEFAULT 0,
      $colDurationMs      INTEGER NOT NULL DEFAULT 0,
      $colSyncStatus      TEXT NOT NULL DEFAULT 'synced',
      $colUpdatedAt       TEXT NOT NULL
    )
  ''';

  // ── CREATE INDEX DDL ──────────────────────────────────────────────

  static const String createIndexDecksParentId =
      '''
    CREATE INDEX idx_decks_parent_id ON $tableDecks($colParentId)
      WHERE $colIsDeleted = 0 AND $colParentId IS NOT NULL
  ''';

  static const String createIndexDecksUserId =
      '''
    CREATE INDEX idx_decks_user_id ON $tableDecks($colUserId)
      WHERE $colIsDeleted = 0
  ''';

  static const String createIndexCardsDueDate =
      '''
    CREATE INDEX idx_cards_due_date ON $tableCards($colDueDate)
      WHERE $colIsDeleted = 0
  ''';

  static const String createIndexCardsDeckDue =
      '''
    CREATE INDEX idx_cards_deck_due ON $tableCards($colDeckId, $colDueDate)
      WHERE $colIsDeleted = 0
  ''';

  static const String createIndexReviewsCardId =
      '''
    CREATE INDEX idx_reviews_card_id ON $tableReviews($colCardId)
  ''';

  static const String createIndexReviewsReviewedAt =
      '''
    CREATE INDEX idx_reviews_reviewed_at ON $tableReviews($colReviewedAt)
  ''';

  static const String createIndexDecksSyncStatus =
      '''
    CREATE INDEX idx_decks_sync_status ON $tableDecks($colSyncStatus)
      WHERE $colSyncStatus != 'synced'
  ''';

  static const String createIndexCardsSyncStatus =
      '''
    CREATE INDEX idx_cards_sync_status ON $tableCards($colSyncStatus)
      WHERE $colSyncStatus != 'synced'
  ''';

  static const String createIndexReviewsSyncStatus =
      '''
    CREATE INDEX idx_reviews_sync_status ON $tableReviews($colSyncStatus)
      WHERE $colSyncStatus != 'synced'
  ''';

  static const String createIndexSessionSummaryUserId =
      '''
    CREATE INDEX idx_session_summary_user_id ON $tableReviewSessionSummary($colUserId)
  ''';

  static const String createIndexSessionSummaryUserDate =
      '''
    CREATE INDEX idx_session_summary_user_date ON $tableReviewSessionSummary($colUserId, $colDate)
  ''';

  static const String createIndexSessionSummarySyncStatus =
      '''
    CREATE INDEX idx_session_summary_sync_status ON $tableReviewSessionSummary($colSyncStatus)
      WHERE $colSyncStatus != 'synced'
  ''';

  /// All DDL statements executed during [onCreate], in order.
  static const List<String> createStatements = [
    createDecksTable,
    createCardsTable,
    createReviewsTable,
    createReviewSessionSummaryTable,
    createIndexDecksParentId,
    createIndexDecksUserId,
    createIndexCardsDueDate,
    createIndexCardsDeckDue,
    createIndexReviewsCardId,
    createIndexReviewsReviewedAt,
    createIndexDecksSyncStatus,
    createIndexCardsSyncStatus,
    createIndexReviewsSyncStatus,
    createIndexSessionSummaryUserId,
    createIndexSessionSummaryUserDate,
    createIndexSessionSummarySyncStatus,
  ];
}
