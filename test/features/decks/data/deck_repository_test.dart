import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper helper;
  late DeckRepository repo;

  setUp(() {
    helper = DatabaseHelper.forTesting(dbName: 'test_deck_repo.db');
    repo = DeckRepository(dbHelper: helper);
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, 'test_deck_repo.db'));
  });

  Deck makeDeck({
    String id = 'deck-1',
    String? parentId,
    String name = 'Test Deck',
  }) {
    final now = DateTime.now();
    return Deck(
      deckId: id,
      parentId: parentId,
      deckName: name,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('create + getById round-trip', () async {
    final deck = makeDeck();
    await repo.create(deck);

    final fetched = await repo.getById('deck-1');
    expect(fetched, isNotNull);
    expect(fetched!.deckId, 'deck-1');
    expect(fetched.deckName, 'Test Deck');
    expect(fetched.isDeleted, false);
  });

  test('getAll excludes deleted decks', () async {
    await repo.create(makeDeck(id: 'a', name: 'Active'));
    await repo.create(makeDeck(id: 'b', name: 'To Delete'));
    await repo.delete('b');

    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.first.deckId, 'a');
  });

  test('getChildren returns only direct children', () async {
    await repo.create(makeDeck(id: 'parent'));
    await repo.create(makeDeck(id: 'child-1', parentId: 'parent'));
    await repo.create(makeDeck(id: 'child-2', parentId: 'parent'));
    await repo.create(makeDeck(id: 'other'));

    final children = await repo.getChildren('parent');
    expect(children, hasLength(2));
    expect(children.map((d) => d.deckId).toSet(), {'child-1', 'child-2'});
  });

  test('update persists name change and bumps updatedAt', () async {
    final original = makeDeck();
    await repo.create(original);

    // Small delay so updatedAt will differ
    await Future<void>.delayed(const Duration(milliseconds: 10));

    final renamed = original.copyWith(deckName: 'Renamed');
    final updated = await repo.update(renamed);
    expect(updated.deckName, 'Renamed');
    expect(updated.updatedAt.isAfter(original.updatedAt), isTrue);

    final fetched = await repo.getById('deck-1');
    expect(fetched!.deckName, 'Renamed');
  });

  test('delete makes getById return null', () async {
    await repo.create(makeDeck());
    await repo.delete('deck-1');

    final fetched = await repo.getById('deck-1');
    expect(fetched, isNull);
  });

  test('getById with unknown ID returns null', () async {
    final fetched = await repo.getById('nonexistent');
    expect(fetched, isNull);
  });

  group('sync status', () {
    test('create sets syncStatus to pending', () async {
      final deck = makeDeck();
      final created = await repo.create(deck);
      expect(created.syncStatus, SyncStatus.pending);

      final fetched = await repo.getById('deck-1');
      expect(fetched!.syncStatus, SyncStatus.pending);
    });

    test('update sets syncStatus to pending', () async {
      await repo.create(makeDeck());
      final deck = (await repo.getById('deck-1'))!;
      final updated = await repo.update(deck.copyWith(deckName: 'Renamed'));
      expect(updated.syncStatus, SyncStatus.pending);
    });

    test('delete sets syncStatus to pending', () async {
      await repo.create(makeDeck());
      await repo.delete('deck-1');

      // Query raw to see deleted row
      final db = await helper.database;
      final rows = await db.query('decks',
          where: 'deck_id = ?', whereArgs: ['deck-1']);
      expect(rows.first['sync_status'], 'pending');
    });

    test('getUnsynced returns pending items only', () async {
      await repo.create(makeDeck(id: 'a'));
      await repo.create(makeDeck(id: 'b'));

      // Mark 'a' as synced
      await repo.markSynced(['a']);

      final unsynced = await repo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.deckId, 'b');
    });

    test('markSynced updates sync status', () async {
      await repo.create(makeDeck(id: 'a'));
      await repo.create(makeDeck(id: 'b'));

      await repo.markSynced(['a', 'b']);

      final unsynced = await repo.getUnsynced();
      expect(unsynced, isEmpty);

      final a = await repo.getById('a');
      expect(a!.syncStatus, SyncStatus.synced);
    });

    test('markSynced with empty list is a no-op', () async {
      await repo.markSynced([]);
      // Should not throw
    });

    test('getUnsynced includes deleted items', () async {
      await repo.create(makeDeck(id: 'a'));
      await repo.delete('a');

      final unsynced = await repo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.isDeleted, isTrue);
    });
  });
}
