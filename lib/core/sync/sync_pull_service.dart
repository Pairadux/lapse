import 'package:flutter/foundation.dart';
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
  Future<bool> pull() async => (await pullWithDetail()).ok;

  /// Like [pull], but returns a [SyncResult] with error detail on failure.
  Future<SyncResult> pullWithDetail() async {
    final client = _clientOverride;
    if (client == null) {
      if (!SupabaseConfig.isConfigured) {
        debugPrint('[SyncPull] Supabase not configured — skipping pull');
        return const SyncResult.failure('Supabase not configured');
      }
      if (SupabaseConfig.client.auth.currentSession == null) {
        debugPrint('[SyncPull] No active session — skipping pull');
        return const SyncResult.failure('Not signed in');
      }
      return _pullAll(SupabaseConfig.client);
    }
    return _pullAll(client);
  }

  /// Executes the sequential pull across all tables using [client].
  Future<SyncResult> _pullAll(SupabaseClient client) async {
    final prefs = await SharedPreferences.getInstance();
    var lastPull = prefs.getString(_lastPullKey);

    // If we have a stored timestamp but the local DB is empty, the DB was
    // likely cleared without resetting the timestamp (e.g. reinstall, release
    // build without dev tools). Force a full pull so we don't miss data that
    // was pushed before the stale timestamp.
    if (lastPull != null) {
      final db = await _dbHelper.database;
      final result = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM ${DatabaseConstants.tableDecks}',
      );
      final deckCount = result.first['c'] as int;
      if (deckCount == 0) {
        debugPrint(
          '[SyncPull] Local DB is empty but last_pull_timestamp exists — forcing full sync',
        );
        lastPull = null;
      }
    }

    debugPrint(
      '[SyncPull] Starting pull (lastPull: ${lastPull ?? 'NEVER — full sync'})',
    );

    final stats = <String, int>{};
    final serverTimestamps = <String>[];

    // Sequential pull in FK-dependency order.
    try {
      var result = await _pullTable(
        client: client,
        table: DatabaseConstants.tableDecks,
        pkColumn: DatabaseConstants.colDeckId,
        timestampColumn: DatabaseConstants.colUpdatedAt,
        lastPull: lastPull,
      );
      stats['decks'] = result.count;
      if (result.maxTimestamp != null) {
        serverTimestamps.add(result.maxTimestamp!);
      }

      result = await _pullTable(
        client: client,
        table: DatabaseConstants.tableCards,
        pkColumn: DatabaseConstants.colCardId,
        timestampColumn: DatabaseConstants.colUpdatedAt,
        lastPull: lastPull,
      );
      stats['cards'] = result.count;
      if (result.maxTimestamp != null) {
        serverTimestamps.add(result.maxTimestamp!);
      }

      final reviewResult = await _pullReviews(
        client: client,
        lastPull: lastPull,
      );
      stats['reviews'] = reviewResult.count;
      // Intentionally NOT adding reviewResult.maxTimestamp to serverTimestamps.
      // reviewed_at is client-set (by the creating device), not server-set.
      // Including it could push the cursor ahead of the server clock domain
      // and cause the same skew bug we're fixing. Reviews are insert-only with
      // ConflictAlgorithm.ignore, so re-fetching duplicates is harmless.

      result = await _pullTable(
        client: client,
        table: DatabaseConstants.tableReviewSessionSummary,
        pkColumn: DatabaseConstants.colSessionId,
        timestampColumn: DatabaseConstants.colUpdatedAt,
        lastPull: lastPull,
      );
      stats['summaries'] = result.count;
      if (result.maxTimestamp != null) {
        serverTimestamps.add(result.maxTimestamp!);
      }

      // Derive pullTimestamp from the server's clock domain — the latest
      // timestamp across all pulled rows. This eliminates clock skew between
      // client and server. If nothing was pulled, don't advance the cursor;
      // next pull re-queries the same window (idempotent, no-op).
      if (serverTimestamps.isNotEmpty) {
        serverTimestamps.sort();
        await prefs.setString(_lastPullKey, serverTimestamps.last);
      }

      final totalPulled = stats.values.fold(0, (a, b) => a + b);
      final parts = stats.entries
          .where((e) => e.value > 0)
          .map((e) => '${e.value} ${e.key}')
          .toList();
      final message = totalPulled == 0
          ? 'Nothing new to pull'
          : 'Pulled ${parts.join(', ')}';
      debugPrint('[SyncPull] $message');
      return SyncResult.success(message);
    } catch (e, st) {
      debugPrint('[SyncPull] Pull failed: $e\n$st');
      return SyncResult.failure(e.toString());
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
  /// Returns the number of *new* rows merged (inserts + conflict wins).
  /// Rows that already exist locally as `synced` are silently refreshed
  /// but not counted — they're typically echoes of data we just pushed
  /// (the server's `set_updated_at` trigger changes the timestamp).
  ///
  /// Conflict resolution per row:
  /// - No local row → insert (counted)
  /// - Local `synced` → overwrite silently (server is authoritative)
  /// - Local `pending` + remote newer → overwrite (counted)
  /// - Local `pending` + local newer → skip (local wins, pushes next cycle)
  Future<({int count, String? maxTimestamp})> _pullTable({
    required SupabaseClient client,
    required String table,
    required String pkColumn,
    required String timestampColumn,
    required String? lastPull,
  }) async {
    final db = await _dbHelper.database;
    var newRows = 0;
    var refreshed = 0;
    var conflictWins = 0;
    var skipped = 0;
    var offset = 0;
    String? maxTimestamp;

    debugPrint('[SyncPull] Fetching $table...');

    while (true) {
      final remoteRows = await _fetchPage(
        client,
        table,
        pkColumn,
        timestampColumn,
        lastPull,
        offset,
      );
      debugPrint(
        '[SyncPull]   $table page at offset $offset: ${remoteRows.length} rows from Supabase',
      );
      if (remoteRows.isEmpty) break;

      // Batch-fetch local state for this page's PKs to avoid N+1 queries.
      final remotePks = remoteRows.map((r) => r[pkColumn] as String).toList();
      final localIndex = await _buildLocalIndex(
        db,
        table,
        pkColumn,
        timestampColumn,
        remotePks,
      );

      for (final remoteRow in remoteRows) {
        // Track the latest server timestamp for pull cursor advancement.
        final ts = remoteRow[timestampColumn] as String?;
        if (ts != null &&
            (maxTimestamp == null || ts.compareTo(maxTimestamp) > 0)) {
          maxTimestamp = ts;
        }

        final localRow = SyncAdapter.fromSupabaseRow(remoteRow);
        final pk = localRow[pkColumn] as String;
        final localInfo = localIndex[pk];

        if (localInfo == null) {
          await db.insert(table, localRow);
          newRows++;
          continue;
        }

        if (localInfo.syncStatus == SyncStatus.synced.name) {
          // Already synced — silent refresh (likely echo of our own push).
          await db.insert(
            table,
            localRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          refreshed++;
          continue;
        }

        // Local row has pending changes — compare timestamps.
        final remoteTimestamp = DateTime.parse(
          remoteRow[timestampColumn] as String,
        );

        if (remoteTimestamp.isAfter(localInfo.updatedAt)) {
          await db.insert(
            table,
            localRow,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          conflictWins++;
        } else {
          skipped++;
        }
      }

      // If we got fewer rows than a full page, there are no more pages.
      if (remoteRows.length < _pageSize) break;
      offset += _pageSize;
    }

    final total = newRows + refreshed + conflictWins + skipped;
    if (total > 0) {
      debugPrint(
        '[SyncPull]   $table: $newRows new, $refreshed refreshed, '
        '$conflictWins conflict wins, $skipped skipped (local wins)',
      );
    }

    // Only count genuinely new data for the user-facing message.
    return (count: newRows + conflictWins, maxTimestamp: maxTimestamp);
  }

  /// Pulls reviews — insert-only since reviews are immutable.
  /// Returns the number of rows inserted.
  Future<({int count, String? maxTimestamp})> _pullReviews({
    required SupabaseClient client,
    required String? lastPull,
  }) async {
    final db = await _dbHelper.database;
    var totalInserted = 0;
    var offset = 0;
    String? maxTimestamp;

    debugPrint('[SyncPull] Fetching reviews...');

    while (true) {
      final remoteRows = await _fetchPage(
        client,
        DatabaseConstants.tableReviews,
        DatabaseConstants.colReviewId,
        DatabaseConstants.colReviewedAt,
        lastPull,
        offset,
      );
      debugPrint(
        '[SyncPull]   reviews page at offset $offset: ${remoteRows.length} rows from Supabase',
      );
      if (remoteRows.isEmpty) break;

      final batch = db.batch();
      for (final remoteRow in remoteRows) {
        final ts = remoteRow[DatabaseConstants.colReviewedAt] as String?;
        if (ts != null &&
            (maxTimestamp == null || ts.compareTo(maxTimestamp) > 0)) {
          maxTimestamp = ts;
        }
        final localRow = SyncAdapter.fromSupabaseRow(remoteRow);
        batch.insert(
          DatabaseConstants.tableReviews,
          localRow,
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      final results = await batch.commit();
      totalInserted += results.where((r) => r is int && r > 0).length;

      if (remoteRows.length < _pageSize) break;
      offset += _pageSize;
    }

    if (totalInserted > 0) {
      debugPrint('[SyncPull]   reviews: $totalInserted inserted');
    }

    return (count: totalInserted, maxTimestamp: maxTimestamp);
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

  /// Clears the stored pull timestamp, forcing the next pull to fetch
  /// everything. Called when local data is cleared.
  static Future<void> resetLastPullTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastPullKey);
    debugPrint('[SyncPull] Cleared last_pull_timestamp');
  }
}

/// Minimal info from a local row needed for conflict resolution.
class _LocalRowInfo {
  final String syncStatus;
  final DateTime updatedAt;

  const _LocalRowInfo({required this.syncStatus, required this.updatedAt});
}
