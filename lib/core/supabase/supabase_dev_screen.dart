import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_scaffold.dart';
import 'supabase_config.dart';

class SupabaseDevScreen extends StatefulWidget {
  const SupabaseDevScreen({super.key});

  @override
  State<SupabaseDevScreen> createState() => _SupabaseDevScreenState();
}

class _SupabaseDevScreenState extends State<SupabaseDevScreen> {
  // Connection health
  _ConnectionStatus _connectionStatus = _ConnectionStatus.checking;
  String? _connectionError;

  // Realtime echo
  RealtimeChannel? _channel;
  _RealtimeStatus _realtimeStatus = _RealtimeStatus.disconnected;
  final List<_EchoMessage> _messages = [];
  final String _deviceName = _buildDeviceName();

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _subscribeToEcho();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    if (!SupabaseConfig.isConfigured) {
      setState(() {
        _connectionStatus = _ConnectionStatus.notConfigured;
      });
      return;
    }

    setState(() => _connectionStatus = _ConnectionStatus.checking);

    try {
      // Simple health check — query the auth endpoint
      await SupabaseConfig.client.auth.getUser();
      // Even if not logged in, a successful HTTP round-trip means we're connected
      if (mounted) {
        setState(() => _connectionStatus = _ConnectionStatus.connected);
      }
    } on AuthException {
      // Auth error still means the network call succeeded
      if (mounted) {
        setState(() => _connectionStatus = _ConnectionStatus.connected);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _connectionStatus = _ConnectionStatus.error;
          _connectionError = e.toString();
        });
      }
    }
  }

  void _subscribeToEcho() {
    if (!SupabaseConfig.isConfigured) return;

    setState(() => _realtimeStatus = _RealtimeStatus.connecting);

    _channel = SupabaseConfig.client.channel(
      'dev-echo',
      opts: const RealtimeChannelConfig(self: true),
    );
    _channel!
        .onBroadcast(
          event: 'ping',
          callback: (payload) {
            debugPrint('Broadcast received: $payload');
            if (!mounted) return;
            _addMessage(
              device: payload['device'] as String? ?? 'unknown',
              message: payload['message'] as String? ?? '',
            );
          },
        )
        .subscribe((status, error) {
          debugPrint('Realtime status: $status, error: $error');
          if (!mounted) return;
          setState(() {
            _realtimeStatus = switch (status) {
              RealtimeSubscribeStatus.subscribed => _RealtimeStatus.subscribed,
              RealtimeSubscribeStatus.closed => _RealtimeStatus.disconnected,
              _ => _RealtimeStatus.connecting,
            };
          });
        });
  }

  void _addMessage({required String device, required String message}) {
    setState(() {
      _messages.insert(
        0,
        _EchoMessage(
          device: device,
          message: message,
          timestamp: DateTime.now(),
        ),
      );
      if (_messages.length > 50) _messages.removeLast();
    });
  }

  Future<void> _sendPing() async {
    if (_channel == null) return;

    await _channel!.sendBroadcastMessage(
      event: 'ping',
      payload: {'device': _deviceName, 'message': 'Hello from $_deviceName'},
    );
  }

  static String _buildDeviceName() {
    try {
      final os = Platform.operatingSystem;
      final host = Platform.localHostname;
      return '$os ($host)';
    } catch (_) {
      return 'unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppScaffold(
      title: 'Supabase Dev',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(Spacing.screenPadding),
        children: [
          _buildSection(
            context,
            title: 'Connection',
            child: _buildConnectionCard(theme),
          ),
          const SizedBox(height: Spacing.sectionSpacing),
          _buildSection(
            context,
            title: 'Auth Status',
            child: _buildAuthCard(theme),
          ),
          const SizedBox(height: Spacing.sectionSpacing),
          _buildSection(
            context,
            title: 'Realtime Echo',
            subtitle: 'Open on multiple devices to see them communicate',
            child: _buildRealtimeCard(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: Spacing.xs),
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: Spacing.sm),
        child,
      ],
    );
  }

  Widget _buildConnectionCard(ThemeData theme) {
    final (icon, color, label) = switch (_connectionStatus) {
      _ConnectionStatus.checking => (
        Icons.sync,
        AppColors.warning,
        'Checking...',
      ),
      _ConnectionStatus.connected => (
        Icons.check_circle,
        AppColors.success,
        'Connected',
      ),
      _ConnectionStatus.error => (Icons.error, AppColors.error, 'Error'),
      _ConnectionStatus.notConfigured => (
        Icons.warning_amber,
        AppColors.warning,
        'Not configured',
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: Spacing.iconSize),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: color,
                        ),
                      ),
                      if (_connectionError != null)
                        Text(
                          _connectionError!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _checkConnection,
                  tooltip: 'Retry',
                ),
              ],
            ),
            if (SupabaseConfig.isConfigured) ...[
              const Divider(height: Spacing.xl),
              Row(
                children: [
                  const Icon(
                    Icons.link,
                    size: 16,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(
                    child: Text(
                      SupabaseConfig.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAuthCard(ThemeData theme) {
    if (!SupabaseConfig.isConfigured) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: Text(
            'Supabase not configured',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final user = SupabaseConfig.client.auth.currentUser;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        child: Row(
          children: [
            Icon(
              user != null ? Icons.person : Icons.person_off_outlined,
              color: user != null ? AppColors.success : AppColors.textTertiary,
              size: Spacing.iconSize,
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Text(
                user?.email ?? 'Not signed in',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: user != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeCard(ThemeData theme) {
    if (!SupabaseConfig.isConfigured) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.cardPadding),
          child: Text(
            'Supabase not configured',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  switch (_realtimeStatus) {
                    _RealtimeStatus.subscribed => Icons.wifi,
                    _RealtimeStatus.connecting => Icons.wifi_find,
                    _RealtimeStatus.disconnected => Icons.wifi_off,
                  },
                  size: 16,
                  color: switch (_realtimeStatus) {
                    _RealtimeStatus.subscribed => AppColors.success,
                    _RealtimeStatus.connecting => AppColors.warning,
                    _RealtimeStatus.disconnected => AppColors.error,
                  },
                ),
                const SizedBox(width: Spacing.sm),
                Text(
                  switch (_realtimeStatus) {
                    _RealtimeStatus.subscribed => 'Channel subscribed',
                    _RealtimeStatus.connecting => 'Connecting...',
                    _RealtimeStatus.disconnected => 'Disconnected',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                const Icon(
                  Icons.devices,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    'This device: $_deviceName',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.md),
            FilledButton.icon(
              onPressed: _sendPing,
              icon: const Icon(Icons.send),
              label: const Text('Send Ping'),
            ),
            if (_messages.isNotEmpty) ...[
              const Divider(height: Spacing.xl),
              for (final msg in _messages) ...[
                Builder(
                  builder: (_) {
                    final isLocal = msg.device == _deviceName;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isLocal ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 14,
                          color: isLocal
                              ? AppColors.primary
                              : AppColors.secondary,
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                msg.device,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: isLocal
                                      ? AppColors.primary
                                      : AppColors.secondary,
                                ),
                              ),
                              Text(
                                msg.message,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _formatTime(msg.timestamp),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: Spacing.sm),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}

enum _ConnectionStatus { checking, connected, error, notConfigured }

enum _RealtimeStatus { disconnected, connecting, subscribed }

class _EchoMessage {
  final String device;
  final String message;
  final DateTime timestamp;

  const _EchoMessage({
    required this.device,
    required this.message,
    required this.timestamp,
  });
}
