import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_helper.dart';
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

  setUp(() {
    helper = DatabaseHelper.forTesting(dbName: 'test_deck_counts.db');
    deckRepo = DeckRepository(dbHelper: helper);
    cardRepo = CardRepository(dbHelper: helper);
  });

  tearDown(() async {
    await helper.close();
    final dbPath = await getDatabasesPath();
    await deleteDatabase(join(dbPath, 'test_deck_counts.db'));
  });

  Deck makeDeck({
    required String id,
    String? parentId,
    String name = 'Deck',
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

  Flashcard makeCard({
    required String id,
    required String deckId,
    DateTime? dueDate,
  }) {
    final now = DateTime.now();
    return Flashcard(
      cardId: id,
      deckId: deckId,
      front: 'Q',
      back: 'A',
      createdAt: now,
      updatedAt: now,
      dueDate: dueDate ?? now.subtract(const Duration(hours: 1)),
      stability: 0.0,
      difficulty: 0.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      cardState: CardState.newCard,
    );
  }

  // ── getDecksWithCounts ────────────────────────────────────────────

  group('getDecksWithCounts', () {
    test('returns empty list when no decks exist', () async {
      final results = await deckRepo.getDecksWithCounts();
      expect(results, isEmpty);
    });

    test('returns root decks with zero counts when no cards exist', () async {
      await deckRepo.create(makeDeck(id: 'root-1', name: 'Alpha'));
      await deckRepo.create(makeDeck(id: 'root-2', name: 'Beta'));

      final results = await deckRepo.getDecksWithCounts();
      expect(results, hasLength(2));
      for (final r in results) {
        expect(r.cardCount, 0);
        expect(r.dueCount, 0);
      }
    });

    test('counts cards directly in a root deck', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'root'));

      final results = await deckRepo.getDecksWithCounts();
      expect(results, hasLength(1));
      expect(results.first.cardCount, 2);
      expect(results.first.dueCount, 2);
    });

    test('aggregates counts across descendant decks', () async {
      // root → child → grandchild
      await deckRepo.create(makeDeck(id: 'root'));
      await deckRepo.create(makeDeck(id: 'child', parentId: 'root'));
      await deckRepo.create(makeDeck(id: 'grandchild', parentId: 'child'));

      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'child'));
      await cardRepo.create(makeCard(id: 'c3', deckId: 'grandchild'));
      await cardRepo.create(makeCard(id: 'c4', deckId: 'grandchild'));

      final results = await deckRepo.getDecksWithCounts();
      expect(results, hasLength(1));
      expect(results.first.deck.deckId, 'root');
      expect(results.first.cardCount, 4);
      expect(results.first.dueCount, 4);
    });

    test('only counts due cards in dueCount', () async {
      await deckRepo.create(makeDeck(id: 'root'));

      final now = DateTime.now();
      final pastDue = now.subtract(const Duration(hours: 1));
      final futureDue = now.add(const Duration(days: 30));

      await cardRepo.create(makeCard(id: 'due-1', deckId: 'root', dueDate: pastDue));
      await cardRepo.create(makeCard(id: 'due-2', deckId: 'root', dueDate: pastDue));
      await cardRepo.create(makeCard(id: 'not-due', deckId: 'root', dueDate: futureDue));

      final results = await deckRepo.getDecksWithCounts();
      expect(results.first.cardCount, 3);
      expect(results.first.dueCount, 2);
    });

    test('excludes soft-deleted cards from counts', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'root'));
      await cardRepo.delete('c2');

      final results = await deckRepo.getDecksWithCounts();
      expect(results.first.cardCount, 1);
      expect(results.first.dueCount, 1);
    });

    test('excludes soft-deleted descendant decks and their cards', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await deckRepo.create(makeDeck(id: 'child', parentId: 'root'));
      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'child'));

      // Soft-delete the child deck (cascades to its cards)
      await deckRepo.delete('child');

      final results = await deckRepo.getDecksWithCounts();
      expect(results.first.cardCount, 1);
      expect(results.first.dueCount, 1);
    });

    test('counts are independent across multiple root decks', () async {
      await deckRepo.create(makeDeck(id: 'root-a'));
      await deckRepo.create(makeDeck(id: 'root-b'));
      await deckRepo.create(makeDeck(id: 'child-b', parentId: 'root-b'));

      await cardRepo.create(makeCard(id: 'c1', deckId: 'root-a'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'root-b'));
      await cardRepo.create(makeCard(id: 'c3', deckId: 'child-b'));

      final results = await deckRepo.getDecksWithCounts();
      expect(results, hasLength(2));

      final a = results.firstWhere((r) => r.deck.deckId == 'root-a');
      final b = results.firstWhere((r) => r.deck.deckId == 'root-b');
      expect(a.cardCount, 1);
      expect(b.cardCount, 2);
    });

    test('excludes deleted root decks from results', () async {
      await deckRepo.create(makeDeck(id: 'keep'));
      await deckRepo.create(makeDeck(id: 'remove'));
      await deckRepo.delete('remove');

      final results = await deckRepo.getDecksWithCounts();
      expect(results, hasLength(1));
      expect(results.first.deck.deckId, 'keep');
    });

    test('parentId parameter returns children with counts', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await deckRepo.create(makeDeck(id: 'child-1', parentId: 'root'));
      await deckRepo.create(makeDeck(id: 'child-2', parentId: 'root'));
      await deckRepo.create(makeDeck(id: 'grandchild', parentId: 'child-1'));

      await cardRepo.create(makeCard(id: 'c1', deckId: 'child-1'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'grandchild'));
      await cardRepo.create(makeCard(id: 'c3', deckId: 'child-2'));

      final children = await deckRepo.getDecksWithCounts(parentId: 'root');
      expect(children, hasLength(2));

      final child1 = children.firstWhere((r) => r.deck.deckId == 'child-1');
      final child2 = children.firstWhere((r) => r.deck.deckId == 'child-2');

      // child-1 has 1 direct card + 1 grandchild card = 2
      expect(child1.cardCount, 2);
      // child-2 has 1 direct card
      expect(child2.cardCount, 1);
    });

    test('parentId returns empty list when no children exist', () async {
      await deckRepo.create(makeDeck(id: 'leaf'));

      final children = await deckRepo.getDecksWithCounts(parentId: 'leaf');
      expect(children, isEmpty);
    });
  });

  // ── getAggregatedCounts ───────────────────────────────────────────

  group('getAggregatedCounts', () {
    test('returns zero counts for a deck with no cards', () async {
      await deckRepo.create(makeDeck(id: 'empty'));

      final counts = await deckRepo.getAggregatedCounts('empty');
      expect(counts.cardCount, 0);
      expect(counts.dueCount, 0);
    });

    test('counts cards in a leaf deck', () async {
      await deckRepo.create(makeDeck(id: 'leaf'));
      await cardRepo.create(makeCard(id: 'c1', deckId: 'leaf'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'leaf'));

      final counts = await deckRepo.getAggregatedCounts('leaf');
      expect(counts.cardCount, 2);
      expect(counts.dueCount, 2);
    });

    test('aggregates across full descendant tree', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await deckRepo.create(makeDeck(id: 'child', parentId: 'root'));
      await deckRepo.create(makeDeck(id: 'grandchild', parentId: 'child'));

      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'child'));
      await cardRepo.create(makeCard(id: 'c3', deckId: 'grandchild'));

      final counts = await deckRepo.getAggregatedCounts('root');
      expect(counts.cardCount, 3);
      expect(counts.dueCount, 3);
    });

    test('separates due from not-due cards', () async {
      await deckRepo.create(makeDeck(id: 'root'));

      final now = DateTime.now();
      await cardRepo.create(makeCard(
        id: 'due',
        deckId: 'root',
        dueDate: now.subtract(const Duration(hours: 1)),
      ));
      await cardRepo.create(makeCard(
        id: 'not-due',
        deckId: 'root',
        dueDate: now.add(const Duration(days: 30)),
      ));

      final counts = await deckRepo.getAggregatedCounts('root');
      expect(counts.cardCount, 2);
      expect(counts.dueCount, 1);
    });

    test('excludes soft-deleted cards', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'root'));
      await cardRepo.delete('c2');

      final counts = await deckRepo.getAggregatedCounts('root');
      expect(counts.cardCount, 1);
      expect(counts.dueCount, 1);
    });

    test('excludes soft-deleted descendant decks', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await deckRepo.create(makeDeck(id: 'child', parentId: 'root'));
      await cardRepo.create(makeCard(id: 'c1', deckId: 'root'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'child'));

      await deckRepo.delete('child');

      final counts = await deckRepo.getAggregatedCounts('root');
      expect(counts.cardCount, 1);
      expect(counts.dueCount, 1);
    });

    test('counts only subtree of specified deck, not siblings', () async {
      await deckRepo.create(makeDeck(id: 'root'));
      await deckRepo.create(makeDeck(id: 'sibling-a', parentId: 'root'));
      await deckRepo.create(makeDeck(id: 'sibling-b', parentId: 'root'));

      await cardRepo.create(makeCard(id: 'c1', deckId: 'sibling-a'));
      await cardRepo.create(makeCard(id: 'c2', deckId: 'sibling-b'));

      final counts = await deckRepo.getAggregatedCounts('sibling-a');
      expect(counts.cardCount, 1);
      expect(counts.dueCount, 1);
    });
  });
}
