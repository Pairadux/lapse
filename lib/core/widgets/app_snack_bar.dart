import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../../core/routing/page_transitions.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';

/// Centralized toast helper for consistent styling across the app.
///
/// Uses toastification's overlay system instead of Scaffold's built-in SnackBar
/// so toasts render independently of the FAB — no pushing, no overlap.
abstract class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    bool withFabMargin = false,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    toastification.showCustom(
      context: context,
      alignment: withFabMargin ? Alignment.bottomLeft : Alignment.bottomCenter,
      autoCloseDuration: duration,
      builder: (context, holder) {
        final safeBottom =
            isDesktop ? 0.0 : MediaQuery.of(context).padding.bottom;
        return Padding(
          padding: EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: Spacing.lg + safeBottom,
          ),
          child: Material(
            color: backgroundColor ?? AppColors.surfaceBright,
            borderRadius: BorderRadius.circular(Spacing.radiusMd),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg,
                vertical: 18,
              ),
              child: Text(
                message,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Previous SnackBar-based implementation (kept for rollback) ──────────
//
// abstract class AppSnackBar {
//   static const _padding =
//       EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: 18);
//
//   static EdgeInsets _fabMargin(BuildContext context) {
//     final safeBottom = MediaQuery.of(context).padding.bottom;
//     return EdgeInsets.fromLTRB(15, 5, 80, (16 - safeBottom).clamp(0, 16));
//   }
//
//   static void show(
//     BuildContext context,
//     String message, {
//     bool withFabMargin = false,
//     Color? backgroundColor,
//     Duration duration = const Duration(seconds: 4),
//   }) {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Text(message),
//         padding: _padding,
//         margin: withFabMargin ? _fabMargin(context) : null,
//         backgroundColor: backgroundColor,
//         duration: duration,
//       ),
//     );
//   }
// }
