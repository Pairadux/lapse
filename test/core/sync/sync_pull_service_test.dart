import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/core/sync/sync_pull_service.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/data/review_repository.dart';
import 'package:lapse/features/study/domain/review.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/domain/review_session_summary.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes ──────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Fake query builder whose [select] returns a configurable result set.
// ignore: must_be_immutable
class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  List<Map<String, dynamic>> _nextResult = [];

  void setResult(List<Map<String, dynamic>> rows) => _nextResult = rows;

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakeFilterBuilder(_nextResult);
  }
}

/// Fake filter builder that supports [gt], [order], [range], and awaiting.
class FakeFilterBuilder extends Fake
    implements PostgrestFilterBuilder<PostgrestList> {
  final List<Map<String, dynamic>> _data;

  FakeFilterBuilder(this._data);

  @override
  PostgrestFilterBuilder<PostgrestList> gt(String column, Object value) {
    // Filter rows where column > value (for incremental pull)
    final filtered = _data.where((row) {
      final rowVal = row[column] as String;
      return rowVal.compareTo(value as String) > 0;
    }).toList();
    return FakeFilterBuilder(filtered);
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(
    String column, {
    bool ascending = false,
    bool nullsFirst = false,
    String? referencedTable,
  }) {
    return FakeTransformBuilder(_data);
  }
}

class FakeTransformBuilder extends Fake
    implements PostgrestTransformBuilder<PostgrestList> {
  final List<Map<String, dynamic>> _data;

  FakeTransformBuilder(this._data);

  @override
  PostgrestTransformBuilder<PostgrestList> range(
    int from,
    int to, {
    String? referencedTable,
  }) {
    final end = to + 1 > _data.length ? _data.length : to + 1;
    final start = from > _data.length ? _data.length : from;
    return FakeTransformBuilder(_data.sublist(start, end));
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList) onValue, {
    Function? onError,
  }) => Future.value(PostgrestList.from(_data)).then(onValue, onError: onError);
}

class FakePaginatedQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<Map<String, dynamic>> allRows;
  final int pageIndex;

  FakePaginatedQueryBuilder(this.allRows, this.pageIndex);

  @override
  PostgrestFilterBuilder<PostgrestList> select([String columns = '*']) {
    return FakePaginatedFilterBuilder(allRows, pageIndex);
  }
}

class FakePaginatedFilterBuilder extends Fake implements PostgrestFilterBuilder<PostgrestList> {
  final List<Map<String, dynamic>> allRows;
  final int pageIndex;
  final int offset = 0;

  FakePaginatedFilterBuilder(this.allRows, this.pageIndex);

  @override
  PostgrestFilterBuilder<PostgrestList> gt(String column, Object value) {
    return this; // Ignore gt for paginated test
  }

  @override
  PostgrestTransformBuilder<PostgrestList> order(String column,
      {bool ascending = false,
      bool nullsFirst = false,
      String? referencedTable}) {
    return FakePaginatedTransformBuilder(allRows, offset);
  }
}

class FakePaginatedTransformBuilder extends Fake implements PostgrestTransformBuilder<PostgrestList> {
  final List<Map<String, dynamic>> allRows;
  final int offset;

  FakePaginatedTransformBuilder(this.allRows, this.offset);

  @override
  PostgrestTransformBuilder<PostgrestList> range(int from, int to,
      {String? referencedTable}) {
    final start = from;
    final end = (to + 1).clamp(0, allRows.length);
    final page = allRows.sublist(start, end);
    return FakePaginatedTransformBuilder(page, offset);
  }

  @override
  Future<U> then<U>(FutureOr<U> Function(PostgrestList) onValue,
      {Function? onError}) {
    return Future.value(PostgrestList.from(allRows))
        .then(onValue, onError: onError);
  }
}

// ── Helpers ────────────────────────────────────────────────────────

/// Builds a Supabase-format deck row (booleans, no sync_status).
Map<String, dynamic> remoteDecRow({
  required String id,
  String name = 'Remote Deck',
  String? parentId,
  String userId = 'user-1',
  bool isDeleted = false,
  DateTime? updatedAt,
}) {
  final ts = (updatedAt ?? DateTime.now()).toUtc().toIso8601String();
  return {
    DatabaseConstants.colDeckId: id,
    DatabaseConstants.colParentId: parentId,
    DatabaseConstants.colDeckName: name,
    DatabaseConstants.colUserId: userId,
    DatabaseConstants.colCreatedAt: ts,
    DatabaseConstants.colUpdatedAt: ts,
    DatabaseConstants.colIsDeleted: isDeleted,
  };
}

Map<String, dynamic> remoteCardRow({
  required String id,
  String deckId = 'deck-1',
  String front = 'Q',
  String back = 'A',
  String userId = 'user-1',
  bool isDeleted = false,
  DateTime? updatedAt,
}) {
  final ts = (updatedAt ?? DateTime.now()).toUtc().toIso8601String();
  return {
    DatabaseConstants.colCardId: id,
    DatabaseConstants.colDeckId: deckId,
    DatabaseConstants.colFront: front,
    DatabaseConstants.colBack: back,
    DatabaseConstants.colUserId: userId,
    DatabaseConstants.colCreatedAt: ts,
    DatabaseConstants.colUpdatedAt: ts,
    DatabaseConstants.colIsDeleted: isDeleted,
    DatabaseConstants.colDueDate: ts,
    DatabaseConstants.colStability: 0.0,
    DatabaseConstants.colDifficulty: 0.0,
    DatabaseConstants.colElapsedDays: 0,
    DatabaseConstants.colScheduledDays: 0,
    DatabaseConstants.colReps: 0,
    DatabaseConstants.colLapses: 0,
    DatabaseConstants.colCardState: 0,  // CardState.newCard.index
  };
}

Map<String, dynamic> remoteReviewRow({
  required String id,
  String cardId = 'card-1',
  String rating = 'good',  // Supabase returns enum as string
  String userId = 'user-1',
  DateTime? reviewedAt,
}) {
  final ts = (reviewedAt ?? DateTime.now()).toUtc().toIso8601String();
  // Convert string enums to integers (what the database expects)
  final ratingIndex = Rating.values.firstWhere((r) => r.name == rating).index;
  final stateIndex = CardState.learning.index;  // Default to learning

  return {
    DatabaseConstants.colReviewId: id,
    DatabaseConstants.colCardId: cardId,
    DatabaseConstants.colReviewedAt: ts,
    DatabaseConstants.colRating: ratingIndex,  // int
    DatabaseConstants.colScheduledDays: 1,
    DatabaseConstants.colElapsedDays: 0,
    DatabaseConstants.colState: stateIndex,  // int
    DatabaseConstants.colUserId: userId,
  };
}

Map<String, dynamic> remoteSessionRow({
  required String id,
  String date = '2026-04-06',
  int totalReviews = 3,
  int againCount = 1,
  int hardCount = 0,
  int goodCount = 2,
  int easyCount = 0,
  String userId = 'user-1',
  DateTime? updatedAt,
}) {
  final ts = (updatedAt ?? DateTime.now()).toUtc().toIso8601String();
  return {
    DatabaseConstants.colSessionId: id,
    DatabaseConstants.colDate: date,
    DatabaseConstants.colStartedAt: ts,
    DatabaseConstants.colEndedAt: ts,
    DatabaseConstants.colTotalReviews: totalReviews,
    DatabaseConstants.colAgainCount: againCount,
    DatabaseConstants.colHardCount: hardCount,
    DatabaseConstants.colGoodCount: goodCount,
    DatabaseConstants.colEasyCount: easyCount,
    DatabaseConstants.colNewCount: 0,
    DatabaseConstants.colLearningCount: 0,
    DatabaseConstants.colReviewCount: 0,
    DatabaseConstants.colDurationMs: 300000,
    DatabaseConstants.colUserId: userId,
    DatabaseConstants.colUpdatedAt: ts,
  };
}

// ── Tests ──────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late DeckRepository deckRepo;
  late MockSupabaseClient mockClient;
  late String dbName;
  late CardRepository cardRepo;
  late ReviewRepository reviewRepo;
  late ReviewSessionSummaryRepository summaryRepo;

  /// Per-table fake builders so tests can configure results per table.
  late Map<String, FakeQueryBuilder> tableBuilders;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    dbName = 'test_pull_${DateTime.now().microsecondsSinceEpoch}.db';
    helper = DatabaseHelper.forTesting(dbName: dbName);
    deckRepo = DeckRepository(dbHelper: helper);
    cardRepo = CardRepository(dbHelper: helper);
    reviewRepo = ReviewRepository(dbHelper: helper);
    summaryRepo = ReviewSessionSummaryRepository(dbHelper: helper);

    mockClient = MockSupabaseClient();
    tableBuilders = {
      DatabaseConstants.tableDecks: FakeQueryBuilder(),
      DatabaseConstants.tableCards: FakeQueryBuilder(),
      DatabaseConstants.tableReviews: FakeQueryBuilder(),
      DatabaseConstants.tableReviewSessionSummary: FakeQueryBuilder(),
    };
    when(() => mockClient.from(any())).thenAnswer((invocation) {
      final table = invocation.positionalArguments[0] as String;
      return tableBuilders[table] ?? FakeQueryBuilder();
    });
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, dbName));
  });

  SyncPullService buildService() =>
      SyncPullService(dbHelper: helper, client: mockClient);

  Future<void> insertDeck({String id = 'deck-1', String name = 'Test'}) async {
    final now = DateTime.now();
    await deckRepo.create(
      Deck(deckId: id, deckName: name, createdAt: now, updatedAt: now),
    );
  }

  Future<void> insertCard({
    String id = 'card-1',
    String deckId = 'deck-1',
  }) async {
    final now = DateTime.now();
    await cardRepo.create(
      Flashcard(
        cardId: id,
        deckId: deckId,
        front: 'Q',
        back: 'A',
        createdAt: now,
        updatedAt: now,
        dueDate: now,
        stability: 0,
        difficulty: 0,
        elapsedDays: 0,
        scheduledDays: 0,
        reps: 0,
        lapses: 0,
        cardState: CardState.newCard,
      ),
    );
  }

  group('basic pull', () {
    test('pull returns true when no remote data', () async {
      final service = buildService();
      final result = await service.pull();
      expect(result, isTrue);
    });

    test('pull inserts new remote deck into local DB', () async {
      final ts = DateTime.now().toUtc();
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1', name: 'From Server', updatedAt: ts),
      ]);

      final service = buildService();
      final result = await service.pull();
      expect(result, isTrue);

      final deck = await deckRepo.getById('deck-1');
      expect(deck, isNotNull);
      expect(deck!.deckName, 'From Server');
    });

    test('pulled deck has sync_status synced', () async {
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1'),
      ]);

      final service = buildService();
      await service.pull();

      final deck = await deckRepo.getById('deck-1');
      expect(deck!.syncStatus, SyncStatus.synced);
    });

    test('pulled deck converts is_deleted bool to int', () async {
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1', isDeleted: true),
      ]);

      final service = buildService();
      await service.pull();

      // getById excludes deleted, so query raw
      final db = await helper.database;
      final rows = await db.query(
        DatabaseConstants.tableDecks,
        where: '${DatabaseConstants.colDeckId} = ?',
        whereArgs: ['deck-1'],
      );
      expect(rows.first[DatabaseConstants.colIsDeleted], 1);
    });

    test('pull with no client override returns false', () async {
      final service = SyncPullService(dbHelper: helper);
      final result = await service.pull();
      expect(result, isFalse);
    });
  });

  group('conflict resolution', () {
    test('overwrites local synced row with remote data', () async {
      // Insert a local deck and mark it synced
      final now = DateTime.now();
      await deckRepo.create(
        Deck(
          deckId: 'deck-1',
          deckName: 'Local',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final created = await deckRepo.getById('deck-1');
      await deckRepo.markSynced({
        'deck-1': created!.updatedAt.toUtc().toIso8601String(),
      });

      // Remote has updated name
      final remoteTsStr = now
          .add(const Duration(seconds: 10))
          .toUtc()
          .toIso8601String();
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(
          id: 'deck-1',
          name: 'Updated on Server',
          updatedAt: DateTime.parse(remoteTsStr),
        ),
      ]);

      final service = buildService();
      await service.pull();

      final deck = await deckRepo.getById('deck-1');
      expect(deck!.deckName, 'Updated on Server');
      expect(deck.syncStatus, SyncStatus.synced);
    });

    test('remote wins when local is pending but remote is newer', () async {
      final now = DateTime.now();
      await deckRepo.create(
        Deck(
          deckId: 'deck-1',
          deckName: 'Local Edit',
          createdAt: now,
          updatedAt: now,
        ),
      );
      // Local row is pending (just created), not synced

      // Remote has a newer timestamp
      final remoteTs = now.add(const Duration(seconds: 10));
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1', name: 'Remote Wins', updatedAt: remoteTs),
      ]);

      final service = buildService();
      await service.pull();

      final deck = await deckRepo.getById('deck-1');
      expect(deck!.deckName, 'Remote Wins');
    });

    test('local wins when local is pending and newer than remote', () async {
      final now = DateTime.now();
      await deckRepo.create(
        Deck(
          deckId: 'deck-1',
          deckName: 'Local Edit',
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Remote has an OLDER timestamp
      final remoteTs = now.subtract(const Duration(seconds: 10));
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1', name: 'Remote Loses', updatedAt: remoteTs),
      ]);

      final service = buildService();
      await service.pull();

      final deck = await deckRepo.getById('deck-1');
      expect(deck!.deckName, 'Local Edit');
    });

    test('local pending row stays pending when it wins conflict', () async {
      final now = DateTime.now();
      await deckRepo.create(
        Deck(
          deckId: 'deck-1',
          deckName: 'Local',
          createdAt: now,
          updatedAt: now,
        ),
      );

      final remoteTs = now.subtract(const Duration(seconds: 10));
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1', name: 'Old Remote', updatedAt: remoteTs),
      ]);

      final service = buildService();
      await service.pull();

      final unsynced = await deckRepo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.syncStatus, SyncStatus.pending);
    });
  });

  group('last_pull_timestamp', () {
    test('saves pull timestamp when rows are pulled', () async {
      // Provide at least one remote row so the server timestamp is recorded.
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-ts'),
      ]);

      final service = buildService();
      await service.pull();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_pull_timestamp');
      expect(saved, isNotNull);
      expect(() => DateTime.parse(saved!), returnsNormally);
    });

    test('does not advance cursor when nothing is pulled', () async {
      final service = buildService();
      await service.pull();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_pull_timestamp'), isNull);
    });

    test('does not update timestamp on failure', () async {
      // Make decks pull throw
      when(
        () => mockClient.from(DatabaseConstants.tableDecks),
      ).thenThrow(Exception('Network error'));

      final service = buildService();
      await service.pull();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_pull_timestamp'), isNull);
    });

    test('incremental pull uses last_pull_timestamp for filtering', () async {
      final oldTs = DateTime(2026, 1, 1).toUtc();

      // First pull: one old deck
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-old', name: 'Old', updatedAt: oldTs),
      ]);
      final service = buildService();
      await service.pull();

      // Timestamp for the new deck must be in the future relative to
      // last_pull_timestamp (which was captured as DateTime.now() during
      // the first pull).
      final newTs = DateTime.now().add(const Duration(hours: 1)).toUtc();

      // Second pull: add a newer deck, keep old one in remote results.
      // The gt() filter should exclude the old one (timestamp < lastPull)
      // but include the new one (timestamp > lastPull).
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-old', name: 'Old', updatedAt: oldTs),
        remoteDecRow(id: 'deck-new', name: 'New', updatedAt: newTs),
      ]);

      await service.pull();

      // Both should exist locally (old from first pull, new from second)
      expect(await deckRepo.getById('deck-old'), isNotNull);
      expect(await deckRepo.getById('deck-new'), isNotNull);
    });
  });

  group('card pull', () {
    test('pulls new card from remote', () async {
      await insertDeck(id: 'deck-1');
      tableBuilders[DatabaseConstants.tableCards]!.setResult([
        remoteCardRow(id: 'card-1', front: 'Test Q', back: 'Test A'),
      ]);

      final service = buildService();
      final result = await service.pull();

      final card = await cardRepo.getById('card-1');
      expect(card, isNotNull);
      expect(card!.front, 'Test Q');
      expect(card.back, 'Test A');
      expect(card.syncStatus, SyncStatus.synced);
    });

    test('overwrites local synced card with remote data', () async {
      await insertDeck(id: 'deck-1');
      final now = DateTime.now();
      await cardRepo.create(
        Flashcard(
          cardId: 'card-1',
          deckId: 'deck-1',
          front: 'Old Q',
          back: 'Old A',
          createdAt: now,
          updatedAt: now,
          dueDate: now,
          stability: 0,
          difficulty: 0,
          elapsedDays: 0,
          scheduledDays: 0,
          reps: 0,
          lapses: 0,
          cardState: CardState.newCard,
        ),
      );
      final card = await cardRepo.getById('card-1');
      await cardRepo.markSynced({'card-1': card!.updatedAt.toUtc().toIso8601String()});

      // Remote has updated front/back
      tableBuilders[DatabaseConstants.tableCards]!.setResult([
        remoteCardRow(
          id: 'card-1',
          front: 'New Q',
          back: 'New A',
          updatedAt: now.add(const Duration(seconds: 10)),
        ),
      ]);

      final service = buildService();
      await service.pull();

      final updated = await cardRepo.getById('card-1');
      expect(updated!.front, 'New Q');
      expect(updated.back, 'New A');
    });

    test('card conflict resolution: remote wins if newer', () async {
      await insertDeck(id: 'deck-1');
      final now = DateTime.now();

      // Local pending card (not synced)
      await cardRepo.create(
        Flashcard(
          cardId: 'card-1',
          deckId: 'deck-1',
          front: 'Local Q',
          back: 'Local A',
          createdAt: now,
          updatedAt: now,
          dueDate: now,
          stability: 0,
          difficulty: 0,
          elapsedDays: 0,
          scheduledDays: 0,
          reps: 0,
          lapses: 0,
          cardState: CardState.newCard,
        ),
      );

      // Remote is newer
      tableBuilders[DatabaseConstants.tableCards]!.setResult([
        remoteCardRow(
          id: 'card-1',
          front: 'Remote Q',
          updatedAt: now.add(const Duration(seconds: 10)),
        ),
      ]);

      final service = buildService();
      await service.pull();

      final card = await cardRepo.getById('card-1');
      expect(card!.front, 'Remote Q');
    });

     test('card conflict resolution: local wins if newer', () async {
      await insertDeck(id: 'deck-1');
      final now = DateTime.now();

      await cardRepo.create(
        Flashcard(
          cardId: 'card-1',
          deckId: 'deck-1',
          front: 'Local Q',
          back: 'Local A',
          createdAt: now,
          updatedAt: now,
          dueDate: now,
          stability: 0,
          difficulty: 0,
          elapsedDays: 0,
          scheduledDays: 0,
          reps: 0,
          lapses: 0,
          cardState: CardState.newCard,
        ),
      );

      // Remote is older
      tableBuilders[DatabaseConstants.tableCards]!.setResult([
        remoteCardRow(
          id: 'card-1',
          front: 'Remote Q',
          updatedAt: now.subtract(const Duration(seconds: 10)),
        ),
      ]);

      final service = buildService();
      await service.pull();

      final card = await cardRepo.getById('card-1');
      expect(card!.front, 'Local Q'); // Local wins
    });
  });

  group('review pull', () {
    test('pulls new review from remote', () async {
      await insertDeck(id: 'deck-1');
      await insertCard(id: 'card-1', deckId: 'deck-1');
      tableBuilders[DatabaseConstants.tableReviews]!.setResult([
        remoteReviewRow(id: 'review-1', cardId: 'card-1', rating: 'good'),
      ]);

      final service = buildService();
      await service.pull();

      // ReviewRepository.getById() doesn't exist, so query database directly
      final db = await helper.database;
      final rows = await db.query(
        DatabaseConstants.tableReviews,
        where: '${DatabaseConstants.colReviewId} = ?',
        whereArgs: ['review-1'],
      );
      expect(rows, hasLength(1));
      final review = Review.fromMap(rows.first);
      expect(review.rating, Rating.good);
      expect(review.syncStatus, SyncStatus.synced);
    });

    test('batch inserts multiple reviews with ConflictAlgorithm.ignore', () async {
      await insertDeck(id: 'deck-1');
      await insertCard(id: 'card-1', deckId: 'deck-1');
      // Insert one local review that will conflict with remote
      final now = DateTime.now();
      await reviewRepo.addReview(
        Review(
          reviewId: 'review-1',
          cardId: 'card-1',
          reviewedAt: now,
          rating: Rating.good,
          scheduledDays: 1,
          elapsedDays: 0,
          state: CardState.learning,
        ),
      );

      // Remote has same review-1 (duplicate) + new review-2
      tableBuilders[DatabaseConstants.tableReviews]!.setResult([
        remoteReviewRow(id: 'review-1', reviewedAt: now, rating: 'good'),
        remoteReviewRow(id: 'review-2', reviewedAt: now.add(const Duration(seconds: 1)), rating: 'good'),
      ]);

      final service = buildService();
      await service.pull();

      // Both should be present; review-1 unchanged (ignored), review-2 inserted
      final db = await helper.database;
      final reviews = await db.query(
        DatabaseConstants.tableReviews,
        where: '${DatabaseConstants.colReviewId} IN (?, ?)',
        whereArgs: ['review-1', 'review-2'],
      );
      expect(reviews, hasLength(2));
    });

    test('review pull uses reviewed_at, not updated_at, for cursor', () async {
      await insertDeck(id: 'deck-1');
      await insertCard(id: 'card-1', deckId: 'deck-1');
      // This is important: reviews don't have a server-managed updated_at.
      // They use reviewed_at (client timestamp). Make sure the pull doesn't
      // try to include reviewed_at in the lastPull cursor (avoiding clock skew).

      final oldTs = DateTime(2026, 1, 1).toUtc();
      tableBuilders[DatabaseConstants.tableReviews]!.setResult([
        remoteReviewRow(id: 'review-1', reviewedAt: oldTs, rating: 'good'),
      ]);

      final service = buildService();
      await service.pull();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_pull_timestamp');

      // The saved timestamp should come from decks/cards/summaries, not reviews.
      // If only reviews were pulled, timestamp should NOT advance.
      // (This is tricky — best verified by checking full pull with mixed data.)
      expect(saved, isNull); // No deck/card/summary data, so no cursor advance
    });

    test('reviews are insert-only and never deleted', () async {
      await insertDeck(id: 'deck-1');
      await insertCard(id: 'card-1', deckId: 'deck-1');
      // Reviews have no is_deleted field and soft-delete is not applied.
      // This test just verifies the data model is handled correctly.

      tableBuilders[DatabaseConstants.tableReviews]!.setResult([
        remoteReviewRow(id: 'review-1', rating: 'good'),
      ]);

      final service = buildService();
      await service.pull();

      // Query database directly (ReviewRepository.getById doesn't exist)
      final db = await helper.database;
      final rows = await db.query(
        DatabaseConstants.tableReviews,
        where: '${DatabaseConstants.colReviewId} = ?',
        whereArgs: ['review-1'],
      );
      expect(rows, hasLength(1));
      final review = Review.fromMap(rows.first);
      expect(review.syncStatus, SyncStatus.synced);

      // Manually query to confirm no is_deleted column in reviews
      final cols = await db.rawQuery(
        "PRAGMA table_info(${DatabaseConstants.tableReviews})",
      );
      final hasIsDeleted = cols.any((col) => col['name'] == DatabaseConstants.colIsDeleted);
      expect(hasIsDeleted, isFalse);
    });
  });

  group('session summary pull', () {
    test('pulls new session summary from remote', () async {
      tableBuilders[DatabaseConstants.tableReviewSessionSummary]!.setResult([
        remoteSessionRow(id: 'summary-1', totalReviews: 10),
      ]);

      final service = buildService();
      await service.pull();

      // Query database directly (ReviewSessionSummaryRepository.getById doesn't exist)
      final db = await helper.database;
      final rows = await db.query(
        DatabaseConstants.tableReviewSessionSummary,
        where: '${DatabaseConstants.colSessionId} = ?',
        whereArgs: ['summary-1'],
      );
      expect(rows, hasLength(1));
      final summary = ReviewSessionSummary.fromMap(rows.first);
      expect(summary.totalReviews, 10);
      expect(summary.syncStatus, SyncStatus.synced);
    });

    test('overwrites local synced summary with remote', () async {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await summaryRepo.add(
        ReviewSessionSummary(
          id: 'summary-1',
          date: dateStr,
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 5)),
          totalReviews: 5,
          againCount: 1,
          hardCount: 1,
          goodCount: 2,
          easyCount: 1,
          newCount: 0,
          learningCount: 0,
          reviewCount: 0,
          durationMs: 300000,
        ),
      );
      final existing = await summaryRepo.getAll();
      final existingRow = existing.firstWhere((s) => s.id == 'summary-1');
      await summaryRepo.markSynced({'summary-1': existingRow.updatedAt.toUtc().toIso8601String()});

      tableBuilders[DatabaseConstants.tableReviewSessionSummary]!.setResult([
        remoteSessionRow(
          id: 'summary-1',
          totalReviews: 20, // Different count
          updatedAt: now.add(const Duration(seconds: 10)),
        ),
      ]);

      final service = buildService();
      await service.pull();

      // Query database directly
      final db = await helper.database;
      final rows = await db.query(
        DatabaseConstants.tableReviewSessionSummary,
        where: '${DatabaseConstants.colSessionId} = ?',
        whereArgs: ['summary-1'],
      );
      expect(rows, hasLength(1));
      final updated = ReviewSessionSummary.fromMap(rows.first);
      expect(updated.totalReviews, 20);
    });

    test('summaries show conflict resolution: remote wins if newer', () async {
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      await summaryRepo.add(
        ReviewSessionSummary(
          id: 'summary-1',
          date: dateStr,
          startedAt: now,
          endedAt: now.add(const Duration(minutes: 5)),
          totalReviews: 5,
          againCount: 1,
          hardCount: 1,
          goodCount: 2,
          easyCount: 1,
          newCount: 0,
          learningCount: 0,
          reviewCount: 0,
          durationMs: 300000,
        ),
      );
      // Intentionally not marking as synced; leave as pending

      tableBuilders[DatabaseConstants.tableReviewSessionSummary]!.setResult([
        remoteSessionRow(
          id: 'summary-1',
          totalReviews: 50,
          updatedAt: now.add(const Duration(seconds: 10)),
        ),
      ]);

      final service = buildService();
      await service.pull();

      // Query database directly
      final db = await helper.database;
      final rows = await db.query(
        DatabaseConstants.tableReviewSessionSummary,
        where: '${DatabaseConstants.colSessionId} = ?',
        whereArgs: ['summary-1'],
      );
      expect(rows, hasLength(1));
      final summary = ReviewSessionSummary.fromMap(rows.first);
      expect(summary.totalReviews, 50); // Remote wins
    });
  });

  group('paginated pull', () {
    test('fetches exactly 1000 deck rows in single page', () async {
      final rows = List.generate(1000, (i) {
        final ts = DateTime.now().add(Duration(seconds: i)).toUtc().toIso8601String();
        return remoteDecRow(id: 'deck-$i', name: 'Deck $i', updatedAt: DateTime.parse(ts));
      });

      tableBuilders[DatabaseConstants.tableDecks]!.setResult(rows);

      final service = buildService();
      final result = await service.pull();
      expect(result, isTrue);

      // All 1000 should be in local DB
      final db = await helper.database;
      final countResult = await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableDecks}');
      final count = countResult.isEmpty ? 0 : (countResult.first['COUNT(*)'] as int);
      expect(count, 1000);
    });

    test('paginates 2500 deck rows across 3 pages', () async {
      // This test verifies the pagination logic in _fetchPage / _pullTable.
      // Since our fake doesn't implement real pagination, we simulate it:
      // - First call returns 1000 rows
      // - Second call returns 1000 rows
      // - Third call returns 500 rows
      // - Fourth call returns 0 rows (stop)

      final allRows = List.generate(2500, (i) {
        final ts = DateTime.now().add(Duration(seconds: i)).toUtc().toIso8601String();
        return remoteDecRow(id: 'deck-$i', name: 'Deck $i', updatedAt: DateTime.parse(ts));
      });

      var pageIndex = 0;
      when(() => mockClient.from(DatabaseConstants.tableDecks))
        .thenAnswer((_) {
          return FakePaginatedQueryBuilder(allRows, pageIndex++);
        });

      final service = buildService();
      final result = await service.pull();
      expect(result, isTrue);

      // All 2500 rows should be present
      final db = await helper.database;
      final countResult = await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableDecks}');
      final count = countResult.isEmpty ? 0 : (countResult.first['COUNT(*)'] as int);
      expect(count, 2500);
    });

    test('pull stops at empty page', () async {
      // Return 500 rows (less than page size), then next call returns empty
      final rows = List.generate(500, (i) {
        final ts = DateTime.now().add(Duration(seconds: i)).toUtc().toIso8601String();
        return remoteDecRow(id: 'deck-$i', updatedAt: DateTime.parse(ts));
      });

      tableBuilders[DatabaseConstants.tableDecks]!.setResult(rows);

      final service = buildService();
      final result = await service.pull();
      expect(result, isTrue);

      final db = await helper.database;
      final countResult = await db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableDecks}');
      final count = countResult.isEmpty ? 0 : (countResult.first['COUNT(*)'] as int);
      expect(count, 500);
    });
  });
}
