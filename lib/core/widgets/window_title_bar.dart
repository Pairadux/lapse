import 'package:flutter/material.dart';
import 'package:modern_titlebar_buttons/modern_titlebar_buttons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';

class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({super.key});

  Future<void> _toggleMaximize() async {
    if (await windowManager.isMaximized()) {
      debugPrint('[titlebar] unmaximize');
      await windowManager.unmaximize();
    } else {
      debugPrint('[titlebar] maximize');
      await windowManager.maximize();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      child: SizedBox(
        height: 36,
        child: Row(
          children: [
            // Draggable title area
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => windowManager.startDragging(),
                onDoubleTap: _toggleMaximize,
                child: Padding(
                  padding: const EdgeInsets.only(left: Spacing.md),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Lapse',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            // Window controls — outside the drag GestureDetector
            DecoratedMinimizeButton(
              onPressed: () {
                debugPrint('[titlebar] minimize');
                windowManager.minimize();
              },
            ),
            DecoratedMaximizeButton(
              onPressed: () {
                debugPrint('[titlebar] maximize/restore');
                _toggleMaximize();
              },
            ),
            DecoratedCloseButton(
              onPressed: () {
                debugPrint('[titlebar] close');
                windowManager.close();
              },
            ),
            const SizedBox(width: Spacing.xs),
          ],
        ),
      ),
    );
  }
}
