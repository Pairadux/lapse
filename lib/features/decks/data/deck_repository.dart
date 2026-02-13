import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/features/decks/domain/deck.dart';

class DeckRepository {
  final DatabaseHelper _dbHelper;

  DeckRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Deck> create(Deck deck) async {
    final db = await _dbHelper.database;
    await db.insert(DatabaseConstants.tableDecks, deck.toMap());
    return deck;
  }

  Future<Deck?> getById(String deckId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDecks,
      where:
          '${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colIsDeleted} = 0',
      whereArgs: [deckId],
    );
    if (rows.isEmpty) return null;
    return Deck.fromMap(rows.first);
  }

  Future<List<Deck>> getAll() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDecks,
      where: '${DatabaseConstants.colIsDeleted} = 0',
      orderBy: DatabaseConstants.colCreatedAt,
    );
    return rows.map(Deck.fromMap).toList();
  }

  Future<List<Deck>> getChildren(String parentId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDecks,
      where:
          '${DatabaseConstants.colParentId} = ? AND ${DatabaseConstants.colIsDeleted} = 0',
      whereArgs: [parentId],
    );
    return rows.map(Deck.fromMap).toList();
  }

  Future<Deck> update(Deck deck) async {
    final db = await _dbHelper.database;
    final updated = deck.copyWith(updatedAt: DateTime.now());
    await db.update(
      DatabaseConstants.tableDecks,
      updated.toMap(),
      where: '${DatabaseConstants.colDeckId} = ?',
      whereArgs: [deck.deckId],
    );
    return updated;
  }

  /// Walks parentId chain from [deckId] up to root, returns list ordered root-first.
  Future<List<Deck>> getAncestors(String deckId) async {
    final ancestors = <Deck>[];
    var current = await getById(deckId);
    while (current != null && current.parentId != null) {
      final parent = await getById(current.parentId!);
      if (parent == null) break;
      ancestors.insert(0, parent);
      current = parent;
    }
    return ancestors;
  }

  Future<void> delete(String deckId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DatabaseConstants.tableDecks,
      {
        DatabaseConstants.colIsDeleted: 1,
        DatabaseConstants.colUpdatedAt: now,
      },
      where: '${DatabaseConstants.colDeckId} = ?',
      whereArgs: [deckId],
    );
  }
}
