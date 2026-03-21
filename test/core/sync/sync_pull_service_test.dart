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
import 'package:postgrest/postgrest.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Fakes ──────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

/// Fake query builder whose [select] returns a configurable result set.
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
  PostgrestTransformBuilder<PostgrestList> range(int from, int to,
      {String? referencedTable}) {
    final end = to + 1 > _data.length ? _data.length : to + 1;
    final start = from > _data.length ? _data.length : from;
    return FakeTransformBuilder(_data.sublist(start, end));
  }

  @override
  Future<U> then<U>(
    FutureOr<U> Function(PostgrestList) onValue, {
    Function? onError,
  }) =>
      Future.value(PostgrestList.from(_data))
          .then(onValue, onError: onError);
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

// ── Tests ──────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late DeckRepository deckRepo;
  late MockSupabaseClient mockClient;
  late String dbName;

  /// Per-table fake builders so tests can configure results per table.
  late Map<String, FakeQueryBuilder> tableBuilders;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    dbName = 'test_pull_${DateTime.now().microsecondsSinceEpoch}.db';
    helper = DatabaseHelper.forTesting(dbName: dbName);
    deckRepo = DeckRepository(dbHelper: helper);

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

  SyncPullService buildService() => SyncPullService(
        dbHelper: helper,
        client: mockClient,
      );

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
      final rows = await db.query(DatabaseConstants.tableDecks,
          where: '${DatabaseConstants.colDeckId} = ?',
          whereArgs: ['deck-1']);
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
        Deck(deckId: 'deck-1', deckName: 'Local', createdAt: now, updatedAt: now),
      );
      final created = await deckRepo.getById('deck-1');
      await deckRepo.markSynced({
        'deck-1': created!.updatedAt.toUtc().toIso8601String(),
      });

      // Remote has updated name
      final remoteTsStr = now.add(const Duration(seconds: 10)).toUtc().toIso8601String();
      tableBuilders[DatabaseConstants.tableDecks]!.setResult([
        remoteDecRow(id: 'deck-1', name: 'Updated on Server',
            updatedAt: DateTime.parse(remoteTsStr)),
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
        Deck(deckId: 'deck-1', deckName: 'Local Edit', createdAt: now, updatedAt: now),
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
        Deck(deckId: 'deck-1', deckName: 'Local Edit', createdAt: now, updatedAt: now),
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
        Deck(deckId: 'deck-1', deckName: 'Local', createdAt: now, updatedAt: now),
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
    test('saves pull timestamp on success', () async {
      final service = buildService();
      await service.pull();

      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('last_pull_timestamp');
      expect(saved, isNotNull);
      // Should be a valid ISO 8601 timestamp
      expect(() => DateTime.parse(saved!), returnsNormally);
    });

    test('does not update timestamp on failure', () async {
      // Make decks pull throw
      when(() => mockClient.from(DatabaseConstants.tableDecks))
          .thenThrow(Exception('Network error'));

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
}
