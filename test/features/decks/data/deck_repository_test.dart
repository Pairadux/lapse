import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  late String dbName;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    dbName = 'test_deck_repo_${DateTime.now().microsecondsSinceEpoch}.db';
    helper = DatabaseHelper.forTesting(dbName: dbName);
    repo = DeckRepository(dbHelper: helper);
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, dbName));
  });

  Deck makeDeck({
    String id = 'deck-1',
    String? parentId,
    String name = 'Test Deck',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final now = DateTime.now();
    final created = createdAt ?? now;
    return Deck(deckId: id, parentId: parentId, deckName: name, createdAt: created, updatedAt: updatedAt ?? created);
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
      final a = await repo.getById('a');
      await repo.markSynced({
        'a': a!.updatedAt.toUtc().toIso8601String(),
      });

      final unsynced = await repo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.deckId, 'b');
    });

    test('markSynced updates sync status', () async {
      await repo.create(makeDeck(id: 'a'));
      await repo.create(makeDeck(id: 'b'));

      final a = await repo.getById('a');
      final b = await repo.getById('b');
      await repo.markSynced({
        'a': a!.updatedAt.toUtc().toIso8601String(),
        'b': b!.updatedAt.toUtc().toIso8601String(),
      });

      final unsynced = await repo.getUnsynced();
      expect(unsynced, isEmpty);

      final aAfter = await repo.getById('a');
      expect(aAfter!.syncStatus, SyncStatus.synced);
    });

    test('markSynced with empty map is a no-op', () async {
      await repo.markSynced({});
      // Should not throw
    });

    test('markSynced skips rows modified after push (TOCTOU guard)', () async {
      await repo.create(makeDeck(id: 'a'));
      final original = await repo.getById('a');
      final pushedTimestamp = original!.updatedAt.toUtc().toIso8601String();

      // Simulate user editing the deck after push read it but before markSynced
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.update(original.copyWith(deckName: 'Edited'));

      // markSynced with the OLD timestamp should not mark as synced
      await repo.markSynced({'a': pushedTimestamp});

      final deck = await repo.getById('a');
      expect(deck!.syncStatus, SyncStatus.pending);
      expect(deck.deckName, 'Edited');
    });

    test('markSynced applies only to matching timestamps', () async {
      await repo.create(makeDeck(id: 'a'));
      await repo.create(makeDeck(id: 'b'));

      final a = await repo.getById('a');
      final b = await repo.getById('b');
      final aTimestamp = a!.updatedAt.toUtc().toIso8601String();

      // Edit 'b' so its timestamp no longer matches
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await repo.update(b!.copyWith(deckName: 'Edited B'));

      await repo.markSynced({
        'a': aTimestamp,
        'b': b.updatedAt.toUtc().toIso8601String(), // stale
      });

      final aAfter = await repo.getById('a');
      final bAfter = await repo.getById('b');
      expect(aAfter!.syncStatus, SyncStatus.synced); // matched
      expect(bAfter!.syncStatus, SyncStatus.pending); // stale, skipped
    });

    test('getUnsynced includes deleted items', () async {
      await repo.create(makeDeck(id: 'a'));
      await repo.delete('a');

      final unsynced = await repo.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.isDeleted, isTrue);
    });
  });

  group('getRootDecks', () {
    test('returns only decks with no parent', () async {
      await repo.create(makeDeck(id: 'root-1', parentId: null));
      await repo.create(makeDeck(id: 'root-2', parentId: null));
      await repo.create(makeDeck(id: 'child', parentId: 'root-1'));

      final roots = await repo.getRootDecks();
      expect(roots, hasLength(2));
      expect(roots.map((d) => d.deckId).toSet(), {'root-1', 'root-2'});
    });

    test('excludes deleted root decks', () async {
      await repo.create(makeDeck(id: 'root-1'));
      await repo.create(makeDeck(id: 'root-2'));
      await repo.delete('root-1');

      final roots = await repo.getRootDecks();
      expect(roots, hasLength(1));
      expect(roots.first.deckId, 'root-2');
    });

    test('returns empty list when no root decks exist', () async {
      final roots = await repo.getRootDecks();
      expect(roots, isEmpty);
    });
  });

  group('getDescendantIds', () {
    test('returns parent plus all descendants (recursive)', () async {
      // Create: parent → child1, child2 → grandchild
      await repo.create(makeDeck(id: 'parent'));
      await repo.create(makeDeck(id: 'child-1', parentId: 'parent'));
      await repo.create(makeDeck(id: 'child-2', parentId: 'parent'));
      await repo.create(makeDeck(id: 'grandchild', parentId: 'child-1'));
      await repo.create(makeDeck(id: 'unrelated'));

      final descendants = await repo.getDescendantIds('parent');
      expect(descendants.length, 4); // parent + 2 children + 1 grandchild
      expect(descendants.toSet(), {'parent', 'child-1', 'child-2', 'grandchild'});
    });

    test('returns only the deck itself if it has no children', () async {
      await repo.create(makeDeck(id: 'leaf'));

      final descendants = await repo.getDescendantIds('leaf');
      expect(descendants, ['leaf']);
    });

    test('excludes deleted descendants', () async {
      await repo.create(makeDeck(id: 'parent'));
      await repo.create(makeDeck(id: 'child-1', parentId: 'parent'));
      await repo.create(makeDeck(id: 'child-2', parentId: 'parent'));
      await repo.delete('child-1');

      final descendants = await repo.getDescendantIds('parent');
      expect(descendants.toSet(), {'parent', 'child-2'});
    });

    test('returns empty list for non-existent deck ID', () async {
      final descendants = await repo.getDescendantIds('nonexistent');
      expect(descendants, isEmpty);
    });

    test('handles deep nesting (5+ levels)', () async {
      var parentId = 'level-0';
      await repo.create(makeDeck(id: parentId));

      for (int i = 1; i <= 5; i++) {
        final newId = 'level-$i';
        await repo.create(makeDeck(id: newId, parentId: parentId));
        parentId = newId;
      }

      final descendants = await repo.getDescendantIds('level-0');
      expect(descendants, hasLength(6)); // level-0 through level-5
    });
  });

  group('delete with cascade', () {
    test('soft-delete parent marks all descendants as deleted', () async {
      // Create tree: parent → child → grandchild
      await repo.create(makeDeck(id: 'parent'));
      await repo.create(makeDeck(id: 'child', parentId: 'parent'));
      await repo.create(makeDeck(id: 'grandchild', parentId: 'child'));

      // Delete parent
      await repo.delete('parent');

      // Verify all are gone (soft-deleted)
      expect(await repo.getById('parent'), isNull);
      expect(await repo.getById('child'), isNull);
      expect(await repo.getById('grandchild'), isNull);

      // Verify they don't appear in getAll/getChildren
      expect(await repo.getAll(), isEmpty);
      expect(await repo.getChildren('parent'), isEmpty);
    });

    test('delete does not affect sibling branches', () async {
      // Create: parent → child-a, child-b
      await repo.create(makeDeck(id: 'parent'));
      await repo.create(makeDeck(id: 'child-a', parentId: 'parent'));
      await repo.create(makeDeck(id: 'child-b', parentId: 'parent'));

      await repo.delete('child-a');

      // child-b should still exist
      final remaining = await repo.getChildren('parent');
      expect(remaining, hasLength(1));
      expect(remaining.first.deckId, 'child-b');
    });
  });

  group('getChildren edge cases', () {
    test('returns empty list for non-existent parent', () async {
      final children = await repo.getChildren('nonexistent');
      expect(children, isEmpty);
    });

    test('returns empty list when parent has no children', () async {
      await repo.create(makeDeck(id: 'parent'));

      final children = await repo.getChildren('parent');
      expect(children, isEmpty);
    });
  });
}
