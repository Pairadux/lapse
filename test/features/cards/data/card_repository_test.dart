import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late DeckRepository deckRepo;
  late CardRepository cardRepo;
  late String dbName;

  setUp(() {
    dbName = 'test_card_repo_${DateTime.now().microsecondsSinceEpoch}.db';
    helper = DatabaseHelper.forTesting(dbName: dbName);
    deckRepo = DeckRepository(dbHelper: helper);
    cardRepo = CardRepository(dbHelper: helper);
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, dbName));
  });

  /// Insert a parent deck to satisfy FK constraints.
  Future<void> insertParentDeck({String id = 'deck-1'}) async {
    final now = DateTime.now();
    await deckRepo.create(
      Deck(deckId: id, deckName: 'Parent', createdAt: now, updatedAt: now),
    );
  }

  Flashcard makeCard({
    String id = 'card-1',
    String deckId = 'deck-1',
    String front = 'Q',
    String back = 'A',
    DateTime? dueDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    final created = createdAt ?? now;
    return Flashcard(
      cardId: id,
      deckId: deckId,
      front: front,
      back: back,
      createdAt: created,
      updatedAt: updatedAt ?? created,
      dueDate: dueDate ?? created,
      stability: 0.0,
      difficulty: 0.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      cardState: CardState.newCard,
    );
  }

  test('create + getById round-trip', () async {
    await insertParentDeck();
    final card = makeCard(front: 'Hello', back: 'World');
    await cardRepo.create(card);

    final fetched = await cardRepo.getById('card-1');
    expect(fetched, isNotNull);
    expect(fetched!.cardId, 'card-1');
    expect(fetched.front, 'Hello');
    expect(fetched.back, 'World');
    expect(fetched.cardState, CardState.newCard);
  });

  test('getByDeckId returns only matching deck cards', () async {
    await insertParentDeck(id: 'deck-a');
    await insertParentDeck(id: 'deck-b');
    await cardRepo.create(makeCard(id: 'c1', deckId: 'deck-a'));
    await cardRepo.create(makeCard(id: 'c2', deckId: 'deck-a'));
    await cardRepo.create(makeCard(id: 'c3', deckId: 'deck-b'));

    final cards = await cardRepo.getByDeckId('deck-a');
    expect(cards, hasLength(2));
    expect(cards.every((c) => c.deckId == 'deck-a'), isTrue);
  });

  test('getByDeckId supports limit and offset pagination', () async {
    await insertParentDeck(id: 'deck-a');
    final base = DateTime(2026, 1, 1, 0, 0, 0);
    for (var i = 1; i <= 5; i++) {
      await cardRepo.create(
        makeCard(
          id: 'c$i',
          deckId: 'deck-a',
          createdAt: base.add(Duration(seconds: i)),
        ),
      );
    }

    final page = await cardRepo.getByDeckId('deck-a', limit: 2, offset: 1);
    expect(page.map((c) => c.cardId).toList(), ['c2', 'c3']);
  });

  test('getDueCards includes past-due and excludes future-due', () async {
    await insertParentDeck();
    final now = DateTime.now();
    final pastDue = now.subtract(const Duration(hours: 1));
    final futureDue = now.add(const Duration(days: 1));

    await cardRepo.create(makeCard(id: 'past', dueDate: pastDue));
    await cardRepo.create(makeCard(id: 'future', dueDate: futureDue));

    final due = await cardRepo.getDueCards('deck-1', asOf: now);
    expect(due, hasLength(1));
    expect(due.first.cardId, 'past');
  });

  test('update persists changes and bumps updatedAt', () async {
    await insertParentDeck();
    final original = makeCard();
    await cardRepo.create(original);

    await Future<void>.delayed(const Duration(milliseconds: 10));

    final modified = original.copyWith(front: 'Updated Q', back: 'Updated A');
    final updated = await cardRepo.update(modified);
    expect(updated.front, 'Updated Q');
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);

    final fetched = await cardRepo.getById('card-1');
    expect(fetched!.front, 'Updated Q');
    expect(fetched.back, 'Updated A');
  });

  test('delete soft-removes card', () async {
    await insertParentDeck();
    await cardRepo.create(makeCard());
    await cardRepo.delete('card-1');

    final fetched = await cardRepo.getById('card-1');
    expect(fetched, isNull);
  });

  test('getById with unknown ID returns null', () async {
    final fetched = await cardRepo.getById('nonexistent');
    expect(fetched, isNull);
  });

  group('sync status', () {
    test('create sets syncStatus to pending', () async {
      await insertParentDeck();
      final card = makeCard();
      final created = await cardRepo.create(card);
      expect(created.syncStatus, SyncStatus.pending);

      final fetched = await cardRepo.getById('card-1');
      expect(fetched!.syncStatus, SyncStatus.pending);
    });

    test('update sets syncStatus to pending', () async {
      await insertParentDeck();
      await cardRepo.create(makeCard());
      final card = (await cardRepo.getById('card-1'))!;
      final updated = await cardRepo.update(card.copyWith(front: 'New Q'));
      expect(updated.syncStatus, SyncStatus.pending);
    });

    test('delete sets syncStatus to pending', () async {
      await insertParentDeck();
      await cardRepo.create(makeCard());
      await cardRepo.delete('card-1');

      final db = await helper.database;
      final rows = await db.query('cards',
          where: 'card_id = ?', whereArgs: ['card-1']);
      expect(rows.first['sync_status'], 'pending');
    });

    test('getUnsynced returns pending items only', () async {
      await insertParentDeck();
      await cardRepo.create(makeCard(id: 'c1'));
      await cardRepo.create(makeCard(id: 'c2'));

      await cardRepo.markSynced(['c1']);

      final unsynced = await cardRepo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.cardId, 'c2');
    });

    test('markSynced updates sync status', () async {
      await insertParentDeck();
      await cardRepo.create(makeCard(id: 'c1'));
      await cardRepo.create(makeCard(id: 'c2'));

      await cardRepo.markSynced(['c1', 'c2']);

      final unsynced = await cardRepo.getUnsynced();
      expect(unsynced, isEmpty);
    });

    test('getUnsynced includes deleted items', () async {
      await insertParentDeck();
      await cardRepo.create(makeCard());
      await cardRepo.delete('card-1');

      final unsynced = await cardRepo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.isDeleted, isTrue);
    });
  });
}
