import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'database_constants.dart';

/// Singleton helper that owns the app's SQLite [Database] connection.
class DatabaseHelper {
  final String _dbName;
  final bool _forTesting;

  DatabaseHelper._({String? dbName}) : _dbName = dbName ?? DatabaseConstants.databaseName, _forTesting = false;
  static final DatabaseHelper instance = DatabaseHelper._();

  /// Creates an independent instance with its own DB file for testing.
  /// Bypasses [getApplicationSupportDirectory] so tests run without
  /// a Flutter engine.
  @visibleForTesting
  DatabaseHelper.forTesting({String dbName = 'test.db'}) : _dbName = dbName, _forTesting = true;

  Database? _database;

  /// Returns the open database, creating it on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// On Android, [getDatabasesPath] returns the standard app database
  /// directory. On iOS and desktop, [getApplicationSupportDirectory] returns
  /// the platform-idiomatic location (Library/Application Support on
  /// iOS/macOS, ~/.local/share on Linux, %APPDATA% on Windows). The desktop
  /// FFI backend's [getDatabasesPath] returns "." (the CWD), which is
  /// unwritable for packaged installs.
  Future<Database> _initDatabase() async {
    final String dbPath;
    if (_forTesting || Platform.isAndroid) {
      dbPath = await getDatabasesPath();
    } else {
      final dir = await getApplicationSupportDirectory();
      dbPath = dir.path;
    }
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enables FK enforcement for every new connection.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Runs all v1 DDL from [DatabaseConstants.createStatements].
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final sql in DatabaseConstants.createStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }

  /// Sequential migration loop for future schema versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 2:
          await _migrateV2(db);
          break;
        case 3:
          await _migrateV3(db);
          break;
        case 4:
          await _migrateV4(db);
          break;
        case 5:
          await _migrateV5(db);
          break;
        case 6:
          await _migrateV6(db);
          break;
        default:
          break;
      }
    }
  }

  /// v2: Add step column to cards table for FSRS learning step tracking.
  Future<void> _migrateV2(Database db) async {
    final columns = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableCards})');
    final hasStep = columns.any((col) => col['name'] == DatabaseConstants.colStep);
    if (!hasStep) {
      await db.execute('ALTER TABLE ${DatabaseConstants.tableCards} ADD COLUMN ${DatabaseConstants.colStep} INTEGER');
    }
  }

  /// v3: Add sync_status and user_id columns to all tables.
  /// Decks already has user_id from v1, so only sync_status is added there.
  Future<void> _migrateV3(Database db) async {
    // decks — user_id already exists from v1 schema, only add sync_status
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

    // partial indexes — only index non-synced rows for efficient sync queries
    await db.execute(DatabaseConstants.createIndexDecksSyncStatus);
    await db.execute(DatabaseConstants.createIndexCardsSyncStatus);
    await db.execute(DatabaseConstants.createIndexReviewsSyncStatus);
  }

  /// v4: Replace reviews auto-increment integer PK with UUID text PK.
  /// Existing rows get a generated UUID; the column is renamed from
  /// `id` to `review_id` to match the deck_id/card_id convention.
  Future<void> _migrateV4(Database db) async {
    const uuid = Uuid();

    // Create the new table with UUID primary key
    await db.execute('''
      CREATE TABLE reviews_v2 (
        ${DatabaseConstants.colReviewId}      TEXT PRIMARY KEY,
        ${DatabaseConstants.colCardId}        TEXT NOT NULL REFERENCES ${DatabaseConstants.tableCards}(${DatabaseConstants.colCardId}) ON DELETE CASCADE,
        ${DatabaseConstants.colReviewedAt}    TEXT NOT NULL,
        ${DatabaseConstants.colRating}        INTEGER NOT NULL,
        ${DatabaseConstants.colScheduledDays} INTEGER NOT NULL,
        ${DatabaseConstants.colElapsedDays}   INTEGER NOT NULL,
        ${DatabaseConstants.colState}         INTEGER NOT NULL,
        ${DatabaseConstants.colUserId}        TEXT,
        ${DatabaseConstants.colSyncStatus}    TEXT NOT NULL DEFAULT 'synced'
      )
    ''');

    // Copy existing rows, generating a UUID for each
    final rows = await db.query(DatabaseConstants.tableReviews);
    if (rows.isNotEmpty) {
      final batch = db.batch();
      for (final row in rows) {
        batch.insert('reviews_v2', {
          DatabaseConstants.colReviewId: uuid.v4(),
          DatabaseConstants.colCardId: row[DatabaseConstants.colCardId],
          DatabaseConstants.colReviewedAt: row[DatabaseConstants.colReviewedAt],
          DatabaseConstants.colRating: row[DatabaseConstants.colRating],
          DatabaseConstants.colScheduledDays: row[DatabaseConstants.colScheduledDays],
          DatabaseConstants.colElapsedDays: row[DatabaseConstants.colElapsedDays],
          DatabaseConstants.colState: row[DatabaseConstants.colState],
          DatabaseConstants.colUserId: row[DatabaseConstants.colUserId],
          DatabaseConstants.colSyncStatus: row[DatabaseConstants.colSyncStatus],
        });
      }
      await batch.commit(noResult: true);
    }

    // Swap tables
    await db.execute('DROP TABLE ${DatabaseConstants.tableReviews}');
    await db.execute('ALTER TABLE reviews_v2 RENAME TO ${DatabaseConstants.tableReviews}');

    // Recreate indexes
    await db.execute(DatabaseConstants.createIndexReviewsCardId);
    await db.execute(DatabaseConstants.createIndexReviewsReviewedAt);
    await db.execute(DatabaseConstants.createIndexReviewsSyncStatus);
  }

  /// v5: Add review_session_summary table for persistent session tracking.
  Future<void> _migrateV5(Database db) async {
    await db.execute(DatabaseConstants.createReviewSessionSummaryTable);
    await db.execute(DatabaseConstants.createIndexSessionSummaryUserId);
    await db.execute(DatabaseConstants.createIndexSessionSummaryUserDate);
    await db.execute(DatabaseConstants.createIndexSessionSummarySyncStatus);
  }

  /// v6: Add card_type column to cards table for advanced card types.
  Future<void> _migrateV6(Database db) async {
    await db.execute(
      'ALTER TABLE ${DatabaseConstants.tableCards} ADD COLUMN ${DatabaseConstants.colCardType} INTEGER NOT NULL DEFAULT 0',
    );
  }

  /// Purges soft-deleted rows older than 7 days that are safe to remove.
  ///
  /// Rows with `sync_status = 'pending'` and a non-empty `user_id` are never
  /// purged — they still need to push the deletion tombstone to the server.
  Future<void> purgeTombstones() async {
    final db = await database;
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).toUtc().toIso8601String();

    await db.transaction((txn) async {
      // Purge cards first (safe — no dependents).
      var deleted = await txn.rawDelete(
        '''DELETE FROM ${DatabaseConstants.tableCards}
           WHERE ${DatabaseConstants.colIsDeleted} = 1
             AND ${DatabaseConstants.colUpdatedAt} < ?
             AND (${DatabaseConstants.colSyncStatus} = 'synced'
                  OR ${DatabaseConstants.colUserId} = '')''',
        [cutoff],
      );
      if (deleted > 0) {
        debugPrint('[Tombstone] Purged $deleted rows from cards');
      }

      // Purge decks only when no child cards would be cascade-deleted.
      // A deck with pending (unsynced) cards must wait.
      deleted = await txn.rawDelete(
        '''DELETE FROM ${DatabaseConstants.tableDecks}
           WHERE ${DatabaseConstants.colIsDeleted} = 1
             AND ${DatabaseConstants.colUpdatedAt} < ?
             AND (${DatabaseConstants.colSyncStatus} = 'synced'
                  OR ${DatabaseConstants.colUserId} = '')
             AND ${DatabaseConstants.colDeckId} NOT IN (
               SELECT ${DatabaseConstants.colDeckId}
               FROM ${DatabaseConstants.tableCards}
               WHERE ${DatabaseConstants.colSyncStatus} = 'pending'
                 AND ${DatabaseConstants.colUserId} != ''
             )''',
        [cutoff],
      );
      if (deleted > 0) {
        debugPrint('[Tombstone] Purged $deleted rows from decks');
      }
    });
  }

  /// Deletes all rows from every table, preserving the schema.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableReviews);
      await txn.delete(DatabaseConstants.tableReviewSessionSummary);
      await txn.delete(DatabaseConstants.tableCards);
      await txn.delete(DatabaseConstants.tableDecks);
    });
  }

  /// Closes the database and resets the cached reference.
  /// Primarily used for test teardown.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
