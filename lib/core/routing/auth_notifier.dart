import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/application/auth_service.dart';

/// Bridges Supabase auth state changes to GoRouter's [refreshListenable].
///
/// When the auth state changes (sign-in, sign-out, token refresh), this
/// notifier fires, causing GoRouter to re-evaluate its redirect logic.
class AuthNotifier extends ChangeNotifier {
  final AuthService _authService;
  StreamSubscription<AuthState>? _subscription;

  AuthNotifier({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _subscription = _authService.onAuthStateChange.listen((_) {
      notifyListeners();
    });
  }

  bool get isSignedIn => _authService.currentSession != null;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
