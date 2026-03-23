import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service for monitoring device connectivity status.
///
/// Provides methods to check connectivity and show offline snack bars.
/// Uses singleton pattern for app-wide access.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  GlobalKey<ScaffoldMessengerState>? _scaffoldMessengerKey;
  bool _notificationsPaused = false;
  DateTime? _lastNotificationTime;
  static const Duration _notificationCooldown = Duration(seconds: 5);

  /// TODO: Wire to user settings (call from settings screen when implemented)
  /// Example: ConnectivityService().setOfflineNotificationsEnabled(userPreference)
  bool _showOfflineNotification = true;

  factory ConnectivityService() => _instance;

  ConnectivityService._internal() {
    _checkInitialConnectivity();

    // Listen for connectivity changes and show snack bar when going offline
    _connectivity.onConnectivityChanged.listen((results) {
      final wasOnline = _isOnline;
      _isOnline = !results.contains(ConnectivityResult.none);

      // Show snack bar if device just went offline (and notifications enabled and not paused)
      if (wasOnline &&
          !_isOnline &&
          _scaffoldMessengerKey != null &&
          _showOfflineNotification &&
          !_notificationsPaused) {
        _tryShowOfflineSnackBar();
      }
    });
  }

  Future<void> _checkInitialConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    _isOnline = !result.contains(ConnectivityResult.none);
  }

  void setScaffoldMessengerKey(GlobalKey<ScaffoldMessengerState> key) {
    _scaffoldMessengerKey = key;
  }

  void setOfflineNotificationsEnabled(bool enabled) {
    _showOfflineNotification = enabled;
  }

  void pauseNotifications() {
    _notificationsPaused = true;
  }

  void resumeNotifications() {
    _notificationsPaused = false;
  }

  /// Check if device is currently offline
  bool get isOffline => !_isOnline;

  /// Check if enough time has passed since last notification (prevents spam on shaky internet)
  bool _canShowNotification() {
    final now = DateTime.now();
    if (_lastNotificationTime == null) return true;
    return now.difference(_lastNotificationTime!) >= _notificationCooldown;
  }

  /// Internal method to show snack bar with cooldown check
  void _tryShowOfflineSnackBar() {
    if (_canShowNotification()) {
      _lastNotificationTime = DateTime.now();
      showOfflineSnackBar();
    }
  }

  /// Show offline snack bar if device is offline and notifications are enabled
  static void showOfflineSnackBar() {
    final service = ConnectivityService();
    if (service.isOffline && service._scaffoldMessengerKey != null && service._showOfflineNotification) {
      service._scaffoldMessengerKey!.currentState?.showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.cloud_off, color: Colors.white, size: 18),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("You're offline"),
                    // TODO: Wire to actual sync queue count when sync service is implemented
                    Text('Changes not synced', style: TextStyle(fontSize: 12, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}
