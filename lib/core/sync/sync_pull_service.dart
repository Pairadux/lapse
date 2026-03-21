import 'dart:developer' as dev;

import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/core/supabase/supabase_config.dart';
import 'package:lapse/core/sync/sync_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pulls remote changes from Supabase into local SQLite.
///
/// Uses `last_pull_timestamp` to fetch only rows changed since the last
/// successful pull. Queries are paginated to avoid PostgREST's `max_rows`
/// limit (default 1000). Conflict resolution is last-write-wins on
/// `updated_at` when a local row has pending changes; otherwise remote wins.
class SyncPullService {
  static const _lastPullKey = 'last_pull_timestamp';

  /// Page size for paginated Supabase queries. Matches PostgREST's default
  /// `max_rows` (1000) so pagination works without server config changes.
  static const _pageSize = 1000;

  final DatabaseHelper _dbHelper;
  final SupabaseClient? _clientOverride;

  SyncPullService({DatabaseHelper? dbHelper, SupabaseClient? client})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance,
        _clientOverride = client;

  /// Pulls all remote changes since the last successful pull.
  ///
  /// Returns `true` if all tables pulled successfully, `false` if any failed.
  /// The pull timestamp is only updated when all tables succeed.
  Future<bool> pull() async {
    final client = _clientOverride;
    if (client == null) {
      if (!SupabaseConfig.isConfigured) return false;
      if (SupabaseConfig.client.auth.currentSession == null) return false;
      return _pullAll(SupabaseConfig.client);
    }
    return _pullAll(client);
  }

  /// Executes the sequential pull across all tables using [client].
  Future<bool> _pullAll(SupabaseClient client) async {
    final prefs = await SharedPreferences.getInstance();
    final lastPull = prefs.getString(_lastPullKey);

    // Capture timestamp before querying so changes during pull are
    // re-fetched next cycle (safe, idempotent) rather than missed.
    final pullTimestamp = DateTime.now().toUtc().toIso8601String();

    // Sequential pull in FK-dependency order.
    try {
      await _pullTable(
        client: client,
        table: DatabaseConstants.tableDecks,
        pkColumn: DatabaseConstants.colDeckId,
        timestampColumn: DatabaseConstants.colUpdatedAt,
        lastPull: lastPull,
      );

      await _pullTable(
        client: client,
        table: DatabaseConstants.tableCards,
        pkColumn: DatabaseConstants.colCardId,
        timestampColumn: DatabaseConstants.colUpdatedAt,
        lastPull: lastPull,
      );

      await _pullReviews(client: client, lastPull: lastPull);

      await _pullTable(
        client: client,
        table: DatabaseConstants.tableReviewSessionSummary,
        pkColumn: DatabaseConstants.colSessionId,
        timestampColumn: DatabaseConstants.colUpdatedAt,
        lastPull: lastPull,
      );

      await prefs.setString(_lastPullKey, pullTimestamp);
      dev.log('Pull complete (since $lastPull)', name: 'SyncPull');
      return true;
    } catch (e, st) {
      dev.log('Pull failed: $e', name: 'SyncPull', error: e, stackTrace: st);
      return false;
    }
  }

  /// Fetches a single page of rows from Supabase.
  ///
  /// Results are ordered by [pkColumn] for deterministic pagination —
  /// without ordering, Postgres may return rows in any order between
  /// requests, causing missed or duplicated rows.
  Future<List<Map<String, dynamic>>> _fetchPage(
    SupabaseClient client,
    String table,
    String pkColumn,
    String timestampColumn,
    String? lastPull,
    int offset,
  ) async {
    var query = client.from(table).select();
    if (lastPull != null) {
      query = query.gt(timestampColumn, lastPull);
    }
    return query.order(pkColumn).range(offset, offset + _pageSize - 1);
  }

  /// Pulls and merges rows for a standard table (decks, cards, summaries).
  /// Fetches pages sequentially and processes each page before fetching
  /// the next to bound memory usage.
  ///
  /// Conflict resolution per row:
  /// - No local row → insert
  /// - Local `synced` → overwrite (server is authoritative)
  /// - Local `pending` + remote newer → overwrite (remote wins)
  /// - Local `pending` + local newer → skip (local wins, pushes next cycle)
  Future<void> _pullTable({
    required SupabaseClient client,
    required String table,
    required String pkColumn,
    required String timestampColumn,
    required String? lastPull,
  }) async {
    final db = await _dbHelper.database;
    var totalMerged = 0;
    var totalSkipped = 0;
    var offset = 0;

    while (true) {
      final remoteRows = await _fetchPage(
        client, table, pkColumn, timestampColumn, lastPull, offset,
      );
      if (remoteRows.isEmpty) break;

      // Batch-fetch local state for this page's PKs to avoid N+1 queries.
      final remotePks = remoteRows.map((r) => r[pkColumn] as String).toList();
      final localIndex = await _buildLocalIndex(
        db, table, pkColumn, timestampColumn, remotePks,
      );

      for (final remoteRow in remoteRows) {
        final localRow = SyncAdapter.fromSupabaseRow(remoteRow);
        final pk = localRow[pkColumn] as String;
        final localInfo = localIndex[pk];

        if (localInfo == null) {
          await db.insert(table, localRow);
          totalMerged++;
          continue;
        }

        if (localInfo.syncStatus == SyncStatus.synced.name) {
          await db.insert(
            table, localRow, conflictAlgorithm: ConflictAlgorithm.replace,
          );
          totalMerged++;
          continue;
        }

        // Local row has pending changes — compare timestamps.
        final remoteTimestamp = DateTime.parse(
          remoteRow[timestampColumn] as String,
        );

        if (remoteTimestamp.isAfter(localInfo.updatedAt)) {
          await db.insert(
            table, localRow, conflictAlgorithm: ConflictAlgorithm.replace,
          );
          totalMerged++;
        } else {
          totalSkipped++;
        }
      }

      // If we got fewer rows than a full page, there are no more pages.
      if (remoteRows.length < _pageSize) break;
      offset += _pageSize;
    }

    if (totalMerged > 0 || totalSkipped > 0) {
      dev.log(
        'Pulled $table: $totalMerged merged, $totalSkipped skipped (local wins)',
        name: 'SyncPull',
      );
    }
  }

  /// Pulls reviews — insert-only since reviews are immutable.
  /// Uses batched inserts with ConflictAlgorithm.ignore for performance.
  Future<void> _pullReviews({
    required SupabaseClient client,
    required String? lastPull,
  }) async {
    final db = await _dbHelper.database;
    var totalInserted = 0;
    var offset = 0;

    while (true) {
      final remoteRows = await _fetchPage(
        client,
        DatabaseConstants.tableReviews,
        DatabaseConstants.colReviewId,
        DatabaseConstants.colReviewedAt,
        lastPull,
        offset,
      );
      if (remoteRows.isEmpty) break;

      final batch = db.batch();
      for (final remoteRow in remoteRows) {
        final localRow = SyncAdapter.fromSupabaseRow(remoteRow);
        batch.insert(
          DatabaseConstants.tableReviews,
          localRow,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      final results = await batch.commit();
      totalInserted += results.where((r) => r != 0).length;

      if (remoteRows.length < _pageSize) break;
      offset += _pageSize;
    }

    if (totalInserted > 0) {
      dev.log('Pulled reviews: $totalInserted inserted', name: 'SyncPull');
    }
  }

  /// Builds a lookup map of {pk → local row info} for conflict resolution.
  /// Only fetches the columns needed (PK, sync_status, timestamp) — not
  /// full rows.
  Future<Map<String, _LocalRowInfo>> _buildLocalIndex(
    Database db,
    String table,
    String pkColumn,
    String timestampColumn,
    List<String> pks,
  ) async {
    if (pks.isEmpty) return {};

    // SQLite has a limit of 999 variables per query. Chunk if needed.
    final index = <String, _LocalRowInfo>{};
    for (var i = 0; i < pks.length; i += 500) {
      final end = (i + 500).clamp(0, pks.length);
      final chunk = pks.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await db.query(
        table,
        columns: [pkColumn, DatabaseConstants.colSyncStatus, timestampColumn],
        where: '$pkColumn IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final pk = row[pkColumn] as String;
        index[pk] = _LocalRowInfo(
          syncStatus: row[DatabaseConstants.colSyncStatus] as String,
          updatedAt: DateTime.parse(row[timestampColumn] as String),
        );
      }
    }
    return index;
  }
}

/// Minimal info from a local row needed for conflict resolution.
class _LocalRowInfo {
  final String syncStatus;
  final DateTime updatedAt;

  const _LocalRowInfo({required this.syncStatus, required this.updatedAt});
}
