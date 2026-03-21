import 'dart:developer' as dev;

import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/supabase/supabase_config.dart';
import 'package:lapse/core/sync/sync_adapter.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/study/data/review_repository.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';

/// Pushes locally-changed rows to Supabase.
///
/// Tables are pushed sequentially (decks → cards → reviews → summaries)
/// to satisfy foreign-key constraints. One upsert per table — no batching.
/// On failure, already-synced tables keep their status; unsynced rows
/// remain pending and retry on the next cycle.
class SyncPushService {
  final DeckRepository _deckRepo;
  final CardRepository _cardRepo;
  final ReviewRepository _reviewRepo;
  final ReviewSessionSummaryRepository _summaryRepo;

  SyncPushService({
    DeckRepository? deckRepo,
    CardRepository? cardRepo,
    ReviewRepository? reviewRepo,
    ReviewSessionSummaryRepository? summaryRepo,
  })  : _deckRepo = deckRepo ?? DeckRepository(),
        _cardRepo = cardRepo ?? CardRepository(),
        _reviewRepo = reviewRepo ?? ReviewRepository(),
        _summaryRepo = summaryRepo ?? ReviewSessionSummaryRepository();

  /// Pushes all pending local changes to Supabase.
  ///
  /// Returns `true` if all tables pushed successfully, `false` if any failed.
  /// On partial failure, already-pushed tables are marked synced — only the
  /// failed table and subsequent tables retry next cycle.
  Future<bool> push() async {
    if (!SupabaseConfig.isConfigured) return false;
    if (SupabaseConfig.client.auth.currentSession == null) return false;

    final client = SupabaseConfig.client;

    // Sequential push in FK-dependency order.
    // If a table fails (likely network), stop — subsequent tables would fail too.

    if (!await _pushTable(
      label: 'decks',
      getUnsynced: () async =>
          (await _deckRepo.getUnsynced()).map((d) => d.toMap()).toList(),
      upsert: (rows) =>
          client.from(DatabaseConstants.tableDecks).upsert(rows, onConflict: DatabaseConstants.colDeckId),
      markSynced: (rows) => _deckRepo.markSynced(
          rows.map((r) => r[DatabaseConstants.colDeckId] as String).toList()),
    )) {
      return false;
    }

    if (!await _pushTable(
      label: 'cards',
      getUnsynced: () async =>
          (await _cardRepo.getUnsynced()).map((c) => c.toMap()).toList(),
      upsert: (rows) =>
          client.from(DatabaseConstants.tableCards).upsert(rows, onConflict: DatabaseConstants.colCardId),
      markSynced: (rows) => _cardRepo.markSynced(
          rows.map((r) => r[DatabaseConstants.colCardId] as String).toList()),
    )) {
      return false;
    }

    if (!await _pushTable(
      label: 'reviews',
      getUnsynced: () async =>
          (await _reviewRepo.getUnsynced()).map((r) => r.toMap()).toList(),
      upsert: (rows) =>
          client.from(DatabaseConstants.tableReviews).upsert(rows, onConflict: DatabaseConstants.colReviewId),
      markSynced: (rows) => _reviewRepo.markSynced(
          rows.map((r) => r[DatabaseConstants.colReviewId] as String).toList()),
    )) {
      return false;
    }

    if (!await _pushTable(
      label: 'session_summaries',
      getUnsynced: () async =>
          (await _summaryRepo.getUnsynced()).map((s) => s.toMap()).toList(),
      upsert: (rows) => client
          .from(DatabaseConstants.tableReviewSessionSummary)
          .upsert(rows, onConflict: DatabaseConstants.colSessionId),
      markSynced: (rows) => _summaryRepo.markSynced(
          rows.map((r) => r[DatabaseConstants.colSessionId] as String).toList()),
    )) {
      return false;
    }

    return true;
  }

  /// Pushes a single table's pending rows.
  ///
  /// [getUnsynced] returns SQLite-format maps. They are converted via
  /// [SyncAdapter.toSupabaseRow] before upserting. [markSynced] receives
  /// the original SQLite maps (for ID extraction).
  Future<bool> _pushTable({
    required String label,
    required Future<List<Map<String, dynamic>>> Function() getUnsynced,
    required Future<void> Function(List<Map<String, dynamic>>) upsert,
    required Future<void> Function(List<Map<String, dynamic>>) markSynced,
  }) async {
    try {
      final localMaps = await getUnsynced();
      if (localMaps.isEmpty) return true;

      final supabaseRows = localMaps.map(SyncAdapter.toSupabaseRow).toList();
      await upsert(supabaseRows);
      await markSynced(localMaps);

      dev.log('Pushed ${localMaps.length} $label', name: 'SyncPush');
      return true;
    } catch (e, st) {
      dev.log('Push failed for $label: $e', name: 'SyncPush', error: e, stackTrace: st);
      return false;
    }
  }
}
