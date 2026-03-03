import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

class CardRepository {
  final DatabaseHelper _dbHelper;

  CardRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  Future<Flashcard> create(Flashcard card) async {
    final db = await _dbHelper.database;
    await db.insert(DatabaseConstants.tableCards, card.toMap());
    return card;
  }

  Future<Flashcard?> getById(String cardId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableCards,
      where:
          '${DatabaseConstants.colCardId} = ? AND ${DatabaseConstants.colIsDeleted} = 0',
      whereArgs: [cardId],
    );
    if (rows.isEmpty) return null;
    return Flashcard.fromMap(rows.first);
  }

  Future<List<Flashcard>> getByDeckId(String deckId) async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableCards,
      where:
          '${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colIsDeleted} = 0',
      whereArgs: [deckId],
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// Returns non-deleted cards due on or before [asOf] (defaults to now),
  /// ordered by due date. Uses the `idx_cards_deck_due` composite index.
  Future<List<Flashcard>> getDueCards(String deckId, {DateTime? asOf}) async {
    final db = await _dbHelper.database;
    final cutoff = (asOf ?? DateTime.now()).toUtc().toIso8601String();
    final rows = await db.query(
      DatabaseConstants.tableCards,
      where:
          '${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colIsDeleted} = 0 AND ${DatabaseConstants.colDueDate} <= ?',
      whereArgs: [deckId, cutoff],
      orderBy: DatabaseConstants.colDueDate,
    );
    return rows.map(Flashcard.fromMap).toList();
  }

  /// Returns the number of non-deleted cards in [deckId].
  Future<int> countByDeckId(String deckId) async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DatabaseConstants.tableCards} '
      'WHERE ${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colIsDeleted} = 0',
      [deckId],
    );
    return result.first['c'] as int;
  }

  /// Returns the number of non-deleted cards due on or before now in [deckId].
  Future<int> countDueByDeckId(String deckId) async {
    final db = await _dbHelper.database;
    final cutoff = DateTime.now().toUtc().toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM ${DatabaseConstants.tableCards} '
      'WHERE ${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colIsDeleted} = 0 '
      'AND ${DatabaseConstants.colDueDate} <= ?',
      [deckId, cutoff],
    );
    return result.first['c'] as int;
  }

  /// Returns the number of non-deleted cards due on each calendar day.
  /// Keys are dates (time portion zeroed), values are counts.
  Future<Map<DateTime, int>> getDueDateCounts() async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery(
      'SELECT DATE(${DatabaseConstants.colDueDate}) AS day, COUNT(*) AS c '
      'FROM ${DatabaseConstants.tableCards} '
      'WHERE ${DatabaseConstants.colIsDeleted} = 0 '
      'GROUP BY day',
    );
    return {
      for (final row in rows)
        DateTime.parse(row['day'] as String): row['c'] as int,
    };
  }

  /// Returns true if a non-deleted card with [front] text exists in [deckId].
  /// Use [excludeCardId] to skip self when editing.
  Future<bool> frontExistsInDeck({
    required String front,
    required String deckId,
    String? excludeCardId,
  }) async {
    final db = await _dbHelper.database;
    final whereParts = <String>[
      '${DatabaseConstants.colIsDeleted} = 0',
      '${DatabaseConstants.colDeckId} = ?',
      'LOWER(${DatabaseConstants.colFront}) = LOWER(?)',
    ];
    final whereArgs = <Object>[deckId, front.trim()];

    if (excludeCardId != null) {
      whereParts.add('${DatabaseConstants.colCardId} != ?');
      whereArgs.add(excludeCardId);
    }

    final rows = await db.query(
      DatabaseConstants.tableCards,
      where: whereParts.join(' AND '),
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Flashcard> update(Flashcard card) async {
    final db = await _dbHelper.database;
    final updated = card.copyWith(updatedAt: DateTime.now());
    await db.update(
      DatabaseConstants.tableCards,
      updated.toMap(),
      where: '${DatabaseConstants.colCardId} = ?',
      whereArgs: [card.cardId],
    );
    return updated;
  }

  Future<void> delete(String cardId) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    await db.update(
      DatabaseConstants.tableCards,
      {
        DatabaseConstants.colIsDeleted: 1,
        DatabaseConstants.colUpdatedAt: now,
      },
      where: '${DatabaseConstants.colCardId} = ?',
      whereArgs: [cardId],
    );
  }
}
