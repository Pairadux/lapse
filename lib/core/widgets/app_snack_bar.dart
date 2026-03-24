import 'package:flutter/material.dart';

import '../theme/spacing.dart';

/// Centralized snackbar helper for consistent styling across the app.
///
/// Snackbar height matches the standard 56dp FAB. On screens with a FAB,
/// pass [withFabMargin] to render the snackbar beside it instead of behind it.
abstract class AppSnackBar {
  /// Right-inset margin that clears a standard 56dp FAB positioned at
  /// `right: Spacing.md, bottom: Spacing.md`.
  static const _fabMargin = EdgeInsets.fromLTRB(15, 5, 76, 12);

  /// Internal padding yielding ~56dp total height for single-line text.
  static const _padding =
      EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 18);

  static void show(
    BuildContext context,
    String message, {
    bool withFabMargin = false,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        padding: _padding,
        margin: withFabMargin ? _fabMargin : null,
        backgroundColor: backgroundColor,
        duration: duration,
      ),
    );
  }
}
