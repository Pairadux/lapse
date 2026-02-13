import 'package:flutter/material.dart';
import 'package:modern_titlebar_buttons/modern_titlebar_buttons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      onDoubleTap: () async {
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      },
      child: Container(
        height: 36,
        color: AppColors.surface,
        child: Row(
          children: [
            const SizedBox(width: Spacing.md),
            Text(
              'Lapse',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            DecoratedMinimizeButton(
              onPressed: () => windowManager.minimize(),
            ),
            DecoratedMaximizeButton(
              onPressed: () async {
                if (await windowManager.isMaximized()) {
                  await windowManager.unmaximize();
                } else {
                  await windowManager.maximize();
                }
              },
            ),
            DecoratedCloseButton(
              onPressed: () => windowManager.close(),
            ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
      ),
    );
  }
}
