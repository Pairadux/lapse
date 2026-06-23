import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/auth/application/auth_service.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/domain/deck_with_counts.dart';
import 'package:sqflite/sqflite.dart';

class DeckRepository {
  final DatabaseHelper _dbHelper;
  final AuthService _authService;

  DeckRepository({DatabaseHelper? dbHelper, AuthService? authService})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance,
      _authService = authService ?? AuthService();

  Future<Deck> create(Deck deck, {Transaction? txn}) async {
    final db = txn ?? await _dbHelper.database;
    final userId = deck.userId.isEmpty
        ? await _authService.getCurrentUserId()
        : deck.userId;
    final syncReady = deck.copyWith(
      syncStatus: SyncStatus.pending,
      userId: userId,
    );
    await db.insert(DatabaseConstants.tableDecks, syncReady.toMap());
    return syncReady;
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
    final updated = deck.copyWith(
      updatedAt: DateTime.now(),
      syncStatus: SyncStatus.pending,
    );
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
    final rows = await db.rawQuery(
      '''
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
    ''',
      [deckId],
    );
    return rows.map((r) => r[DatabaseConstants.colDeckId] as String).toList();
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

  /// Returns decks at the given tree level with aggregated card/due counts
  /// across all descendants in a single recursive query.
  /// Pass [parentId] = null for root decks, or a deck ID for its children.
  Future<List<DeckWithCounts>> getDecksWithCounts({String? parentId}) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    final parentCondition = parentId != null
        ? '${DatabaseConstants.colParentId} = ?'
        : '${DatabaseConstants.colParentId} IS NULL';
    final args = parentId != null ? [parentId, now] : [now];

    final rows = await db.rawQuery('''
      WITH RECURSIVE
        anchor_decks(${DatabaseConstants.colDeckId}) AS (
          SELECT ${DatabaseConstants.colDeckId}
          FROM ${DatabaseConstants.tableDecks}
          WHERE $parentCondition AND ${DatabaseConstants.colIsDeleted} = 0
        ),
        descendants(anchor_id, ${DatabaseConstants.colDeckId}) AS (
          SELECT ${DatabaseConstants.colDeckId}, ${DatabaseConstants.colDeckId}
          FROM anchor_decks
          UNION ALL
          SELECT dt.anchor_id, d.${DatabaseConstants.colDeckId}
          FROM ${DatabaseConstants.tableDecks} d
          INNER JOIN descendants dt
            ON d.${DatabaseConstants.colParentId} = dt.${DatabaseConstants.colDeckId}
          WHERE d.${DatabaseConstants.colIsDeleted} = 0
        )
      SELECT
        d.*,
        COALESCE(agg.card_count, 0) AS card_count,
        COALESCE(agg.due_count, 0) AS due_count
      FROM anchor_decks a
      INNER JOIN ${DatabaseConstants.tableDecks} d
        ON d.${DatabaseConstants.colDeckId} = a.${DatabaseConstants.colDeckId}
      LEFT JOIN (
        SELECT
          dt.anchor_id,
          COUNT(c.${DatabaseConstants.colCardId}) AS card_count,
          SUM(CASE WHEN c.${DatabaseConstants.colDueDate} <= ? THEN 1 ELSE 0 END) AS due_count
        FROM descendants dt
        LEFT JOIN ${DatabaseConstants.tableCards} c
          ON c.${DatabaseConstants.colDeckId} = dt.${DatabaseConstants.colDeckId}
          AND c.${DatabaseConstants.colIsDeleted} = 0
        GROUP BY dt.anchor_id
      ) agg ON d.${DatabaseConstants.colDeckId} = agg.anchor_id
      ORDER BY d.${DatabaseConstants.colCreatedAt}
    ''', args);

    return rows
        .map(
          (row) => DeckWithCounts(
            deck: Deck.fromMap(row),
            cardCount: row['card_count'] as int,
            dueCount: row['due_count'] as int,
          ),
        )
        .toList();
  }

  /// Returns (cardCount, dueCount) for a deck and all its descendants
  /// in a single recursive query.
  Future<({int cardCount, int dueCount})> getAggregatedCounts(
    String deckId,
  ) async {
    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();

    final rows = await db.rawQuery(
      '''
      WITH RECURSIVE descendants(${DatabaseConstants.colDeckId}) AS (
        SELECT ${DatabaseConstants.colDeckId}
        FROM ${DatabaseConstants.tableDecks}
        WHERE ${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colIsDeleted} = 0
        UNION ALL
        SELECT d.${DatabaseConstants.colDeckId}
        FROM ${DatabaseConstants.tableDecks} d
        INNER JOIN descendants dt
          ON d.${DatabaseConstants.colParentId} = dt.${DatabaseConstants.colDeckId}
        WHERE d.${DatabaseConstants.colIsDeleted} = 0
      )
      SELECT
        COUNT(c.${DatabaseConstants.colCardId}) AS card_count,
        COALESCE(SUM(CASE WHEN c.${DatabaseConstants.colDueDate} <= ? THEN 1 ELSE 0 END), 0) AS due_count
      FROM descendants dt
      LEFT JOIN ${DatabaseConstants.tableCards} c
        ON c.${DatabaseConstants.colDeckId} = dt.${DatabaseConstants.colDeckId}
        AND c.${DatabaseConstants.colIsDeleted} = 0
    ''',
      [deckId, now],
    );

    final row = rows.first;
    return (
      cardCount: row['card_count'] as int,
      dueCount: row['due_count'] as int,
    );
  }

  /// Returns all decks with pending sync status.
  Future<List<Deck>> getUnsynced() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableDecks,
      where: '${DatabaseConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.synced.name],
    );
    return rows.map(Deck.fromMap).toList();
  }

  /// Marks the given decks as synced, guarded by [updated_at] to prevent
  /// a TOCTOU race: if a row was modified between push and markSynced,
  /// the guard ensures it stays pending for the next sync cycle.
  Future<void> markSynced(Map<String, String> idToUpdatedAt) async {
    if (idToUpdatedAt.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final entry in idToUpdatedAt.entries) {
        await txn.update(
          DatabaseConstants.tableDecks,
          {DatabaseConstants.colSyncStatus: SyncStatus.synced.name},
          where:
              '${DatabaseConstants.colDeckId} = ? AND ${DatabaseConstants.colUpdatedAt} = ?',
          whereArgs: [entry.key, entry.value],
        );
      }
    });
  }

  /// Soft-deletes [deckId], all descendant decks, and all their cards
  /// in a single transaction.
  Future<void> delete(String deckId) async {
    await bulkDelete([deckId]);
  }

  /// Bulk soft-delete for decks and each selected deck's descendants.
  Future<void> bulkDelete(List<String> deckIds) async {
    if (deckIds.isEmpty) return;

    final db = await _dbHelper.database;
    final seedPlaceholders = List.filled(deckIds.length, '?').join(', ');
    final descendantRows = await db.rawQuery(
      '''
      WITH RECURSIVE descendants(${DatabaseConstants.colDeckId}) AS (
        SELECT ${DatabaseConstants.colDeckId}
        FROM ${DatabaseConstants.tableDecks}
        WHERE ${DatabaseConstants.colDeckId} IN ($seedPlaceholders)
          AND ${DatabaseConstants.colIsDeleted} = 0
        UNION ALL
        SELECT d.${DatabaseConstants.colDeckId}
        FROM ${DatabaseConstants.tableDecks} d
        INNER JOIN descendants dt
          ON d.${DatabaseConstants.colParentId} = dt.${DatabaseConstants.colDeckId}
        WHERE d.${DatabaseConstants.colIsDeleted} = 0
      )
      SELECT DISTINCT ${DatabaseConstants.colDeckId} FROM descendants
      ''',
      deckIds,
    );
    final allIds = descendantRows
        .map((row) => row[DatabaseConstants.colDeckId] as String)
        .toList(growable: false);
    if (allIds.isEmpty) return;

    final now = DateTime.now().toUtc().toIso8601String();
    final deletedFields = {
      DatabaseConstants.colIsDeleted: 1,
      DatabaseConstants.colUpdatedAt: now,
      DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
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

  /// Bulk-moves non-deleted decks to [newParentId] in a single transaction.
  Future<void> moveDecks(List<String> deckIds, String? newParentId) async {
    if (deckIds.isEmpty) return;

    final db = await _dbHelper.database;
    final now = DateTime.now().toUtc().toIso8601String();
    final placeholders = List.filled(deckIds.length, '?').join(', ');

    await db.transaction((txn) async {
      await txn.update(
        DatabaseConstants.tableDecks,
        {
          DatabaseConstants.colParentId: newParentId,
          DatabaseConstants.colUpdatedAt: now,
          DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
        },
        where:
            '${DatabaseConstants.colDeckId} IN ($placeholders) '
            'AND ${DatabaseConstants.colIsDeleted} = 0',
        whereArgs: deckIds,
      );
    });
  }

  /// Finds a deck by its full path (e.g., "Parent::Child::Grandchild").
  /// Creates the deck hierarchy if it doesn't exist.
  ///
  /// When [parentId] is provided, the first path segment is created under
  /// that deck instead of at the root.
  Future<Deck> getOrCreateByPath(String path, {String? parentId}) async {
    final segments = path.split('::');
    if (path.trim().isEmpty) throw ArgumentError('Path cannot be empty');

    final db = await _dbHelper.database;

    return await db.transaction((txn) async {
      Future<Deck> getOrCreate(String name, String? deckParentId) async {
        final rows = await txn.query(
          DatabaseConstants.tableDecks,
          where: '${DatabaseConstants.colDeckName} = ? AND '
              '${DatabaseConstants.colParentId} ${deckParentId == null ? 'IS NULL' : '= ?'} AND '
              '${DatabaseConstants.colIsDeleted} = 0',
          whereArgs: [name, ?deckParentId],
        );

        if (rows.isNotEmpty) return Deck.fromMap(rows.first);

        final deck = Deck.create(deckName: name, parentId: deckParentId);
        return await create(deck, txn: txn);
      }

      var current = await getOrCreate(segments[0], parentId);
      for (final segment in segments.skip(1)) {
        current = await getOrCreate(segment, current.deckId);
      }
      return current;
    });
  }
}
