import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_helper.dart';
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
}
