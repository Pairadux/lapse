import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/sync/sync_push_service.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/study/data/review_repository.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Mocks ──────────────────────────────────────────────────────────

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockGoTrueClient extends Mock implements GoTrueClient {}

/// Fake query builder whose [upsert] records calls and returns an
/// immediately-completing future.
class FakeQueryBuilder extends Fake implements SupabaseQueryBuilder {
  final List<List<Map<String, dynamic>>> upsertCalls = [];

  @override
  PostgrestFilterBuilder upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    upsertCalls.add(List<Map<String, dynamic>>.from(values as List));
    return FakeFilterBuilder();
  }
}

/// Fake that completes immediately when awaited with no value.
class FakeFilterBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  @override
  Future<U> then<U>(FutureOr<U> Function(T) onValue, {Function? onError}) =>
      Future<T>.value(null as T).then(onValue, onError: onError);
}

// ── Tests ──────────────────────────────────────────────────────────

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late DeckRepository deckRepo;
  late CardRepository cardRepo;
  late ReviewRepository reviewRepo;
  late ReviewSessionSummaryRepository summaryRepo;
  late MockSupabaseClient mockClient;
  late FakeQueryBuilder fakeQueryBuilder;
  late String dbName;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dbName = 'test_push_${DateTime.now().microsecondsSinceEpoch}.db';
    helper = DatabaseHelper.forTesting(dbName: dbName);
    deckRepo = DeckRepository(dbHelper: helper);
    cardRepo = CardRepository(dbHelper: helper);
    reviewRepo = ReviewRepository(dbHelper: helper);
    summaryRepo = ReviewSessionSummaryRepository(dbHelper: helper);

    mockClient = MockSupabaseClient();
    fakeQueryBuilder = FakeQueryBuilder();

    final mockAuth = MockGoTrueClient();
    when(() => mockAuth.currentUser).thenReturn(null);
    when(() => mockClient.auth).thenReturn(mockAuth);
    when(() => mockClient.from(any())).thenAnswer((_) => fakeQueryBuilder);
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, dbName));
  });

  SyncPushService buildService() => SyncPushService(
    deckRepo: deckRepo,
    cardRepo: cardRepo,
    reviewRepo: reviewRepo,
    summaryRepo: summaryRepo,
    client: mockClient,
  );

  Future<void> insertDeck({String id = 'deck-1', String name = 'Test'}) async {
    final now = DateTime.now();
    await deckRepo.create(
      Deck(deckId: id, deckName: name, createdAt: now, updatedAt: now),
    );
  }

  Future<void> insertCard({
    String id = 'card-1',
    String deckId = 'deck-1',
    String front = 'Q',
    String back = 'A',
  }) async {
    final now = DateTime.now();
    await cardRepo.create(
      Flashcard(
        cardId: id,
        deckId: deckId,
        front: front,
        back: back,
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

  Future<void> insertManyDecks(int count) async {
    for (var i = 0; i < count; i++) {
      await insertDeck(id: 'deck-$i', name: 'Deck $i');
    }
  }

  Future<void> insertManyCards(int count, {String deckId = 'deck-1'}) async {
    for (var i = 0; i < count; i++) {
      await insertCard(
        id: 'card-$i',
        deckId: deckId,
        front: 'Q $i',
        back: 'A $i',
      );
    }
  }



  test('push returns true when nothing is unsynced', () async {
    final service = buildService();
    final result = await service.push();
    expect(result, isTrue);
    expect(fakeQueryBuilder.upsertCalls, isEmpty);
  });

  test('push upserts pending decks and marks them synced', () async {
    await insertDeck();
    final service = buildService();

    final result = await service.push();
    expect(result, isTrue);

    // Verify upsert was called
    expect(fakeQueryBuilder.upsertCalls, hasLength(1));
    final upsertedRows = fakeQueryBuilder.upsertCalls.first;
    expect(upsertedRows, hasLength(1));
    // Supabase row should not have sync_status
    expect(
      upsertedRows.first.containsKey(DatabaseConstants.colSyncStatus),
      isFalse,
    );
    // is_deleted should be bool, not int
    expect(upsertedRows.first[DatabaseConstants.colIsDeleted], isFalse);

    // After push, deck should be marked synced
    final unsynced = await deckRepo.getUnsynced();
    expect(unsynced, isEmpty);
  });

  test('push upserts decks then cards in FK order', () async {
    await insertDeck();
    await insertCard();
    final service = buildService();

    final result = await service.push();
    expect(result, isTrue);

    // Two upsert calls: one for decks, one for cards
    expect(fakeQueryBuilder.upsertCalls, hasLength(2));

    // Verify client.from() was called with decks first, then cards
    final fromCalls = verify(() => mockClient.from(captureAny())).captured;
    expect(fromCalls[0], DatabaseConstants.tableDecks);
    expect(fromCalls[1], DatabaseConstants.tableCards);
  });

  test('push marks both decks and cards synced on success', () async {
    await insertDeck();
    await insertCard();
    final service = buildService();

    await service.push();

    expect(await deckRepo.getUnsynced(), isEmpty);
    expect(await cardRepo.getUnsynced(), isEmpty);
  });

  test('push stops on first table failure', () async {
    await insertDeck();
    await insertCard();

    // Make the first upsert throw (deck push fails)
    var callCount = 0;
    final failingQueryBuilder = FakeQueryBuilder();
    when(() => mockClient.from(any())).thenAnswer((_) {
      callCount++;
      if (callCount == 1) {
        // Return a builder whose upsert throws
        return ThrowingQueryBuilder();
      }
      return failingQueryBuilder;
    });

    final service = buildService();
    final result = await service.push();

    expect(result, isFalse);
    // Cards should NOT have been attempted since decks failed
    expect(failingQueryBuilder.upsertCalls, isEmpty);
    // Both should still be pending
    expect(await deckRepo.getUnsynced(), hasLength(1));
    expect(await cardRepo.getUnsynced(), hasLength(1));
  });

  test('push converts is_deleted to bool for Supabase', () async {
    await insertDeck();
    final service = buildService();

    await service.push();

    final row = fakeQueryBuilder.upsertCalls.first.first;
    expect(row[DatabaseConstants.colIsDeleted], isA<bool>());
    expect(row[DatabaseConstants.colIsDeleted], isFalse);
  });

  test('push sends deleted rows with is_deleted=true', () async {
    await insertDeck();
    await deckRepo.delete('deck-1');
    final service = buildService();

    await service.push();

    final row = fakeQueryBuilder.upsertCalls.first.first;
    expect(row[DatabaseConstants.colIsDeleted], isTrue);
  });

  test('push does not include sync_status in Supabase payload', () async {
    await insertDeck();
    final service = buildService();

    await service.push();

    for (final call in fakeQueryBuilder.upsertCalls) {
      for (final row in call) {
        expect(
          row.containsKey(DatabaseConstants.colSyncStatus),
          isFalse,
          reason: 'sync_status should be stripped before sending to Supabase',
        );
      }
    }
  });

  test(
    'push with no client override returns false (Supabase not configured)',
    () async {
      // Service without client override — relies on SupabaseConfig which is not
      // initialized in tests.
      final service = SyncPushService(
        deckRepo: deckRepo,
        cardRepo: cardRepo,
        reviewRepo: reviewRepo,
        summaryRepo: summaryRepo,
      );

      final result = await service.push();
      expect(result, isFalse);
    },
  );

  group('paginated push', () {
    test(
      'pushes exactly 1000 rows as single page',
      () async {
        await insertManyDecks(1000);
        final service = buildService();

        final result = await service.push();

        expect(result, isTrue);
        expect(fakeQueryBuilder.upsertCalls, hasLength(1)); // One page
        expect(fakeQueryBuilder.upsertCalls.first, hasLength(1000));

        final unsynced = await deckRepo.getUnsynced();
        expect(unsynced, isEmpty);
      },
    );

    test(
      'splits 2500 rows into 3 pages (1000, 1000, 500)',
      () async {
        await insertManyDecks(2500);
        final service = buildService();

        await service.push();

        expect(fakeQueryBuilder.upsertCalls, hasLength(3));
        expect(fakeQueryBuilder.upsertCalls[0], hasLength(1000));
        expect(fakeQueryBuilder.upsertCalls[1], hasLength(1000));
        expect(fakeQueryBuilder.upsertCalls[2], hasLength(500));
      },
    );

    test(
      'marks all pages synced even if final page is small',
      () async {
        await insertManyDecks(1001); // Just over 1 page size
        final service = buildService();

        await service.push();

        final unsynced = await deckRepo.getUnsynced();
        expect(unsynced, isEmpty);
      },
    );

    test(
      'stops pushing subsequent pages if first page fails',
      () async {
        await insertDeck(id: 'deck-1');
        await insertManyCards(2500, deckId: 'deck-1');

        var callCount = 0;
        final recorder = FakeQueryBuilder();
        when(() => mockClient.from(DatabaseConstants.tableCards))
          .thenAnswer((_) {
            callCount++;
            if (callCount == 1) return ThrowingQueryBuilder(); // First page fails
            return recorder;
          });

        final service = buildService();

        final result = await service.push();

        expect(result, isFalse); // Push failed
        expect(recorder.upsertCalls, isEmpty); // Second page never attempted
        expect(await cardRepo.getUnsynced(), hasLength(2500)); // All still pending
      },
    );

    test(
      'marks first page synced if second page fails',
      () async {
        // Arrange: 2000 cards split into 2 pages
        await insertDeck(id: 'deck-1');
        await insertManyCards(2000, deckId: 'deck-1');

        var callCount = 0;
        when(() => mockClient.from(DatabaseConstants.tableCards))
          .thenAnswer((_) {
            callCount++;
            if (callCount == 2) return ThrowingQueryBuilder(); // Second page fails
            return fakeQueryBuilder;
          });

        final service = buildService();

        // Act
        final result = await service.push();

        // Assert
        expect(result, isFalse);
        expect(await cardRepo.getUnsynced(), hasLength(1000)); // Only 2nd page pending
      },
    );
  });
}

/// Query builder whose [upsert] throws to simulate network failure.
class ThrowingQueryBuilder extends Fake implements SupabaseQueryBuilder {
  @override
  PostgrestFilterBuilder upsert(
    Object values, {
    String? onConflict,
    bool ignoreDuplicates = false,
    bool defaultToNull = true,
  }) {
    return ThrowingFilterBuilder();
  }
}

class ThrowingFilterBuilder<T> extends Fake
    implements PostgrestFilterBuilder<T> {
  @override
  Future<U> then<U>(FutureOr<U> Function(T) onValue, {Function? onError}) =>
      Future<T>.error(
        Exception('Network error'),
        StackTrace.current,
      ).then(onValue, onError: onError);
}
