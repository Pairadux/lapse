import 'package:flutter/foundation.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/supabase/supabase_config.dart';
import 'package:lapse/core/sync/sync_adapter.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/study/data/review_repository.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pushes locally-changed rows to Supabase.
///
/// Tables are pushed sequentially (decks → cards → reviews → summaries)
/// to satisfy foreign-key constraints. Each table's rows are paginated
/// (1000 per request) so large offline-accumulated changes don't produce
/// oversized payloads. On failure, already-synced pages/tables keep their
/// status; unsynced rows remain pending and retry on the next cycle.
class SyncPushService {
  /// Page size for chunked upserts. Keeps payloads reasonable and allows
  /// partial progress if the connection drops mid-sync.
  static const _pageSize = 1000;

  final DeckRepository _deckRepo;
  final CardRepository _cardRepo;
  final ReviewRepository _reviewRepo;
  final ReviewSessionSummaryRepository _summaryRepo;
  final SupabaseClient? _clientOverride;

  SyncPushService({
    DeckRepository? deckRepo,
    CardRepository? cardRepo,
    ReviewRepository? reviewRepo,
    ReviewSessionSummaryRepository? summaryRepo,
    SupabaseClient? client,
  }) : _deckRepo = deckRepo ?? DeckRepository(),
       _cardRepo = cardRepo ?? CardRepository(),
       _reviewRepo = reviewRepo ?? ReviewRepository(),
       _summaryRepo = summaryRepo ?? ReviewSessionSummaryRepository(),
       _clientOverride = client;

  /// Pushes all pending local changes to Supabase.
  ///
  /// Returns `true` if all tables pushed successfully, `false` if any failed.
  /// On partial failure, already-pushed tables are marked synced — only the
  /// failed table and subsequent tables retry next cycle.
  Future<bool> push() async => (await pushWithDetail()).ok;

  /// Like [push], but returns a [SyncResult] with error detail on failure.
  Future<SyncResult> pushWithDetail() async {
    final client = _clientOverride;
    if (client == null) {
      if (!SupabaseConfig.isConfigured) {
        debugPrint('[SyncPush] Supabase not configured — skipping push');
        return const SyncResult.failure('Supabase not configured');
      }
      if (SupabaseConfig.client.auth.currentSession == null) {
        debugPrint('[SyncPush] No active session — skipping push');
        return const SyncResult.failure('Not signed in');
      }
      return _pushAll(SupabaseConfig.client);
    }
    return _pushAll(client);
  }

  /// Executes the sequential push across all tables using [client].
  Future<SyncResult> _pushAll(SupabaseClient client) async {
    debugPrint('[SyncPush] Starting push...');

    // Sequential push in FK-dependency order.
    // If a table fails (likely network), stop — subsequent tables would fail too.

    // Safety net: stamp user_id on any rows that slipped through without one.
    final authUid = client.auth.currentUser?.id;

    final tables = <_TablePushConfig>[
      _TablePushConfig(
        label: 'decks',
        getUnsynced: () async =>
            (await _deckRepo.getUnsynced()).map((d) => d.toMap()).toList(),
        upsert: (rows) => client
            .from(DatabaseConstants.tableDecks)
            .upsert(rows, onConflict: DatabaseConstants.colDeckId),
        markSynced: (rows) => _deckRepo.markSynced({
          for (final r in rows)
            r[DatabaseConstants.colDeckId] as String:
                r[DatabaseConstants.colUpdatedAt] as String,
        }),
      ),
      _TablePushConfig(
        label: 'cards',
        getUnsynced: () async =>
            (await _cardRepo.getUnsynced()).map((c) => c.toMap()).toList(),
        upsert: (rows) => client
            .from(DatabaseConstants.tableCards)
            .upsert(rows, onConflict: DatabaseConstants.colCardId),
        markSynced: (rows) => _cardRepo.markSynced({
          for (final r in rows)
            r[DatabaseConstants.colCardId] as String:
                r[DatabaseConstants.colUpdatedAt] as String,
        }),
      ),
      _TablePushConfig(
        label: 'reviews',
        getUnsynced: () async =>
            (await _reviewRepo.getUnsynced()).map((r) => r.toMap()).toList(),
        upsert: (rows) => client
            .from(DatabaseConstants.tableReviews)
            .upsert(rows, onConflict: DatabaseConstants.colReviewId),
        markSynced: (rows) => _reviewRepo.markSynced(
          rows.map((r) => r[DatabaseConstants.colReviewId] as String).toList(),
        ),
      ),
      _TablePushConfig(
        label: 'session_summaries',
        getUnsynced: () async =>
            (await _summaryRepo.getUnsynced()).map((s) => s.toMap()).toList(),
        upsert: (rows) => client
            .from(DatabaseConstants.tableReviewSessionSummary)
            .upsert(rows, onConflict: DatabaseConstants.colSessionId),
        markSynced: (rows) => _summaryRepo.markSynced({
          for (final r in rows)
            r[DatabaseConstants.colSessionId] as String:
                r[DatabaseConstants.colUpdatedAt] as String,
        }),
      ),
    ];

    final stats = <String, int>{};

    for (final table in tables) {
      final result = await _pushTable(table, authUid);
      if (result.error != null) {
        return SyncResult.failure('${table.label}: ${result.error}');
      }
      stats[table.label] = result.count;
    }

    final totalPushed = stats.values.fold(0, (a, b) => a + b);
    final parts = stats.entries
        .where((e) => e.value > 0)
        .map((e) => '${e.value} ${e.key}')
        .toList();
    final message = totalPushed == 0
        ? 'Nothing to push'
        : 'Pushed ${parts.join(', ')}';
    debugPrint('[SyncPush] $message');
    return SyncResult.success(message);
  }

  /// Pushes a single table's pending rows in pages of [_pageSize].
  ///
  /// Returns a [_PushTableResult] with count and optional error.
  /// [getUnsynced] returns SQLite-format maps. They are converted via
  /// [SyncAdapter.toSupabaseRow] before upserting. Each page is upserted
  /// and marked synced independently — if a page fails, prior pages keep
  /// their synced status and only the remaining rows retry next cycle.
  Future<_PushTableResult> _pushTable(
    _TablePushConfig config,
    String? authUid,
  ) async {
    try {
      final localMaps = await config.getUnsynced();
      if (localMaps.isEmpty) {
        debugPrint('[SyncPush] ${config.label}: 0 pending');
        return const _PushTableResult(count: 0);
      }

      debugPrint('[SyncPush] ${config.label}: ${localMaps.length} pending');

      for (var i = 0; i < localMaps.length; i += _pageSize) {
        final end = (i + _pageSize).clamp(0, localMaps.length);
        final chunk = localMaps.sublist(i, end);
        final supabaseRows = chunk.map(SyncAdapter.toSupabaseRow).toList();
        // Safety net: stamp empty user_id with auth uid before sending
        if (authUid != null) {
          for (final row in supabaseRows) {
            final uid = row[DatabaseConstants.colUserId];
            if (uid == null || uid == '') {
              row[DatabaseConstants.colUserId] = authUid;
            }
          }
        }
        await config.upsert(supabaseRows);
        await config.markSynced(chunk);
      }

      debugPrint(
        '[SyncPush] ${config.label}: ${localMaps.length} pushed successfully',
      );
      return _PushTableResult(count: localMaps.length);
    } catch (e, st) {
      debugPrint('[SyncPush] ${config.label} FAILED: $e\n$st');
      return _PushTableResult(count: 0, error: e.toString());
    }
  }
}

class _TablePushConfig {
  final String label;
  final Future<List<Map<String, dynamic>>> Function() getUnsynced;
  final Future<void> Function(List<Map<String, dynamic>>) upsert;
  final Future<void> Function(List<Map<String, dynamic>>) markSynced;

  const _TablePushConfig({
    required this.label,
    required this.getUnsynced,
    required this.upsert,
    required this.markSynced,
  });
}

class _PushTableResult {
  final int count;
  final String? error;

  const _PushTableResult({required this.count, this.error});
}
