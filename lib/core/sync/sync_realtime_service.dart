import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Subscribes to a private Broadcast channel for the current user and
/// calls [onRemoteChange] when any synced table changes on the server.
///
/// Notifications are debounced (2s) so a bulk push from another device
/// doesn't fire dozens of pulls.
class SyncRealtimeService {
  final SupabaseClient _client;
  final VoidCallback _onRemoteChange;
  Timer? _debounceTimer;
  RealtimeChannel? _channel;
  bool _disposed = false;

  /// Monotonically increasing counter so a newer [subscribe] call
  /// silently cancels any in-flight retry from a previous call.
  int _generation = 0;

  static const _debounceDelay = Duration(seconds: 2);
  static const _maxAttempts = 3;
  static const _subscribeTimeout = Duration(seconds: 10);

  SyncRealtimeService({
    required SupabaseClient client,
    required VoidCallback onRemoteChange,
  }) : _client = client,
       _onRemoteChange = onRemoteChange;

  /// Subscribes to the user's private sync broadcast channel.
  ///
  /// Retries with exponential backoff (1s, 2s, 4s) on failure. A newer
  /// call to [subscribe] cancels any in-flight retry from a previous call.
  Future<void> subscribe(String userId, {int attempt = 0, int? generation}) async {
    final gen = generation ?? ++_generation;

    // A newer subscribe() or dispose() was called — abandon this attempt.
    if (gen != _generation || _disposed) return;

    await unsubscribe();

    if (_disposed) return;

    _channel = _client.channel(
      'user:$userId:sync',
      opts: const RealtimeChannelConfig(private: true),
    );

    final completer = Completer<void>();

    _channel!.subscribe((status, [error]) {
      if (completer.isCompleted) return;
      if (status == RealtimeSubscribeStatus.subscribed) {
        completer.complete();
      } else if (error != null) {
        completer.completeError(error);
      }
    });

    try {
      await completer.future.timeout(_subscribeTimeout);

      // Register broadcast listener AFTER subscription is confirmed.
      if (gen != _generation || _disposed) return;
      _channel?.onBroadcast(event: 'sync_change', callback: (_) => _onChange());
      debugPrint('[SyncRealtime] Subscribed to user:$userId:sync');
    } catch (e) {
      debugPrint(
        '[SyncRealtime] Subscribe attempt ${attempt + 1} failed: $e',
      );

      if (attempt + 1 < _maxAttempts && gen == _generation && !_disposed) {
        final delay = Duration(seconds: 1 << attempt); // 1s, 2s, 4s
        await Future.delayed(delay);
        return subscribe(userId, attempt: attempt + 1, generation: gen);
      }

      debugPrint(
        '[SyncRealtime] Giving up after ${attempt + 1} attempt(s)',
      );
    }
  }

  void _onChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _onRemoteChange);
  }

  /// Unsubscribes from the channel and cancels any pending debounce.
  Future<void> unsubscribe() async {
    _debounceTimer?.cancel();
    if (_channel != null) {
      final channel = _channel!;
      _channel = null;
      await _client.removeChannel(channel);
    }
  }

  void dispose() {
    _disposed = true;
    _generation++; // Cancel any in-flight retries.
    unsubscribe();
  }
}
