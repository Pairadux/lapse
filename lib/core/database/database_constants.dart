import 'package:sqflite/sqflite.dart';

/// Compile-time constants for the SQLite schema.
abstract final class DatabaseConstants {
  static const String databaseName = 'lapse.db';
  static const int databaseVersion = 3;

  // -- Table names --
  static const String tableDecks = 'decks';
  static const String tableCards = 'cards';
  static const String tableReviews = 'reviews';

  // -- Deck columns --
  static const String colDeckId = 'deck_id';
  static const String colParentId = 'parent_id';
  static const String colDeckName = 'deck_name';

  // -- Card columns --
  static const String colCardId = 'card_id';
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

  // -- Review columns --
  static const String colId = 'id';
  static const String colReviewedAt = 'reviewed_at';
  static const String colRating = 'rating';
  static const String colState = 'state';

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
      $colSyncStatus    TEXT NOT NULL DEFAULT 'synced'
    )
  ''';

  static const String createReviewsTable =
      '''
    CREATE TABLE $tableReviews (
      $colId            INTEGER PRIMARY KEY AUTOINCREMENT,
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

  /// All DDL statements executed during [onCreate], in order.
  static const List<String> createStatements = [
    createDecksTable,
    createCardsTable,
    createReviewsTable,
    createIndexDecksParentId,
    createIndexDecksUserId,
    createIndexCardsDueDate,
    createIndexCardsDeckDue,
    createIndexReviewsCardId,
    createIndexReviewsReviewedAt,
  ];

  Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      // decks
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDecks} ADD COLUMN ${DatabaseConstants.colUserId} TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableDecks} ADD COLUMN ${DatabaseConstants.colSyncStatus} TEXT NOT NULL DEFAULT 'synced'",
      );

      // cards
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableCards} ADD COLUMN ${DatabaseConstants.colUserId} TEXT NOT NULL DEFAULT ''",
      );
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableCards} ADD COLUMN ${DatabaseConstants.colSyncStatus} TEXT NOT NULL DEFAULT 'synced'",
      );

      // reviews
      await db.execute("ALTER TABLE ${DatabaseConstants.tableReviews} ADD COLUMN ${DatabaseConstants.colUserId} TEXT");
      await db.execute(
        "ALTER TABLE ${DatabaseConstants.tableReviews} ADD COLUMN ${DatabaseConstants.colSyncStatus} TEXT NOT NULL DEFAULT 'synced'",
      );
    }
  }
}
