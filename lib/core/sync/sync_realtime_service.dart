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

  static const _debounceDelay = Duration(seconds: 2);

  SyncRealtimeService({
    required SupabaseClient client,
    required VoidCallback onRemoteChange,
  })  : _client = client,
        _onRemoteChange = onRemoteChange;

  /// Subscribes to the user's private sync broadcast channel.
  void subscribe(String userId) {
    unsubscribe();

    _channel = _client.channel(
      'user:$userId:sync',
      opts: const RealtimeChannelConfig(private: true),
    );

    _channel!.onBroadcast(
      event: 'sync_change',
      callback: (_) => _onChange(),
    );

    _channel!.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        debugPrint('[SyncRealtime] Subscribed to user:$userId:sync');
      } else if (error != null) {
        debugPrint('[SyncRealtime] Subscribe error: $error');
      }
    });
  }

  void _onChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, _onRemoteChange);
  }

  /// Unsubscribes from the channel and cancels any pending debounce.
  void unsubscribe() {
    _debounceTimer?.cancel();
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }

  void dispose() {
    unsubscribe();
  }
}
