import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

import '../theme/app_colors.dart';
import '../theme/spacing.dart';

/// Centralized toast helper for consistent styling across the app.
///
/// Uses toastification's overlay system instead of Scaffold's built-in SnackBar
/// so toasts render independently of the FAB — no pushing, no overlap.
///
/// Safe area and FAB alignment are handled by the [ToastificationConfig]
/// in main.dart (zero margin + viewPadding) plus [Spacing.lg] bottom padding
/// here — matching the Scaffold's 16dp FAB inset on all platforms.
abstract class AppSnackBar {
  static void show(
    BuildContext context,
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 4),
  }) {
    toastification.showCustom(
      context: context,
      alignment: Alignment.bottomLeft,
      autoCloseDuration: duration,
      builder: (context, holder) {
        return Padding(
          padding: const EdgeInsets.only(
            left: Spacing.lg,
            right: Spacing.lg,
            bottom: Spacing.lg,
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
