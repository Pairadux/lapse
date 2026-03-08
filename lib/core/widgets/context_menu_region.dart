import 'package:flutter/material.dart';

enum ContextMenuAction { edit, delete, move }

/// Default menu items shared across deck and card context menus.
const List<PopupMenuEntry<ContextMenuAction>> kDefaultContextMenuItems = [
  PopupMenuItem<ContextMenuAction>(
    value: ContextMenuAction.edit,
    child: Text('Edit'),
  ),
  PopupMenuItem<ContextMenuAction>(
    value: ContextMenuAction.delete,
    child: Text('Delete'),
  ),
  PopupMenuItem<ContextMenuAction>(
    value: ContextMenuAction.move,
    enabled: false,
    child: Text('Move (Coming soon)'),
  ),
];

/// Wraps a child widget with long-press and right-click context menu support.
///
/// Shows a popup menu anchored at the gesture position. Pass custom [menuItems]
/// to override the default edit/delete/move actions.
class ContextMenuRegion extends StatelessWidget {
  final Widget child;
  final ValueChanged<ContextMenuAction> onAction;
  final List<PopupMenuEntry<ContextMenuAction>>? menuItems;

  const ContextMenuRegion({
    super.key,
    required this.onAction,
    required this.child,
    this.menuItems,
  });

  Future<void> _show(BuildContext context, {Offset? globalPosition}) async {
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox;
    final target = context.findRenderObject();
    final anchorPosition =
        globalPosition ??
        (target is RenderBox
            ? target.localToGlobal(target.size.center(Offset.zero))
            : overlayBox.localToGlobal(overlayBox.size.center(Offset.zero)));

    final action = await showMenu<ContextMenuAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(anchorPosition.dx, anchorPosition.dy, 0, 0),
        Offset.zero & overlayBox.size,
      ),
      items: menuItems ?? kDefaultContextMenuItems,
    );
    if (action != null) onAction(action);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapDown: (details) =>
          _show(context, globalPosition: details.globalPosition),
      onLongPress: () => _show(context),
      child: child,
    );
  }
}
