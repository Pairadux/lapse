import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/database/database_constants.dart';

void main() {
  // Use FFI-backed sqflite so tests run on desktop without a real device.
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;

  setUp(() {
    helper = DatabaseHelper.forTesting(dbName: 'test_db_helper.db');
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, 'test_db_helper.db'));
  });

  test('database opens successfully', () async {
    final db = await helper.database;
    expect(db.isOpen, isTrue);
  });

  test('all 4 tables exist', () async {
    final db = await helper.database;
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' AND name NOT LIKE 'android_%'",
    );
    final names = tables.map((r) => r['name'] as String).toSet();

    expect(
      names,
      containsAll(['decks', 'cards', 'reviews', 'review_session_summary']),
    );
  });

  test('all 12 indexes exist', () async {
    final db = await helper.database;
    final indexes = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' AND name LIKE 'idx_%'",
    );
    final names = indexes.map((r) => r['name'] as String).toSet();

    expect(
      names,
      containsAll([
        'idx_decks_parent_id',
        'idx_decks_user_id',
        'idx_decks_sync_status',
        'idx_cards_due_date',
        'idx_cards_deck_due',
        'idx_cards_sync_status',
        'idx_reviews_card_id',
        'idx_reviews_reviewed_at',
        'idx_reviews_sync_status',
        'idx_session_summary_user_id',
        'idx_session_summary_user_date',
        'idx_session_summary_sync_status',
      ]),
    );
  });

  test('foreign keys are enforced', () async {
    final db = await helper.database;
    final result = await db.rawQuery('PRAGMA foreign_keys');
    expect(result.first.values.first, 1);
  });

  group('round-trip insert/read', () {
    test('decks', () async {
      final db = await helper.database;
      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert(DatabaseConstants.tableDecks, {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'Test Deck',
        DatabaseConstants.colUserId: 'user-1',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      });

      final rows = await db.query(DatabaseConstants.tableDecks);
      expect(rows, hasLength(1));
      expect(rows.first[DatabaseConstants.colDeckName], 'Test Deck');
      expect(rows.first[DatabaseConstants.colParentId], isNull);
      expect(rows.first[DatabaseConstants.colIsDeleted], 0);
    });

    test('cards', () async {
      final db = await helper.database;
      final now = DateTime.now().toUtc().toIso8601String();

      // Insert parent deck first (FK).
      await db.insert(DatabaseConstants.tableDecks, {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'Deck',
        DatabaseConstants.colUserId: 'user-1',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      });

      await db.insert(DatabaseConstants.tableCards, {
        DatabaseConstants.colCardId: 'card-1',
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colUserId: 'user-1',
        DatabaseConstants.colFront: 'Q',
        DatabaseConstants.colBack: 'A',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
        DatabaseConstants.colDueDate: now,
      });

      final rows = await db.query(DatabaseConstants.tableCards);
      expect(rows, hasLength(1));
      expect(rows.first[DatabaseConstants.colFront], 'Q');
      expect(rows.first[DatabaseConstants.colStability], 0.0);
      expect(rows.first[DatabaseConstants.colCardState], 0);
    });

    test('reviews', () async {
      final db = await helper.database;
      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert(DatabaseConstants.tableDecks, {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'Deck',
        DatabaseConstants.colUserId: 'user-1',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
      });
      await db.insert(DatabaseConstants.tableCards, {
        DatabaseConstants.colCardId: 'card-1',
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colUserId: 'user-1',
        DatabaseConstants.colFront: 'Q',
        DatabaseConstants.colBack: 'A',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
        DatabaseConstants.colDueDate: now,
      });

      await db.insert(DatabaseConstants.tableReviews, {
        DatabaseConstants.colReviewId: 'review-1',
        DatabaseConstants.colCardId: 'card-1',
        DatabaseConstants.colReviewedAt: now,
        DatabaseConstants.colRating: 3,
        DatabaseConstants.colScheduledDays: 1,
        DatabaseConstants.colElapsedDays: 0,
        DatabaseConstants.colState: 0,
      });

      final rows = await db.query(DatabaseConstants.tableReviews);
      expect(rows, hasLength(1));
      expect(rows.first[DatabaseConstants.colRating], 3);
      expect(rows.first[DatabaseConstants.colReviewId], 'review-1');
    });
  });

  test('FK violation throws on invalid deck_id', () async {
    final db = await helper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    expect(
      () => db.insert(DatabaseConstants.tableCards, {
        DatabaseConstants.colCardId: 'card-orphan',
        DatabaseConstants.colDeckId: 'nonexistent-deck',
        DatabaseConstants.colUserId: 'user-1',
        DatabaseConstants.colFront: 'Q',
        DatabaseConstants.colBack: 'A',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
        DatabaseConstants.colDueDate: now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('CASCADE delete: removing deck removes its cards', () async {
    final db = await helper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert(DatabaseConstants.tableDecks, {
      DatabaseConstants.colDeckId: 'deck-1',
      DatabaseConstants.colDeckName: 'Deck',
      DatabaseConstants.colUserId: 'user-1',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
    });
    await db.insert(DatabaseConstants.tableCards, {
      DatabaseConstants.colCardId: 'card-1',
      DatabaseConstants.colDeckId: 'deck-1',
      DatabaseConstants.colUserId: 'user-1',
      DatabaseConstants.colFront: 'Q',
      DatabaseConstants.colBack: 'A',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
      DatabaseConstants.colDueDate: now,
    });

    // Verify card exists.
    expect(await db.query(DatabaseConstants.tableCards), hasLength(1));

    // Delete the deck.
    await db.delete(
      DatabaseConstants.tableDecks,
      where: '${DatabaseConstants.colDeckId} = ?',
      whereArgs: ['deck-1'],
    );

    // Card should be cascade-deleted.
    expect(await db.query(DatabaseConstants.tableCards), isEmpty);
  });

  test('soft delete filtering works via WHERE clause', () async {
    final db = await helper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    await db.insert(DatabaseConstants.tableDecks, {
      DatabaseConstants.colDeckId: 'deck-active',
      DatabaseConstants.colDeckName: 'Active',
      DatabaseConstants.colUserId: 'user-1',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
      DatabaseConstants.colIsDeleted: 0,
    });
    await db.insert(DatabaseConstants.tableDecks, {
      DatabaseConstants.colDeckId: 'deck-deleted',
      DatabaseConstants.colDeckName: 'Deleted',
      DatabaseConstants.colUserId: 'user-1',
      DatabaseConstants.colCreatedAt: now,
      DatabaseConstants.colUpdatedAt: now,
      DatabaseConstants.colIsDeleted: 1,
    });

    final active = await db.query(
      DatabaseConstants.tableDecks,
      where: '${DatabaseConstants.colIsDeleted} = 0',
    );
    expect(active, hasLength(1));
    expect(active.first[DatabaseConstants.colDeckId], 'deck-active');

    // Unfiltered query returns both.
    final all = await db.query(DatabaseConstants.tableDecks);
    expect(all, hasLength(2));
  });
}
