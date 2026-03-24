import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_config.dart';
import 'sync_pull_service.dart';
import 'sync_push_service.dart';
import 'sync_adapter.dart';
import '../../features/decks/presentation/providers/deck_list_provider.dart';

/// Sync orchestrator state exposed to the UI.
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncTime;
  final String? lastError;
  final bool isPaused;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncTime,
    this.lastError,
    this.isPaused = false,
  });

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncTime,
    String? lastError,
    bool? isPaused,
    bool clearError = false,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      lastError: clearError ? null : (lastError ?? this.lastError),
      isPaused: isPaused ?? this.isPaused,
    );
  }
}

final syncServiceProvider =
    NotifierProvider<SyncServiceNotifier, SyncState>(SyncServiceNotifier.new);

/// Orchestrates sync push/pull, debounced writes, and app lifecycle triggers.
class SyncServiceNotifier extends Notifier<SyncState> {
  late final SyncPushService _pushService;
  late final SyncPullService _pullService;
  Timer? _debounceTimer;
  AppLifecycleListener? _lifecycleListener;
  bool _pushScheduledWhilePaused = false;

  @override
  SyncState build() {
    _pushService = SyncPushService();
    _pullService = SyncPullService();

    _lifecycleListener = AppLifecycleListener(
      onStateChange: _onLifecycleChange,
    );

    ref.onDispose(() {
      _debounceTimer?.cancel();
      _lifecycleListener?.dispose();
    });

    return const SyncState();
  }

  /// Whether sync can run (Supabase configured + active session).
  bool get _canSync =>
      SupabaseConfig.isConfigured &&
      SupabaseConfig.client.auth.currentSession != null;

  /// Schedules a push+pull after a 3s debounce. Called by notifiers after
  /// local writes. Resets the timer on each call so rapid edits batch up.
  void schedulePush() {
    if (state.isPaused) {
      _pushScheduledWhilePaused = true;
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 3), () {
      _doSync();
    });
  }

  /// Runs push then pull immediately. Called by the manual sync button.
  /// Returns a combined SyncResult for UI feedback.
  Future<SyncResult> syncNow() async {
    _debounceTimer?.cancel();
    return _doSync();
  }

  /// Pauses sync (for study session isolation). Cancels any pending debounce.
  /// Queued writes are tracked and flushed on resume.
  void pause() {
    _debounceTimer?.cancel();
    state = state.copyWith(isPaused: true);
  }

  /// Resumes sync after a study session. If writes were queued while paused,
  /// triggers a sync cycle.
  void resume() {
    state = state.copyWith(isPaused: false);
    if (_pushScheduledWhilePaused) {
      _pushScheduledWhilePaused = false;
      schedulePush();
    }
  }

  void _onLifecycleChange(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed) {
      if (!_canSync || state.isPaused) return;
      debugPrint('[SyncService] App resumed — triggering sync');
      _doSync();
    }
  }

  /// Core sync cycle: push then pull. Guards against concurrent runs.
  Future<SyncResult> _doSync() async {
    if (state.isSyncing) {
      return const SyncResult.success('Sync already in progress');
    }
    if (!_canSync) {
      return const SyncResult.success('Not signed in');
    }

    state = state.copyWith(isSyncing: true, clearError: true);

    try {
      final pushResult = await _pushService.pushWithDetail();
      final pullResult = await _pullService.pullWithDetail();

      final ok = pushResult.ok && pullResult.ok;
      final parts = <String>[
        if (pushResult.message.isNotEmpty) pushResult.message,
        if (pullResult.message.isNotEmpty) pullResult.message,
      ];
      final message = parts.isNotEmpty ? parts.join('. ') : 'Sync complete';

      if (ok) {
        state = state.copyWith(
          isSyncing: false,
          lastSyncTime: DateTime.now(),
        );
        // Refresh the deck list so UI reflects any pulled changes.
        ref.invalidate(deckListProvider);
        return SyncResult.success(message);
      } else {
        final errors = <String>[
          if (!pushResult.ok) 'Push: ${pushResult.error ?? 'unknown'}',
          if (!pullResult.ok) 'Pull: ${pullResult.error ?? 'unknown'}',
        ];
        final error = errors.join(' | ');
        state = state.copyWith(isSyncing: false, lastError: error);
        return SyncResult.failure(error);
      }
    } catch (e) {
      final error = 'Sync error: $e';
      debugPrint('[SyncService] $error');
      state = state.copyWith(isSyncing: false, lastError: error);
      return SyncResult.failure(error);
    }
  }
}
