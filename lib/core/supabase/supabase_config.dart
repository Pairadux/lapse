import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized Supabase configuration and client access.
///
/// Credentials are provided at compile time via `--dart-define-from-file=env.json`.
class SupabaseConfig {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// The project URL, for display or diagnostics.
  static String get url => _url;

  /// Whether Supabase credentials were provided at build time.
  static bool get isConfigured => _url.isNotEmpty && _publishableKey.isNotEmpty;

  /// Initialize the Supabase client. Call once in main() before runApp().
  static Future<void> initialize() async {
    if (!isConfigured) return;

    await Supabase.initialize(url: _url, anonKey: _publishableKey);
  }

  /// The Supabase client instance. Only valid after [initialize] completes
  /// and when [isConfigured] is true.
  static SupabaseClient get client => Supabase.instance.client;
}
