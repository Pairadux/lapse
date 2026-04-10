import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_config.dart';
import 'user_id_migration_service.dart';

/// Wraps Supabase auth operations and manages user-id persistence.
///
/// When Supabase is not configured (no env.json at build time), all
/// auth operations are no-ops and [isAvailable] returns false.
class AuthService {
  static const _storedUserIdKey = 'stored_user_id';

  final UserIdMigrationService _migration;

  AuthService({UserIdMigrationService? migration})
    : _migration = migration ?? UserIdMigrationService();

  /// Whether Supabase auth is available (credentials were provided at build time).
  bool get isAvailable => SupabaseConfig.isConfigured;

  SupabaseClient get _client => SupabaseConfig.client;

  User? get currentUser => isAvailable ? _client.auth.currentUser : null;

  Session? get currentSession =>
      isAvailable ? _client.auth.currentSession : null;

  /// Auth state change stream. Returns an empty stream if Supabase is not configured.
  Stream<AuthState> get onAuthStateChange =>
      isAvailable ? _client.auth.onAuthStateChange : const Stream.empty();

  /// Sign up with email and password.
  ///
  /// Returns the [AuthResponse]. When email confirmation is enabled (production),
  /// `response.session` will be null — the user must confirm their email before
  /// they get a session. Migration runs only when a session is returned (i.e.
  /// confirmation is disabled in the Supabase project settings).
  Future<AuthResponse> signUpWithEmail(String email, String password) async {
    _requireAvailable();
    final response = await _client.auth.signUp(
      email: email,
      password: password,
    );
    // Only migrate if we got a session (email confirmation is disabled).
    // When confirmation is enabled, migration happens on first signIn.
    if (response.session != null && response.user != null) {
      await _onAuthenticated(response.user!.id);
    }
    return response;
  }

  /// Sign in with email and password.
  ///
  /// Runs user-id migration on success to stamp local data with the auth uid.
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    _requireAvailable();
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    if (response.user != null) {
      await _onAuthenticated(response.user!.id);
    }
    return response;
  }

  /// Sign out the current user.
  ///
  /// Stores the user_id in SharedPreferences so new data continues to be
  /// stamped with the correct owner while signed out.
  Future<void> signOut() async {
    _requireAvailable();
    final userId = _client.auth.currentUser?.id;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storedUserIdKey, userId);
    }
    await _client.auth.signOut(scope: SignOutScope.local);
  }

  /// Send a password reset email.
  Future<void> resetPassword(String email) async {
    _requireAvailable();
    await _client.auth.resetPasswordForEmail(email);
  }

  /// Resend the signup confirmation email.
  Future<void> resendConfirmation(String email) async {
    _requireAvailable();
    await _client.auth.resend(type: OtpType.signup, email: email);
  }

  /// Verify the 6-digit OTP code sent during sign-up.
  Future<AuthResponse> verifyOtp(String email, String token) async {
    _requireAvailable();
    final response = await _client.auth.verifyOTP(
      type: OtpType.signup,
      email: email,
      token: token,
    );
    if (response.session != null && response.user != null) {
      await _onAuthenticated(response.user!.id);
    }
    return response;
  }

  /// Returns the user_id to stamp on new data.
  ///
  /// Priority:
  /// 1. Active Supabase session → auth uid
  /// 2. Previously signed in → stored uid from SharedPreferences
  /// 3. Never signed in → empty string
  Future<String> getCurrentUserId() async {
    if (isAvailable) {
      final user = _client.auth.currentUser;
      if (user != null) return user.id;
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storedUserIdKey) ?? '';
  }

  /// Clears the stored user_id from SharedPreferences.
  /// Called during account deletion to revert to local-only mode.
  Future<void> clearStoredUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storedUserIdKey);
  }

  /// Common post-authentication logic: migrate local data and persist user_id.
  Future<void> _onAuthenticated(String userId) async {
    await _migration.migrateLocalData(userId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storedUserIdKey, userId);
  }

  void _requireAvailable() {
    if (!isAvailable) {
      throw StateError(
        'Supabase is not configured. Provide credentials via --dart-define-from-file=env.json',
      );
    }
  }
}
