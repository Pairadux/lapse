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

  /// Returns [deckId] plus all descendant deck IDs via a single recursive CTE.
  Future<List<String>> getDescendantIds(String deckId) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      WITH RECURSIVE descendants(${DatabaseConstants.colDeckId}) AS (
        SELECT ${DatabaseConstants.colDeckId}
          FROM ${DatabaseConstants.tableDecks}
         WHERE ${DatabaseConstants.colDeckId} = ?
           AND ${DatabaseConstants.colIsDeleted} = 0
        UNION ALL
        SELECT d.${DatabaseConstants.colDeckId}
          FROM ${DatabaseConstants.tableDecks} d
         INNER JOIN descendants dt
            ON d.${DatabaseConstants.colParentId} = dt.${DatabaseConstants.colDeckId}
         WHERE d.${DatabaseConstants.colIsDeleted} = 0
      )
      SELECT ${DatabaseConstants.colDeckId} FROM descendants
    ''', [deckId]);
    return rows
        .map((r) => r[DatabaseConstants.colDeckId] as String)
        .toList();
  }

  /// Returns only root-level (no parent) decks, ordered by creation date.
  Future<List<Deck>> getRootDecks() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDecks,
      where:
          '${DatabaseConstants.colParentId} IS NULL AND ${DatabaseConstants.colIsDeleted} = 0',
      orderBy: DatabaseConstants.colCreatedAt,
    );
    return rows.map(Deck.fromMap).toList();
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

  /// Returns true if a non-deleted deck with [name] exists at the same
  /// parent level. Use [excludeDeckId] to skip self when editing.
  Future<bool> nameExistsAtLevel({
    required String name,
    String? parentId,
    String? excludeDeckId,
  }) async {
    final db = await _dbHelper.database;
    final whereParts = <String>[
      '${DatabaseConstants.colIsDeleted} = 0',
      'LOWER(${DatabaseConstants.colDeckName}) = LOWER(?)',
    ];
    final whereArgs = <Object>[name];

    if (parentId != null) {
      whereParts.add('${DatabaseConstants.colParentId} = ?');
      whereArgs.add(parentId);
    } else {
      whereParts.add('${DatabaseConstants.colParentId} IS NULL');
    }

    if (excludeDeckId != null) {
      whereParts.add('${DatabaseConstants.colDeckId} != ?');
      whereArgs.add(excludeDeckId);
    }

    final rows = await db.query(
      DatabaseConstants.tableDecks,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  /// Soft-deletes [deckId], all descendant decks, and all their cards
  /// in a single transaction.
  Future<void> delete(String deckId) async {
    final allIds = await getDescendantIds(deckId);
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final deletedFields = {
      DatabaseConstants.colIsDeleted: 1,
      DatabaseConstants.colUpdatedAt: now,
    };
    final placeholders = List.filled(allIds.length, '?').join(', ');

    await db.transaction((txn) async {
      await txn.update(
        DatabaseConstants.tableDecks,
        deletedFields,
        where: '${DatabaseConstants.colDeckId} IN ($placeholders)',
        whereArgs: allIds,
      );
      await txn.update(
        DatabaseConstants.tableCards,
        deletedFields,
        where: '${DatabaseConstants.colDeckId} IN ($placeholders)',
        whereArgs: allIds,
      );
    });
  }
}
