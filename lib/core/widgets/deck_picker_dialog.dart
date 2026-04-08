import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import '../../features/decks/domain/deck.dart';

/// Dialog for selecting a deck from the deck tree.
///
/// Returns the selected deck ID via [show]:
/// - `null` = cancelled
/// - `''` (empty) = root level
/// - non-empty = specific deck ID
class DeckPickerDialog extends StatefulWidget {
  final List<Deck> decks;
  final Set<String> excludeIds;
  final String? currentParentId;
  final bool showRoot;
  final String title;
  final String confirmLabel;

  /// When true, any selection is valid — there's no "current" location to
  /// prevent reselecting. Use for import/export where there's no origin.
  final bool allowReselect;

  const DeckPickerDialog({
    super.key,
    required this.decks,
    required this.excludeIds,
    this.currentParentId,
    this.showRoot = true,
    this.title = 'Select deck',
    this.confirmLabel = 'Select',
    this.allowReselect = false,
  });

  static Future<String?> show({
    required BuildContext context,
    required List<Deck> decks,
    required Set<String> excludeIds,
    String? currentParentId,
    bool showRoot = true,
    String title = 'Select deck',
    String confirmLabel = 'Select',
    bool allowReselect = false,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => DeckPickerDialog(
        decks: decks,
        excludeIds: excludeIds,
        currentParentId: currentParentId,
        showRoot: showRoot,
        title: title,
        confirmLabel: confirmLabel,
        allowReselect: allowReselect,
      ),
    );
  }

  @override
  State<DeckPickerDialog> createState() => _DeckPickerDialogState();
}

class _DeckPickerDialogState extends State<DeckPickerDialog> {
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.showRoot ? '' : null;
  }

  /// Whether a valid selection has been made.
  bool get _hasSelection {
    if (_selectedId == null) return false;
    if (widget.allowReselect) return true;
    // Root selected and current parent is already root.
    if (_selectedId!.isEmpty && widget.currentParentId == null) return false;
    // Specific deck selected that matches current parent.
    if (_selectedId == widget.currentParentId) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final available = widget.decks
        .where((d) => !widget.excludeIds.contains(d.deckId))
        .toList();

    // Group decks by parentId to build the tree.
    final childrenMap = <String?, List<Deck>>{};
    for (final deck in available) {
      childrenMap.putIfAbsent(deck.parentId, () => []).add(deck);
    }

    final treeItems = <Widget>[
      if (widget.showRoot)
        _buildTile(
          label: 'Root (top level)',
          icon: Icons.home_outlined,
          id: '',
          indent: 0,
          isCurrent: !widget.allowReselect && widget.currentParentId == null,
        ),
      ..._buildTree(childrenMap, null, 0),
    ];

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: treeItems.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: Spacing.lg),
                child: Text(
                  'No destinations available',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView(shrinkWrap: true, children: treeItems),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        if (_hasSelection)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_selectedId),
            child: Text(widget.confirmLabel),
          )
        else
          TextButton(
            onPressed: null,
            child: Text(widget.confirmLabel),
          ),
      ],
    );
  }

  List<Widget> _buildTree(
    Map<String?, List<Deck>> childrenMap,
    String? parentId,
    int depth,
  ) {
    final children = childrenMap[parentId];
    if (children == null) return const [];

    final widgets = <Widget>[];
    for (final deck in children) {
      widgets.add(_buildTile(
        label: deck.deckName,
        icon: Icons.folder_outlined,
        id: deck.deckId,
        indent: depth + 1,
        isCurrent: !widget.allowReselect && widget.currentParentId == deck.deckId,
      ));
      widgets.addAll(_buildTree(childrenMap, deck.deckId, depth + 1));
    }
    return widgets;
  }

  Widget _buildTile({
    required String label,
    required IconData icon,
    required String id,
    required int indent,
    required bool isCurrent,
  }) {
    final isSelected = _selectedId == id;
    final isNewSelection = isSelected && !isCurrent;

    return Padding(
      padding: EdgeInsets.only(left: Spacing.lg * indent),
      child: Material(
        color: isNewSelection
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(Spacing.radiusSm),
        child: InkWell(
          onTap: isCurrent ? null : () => setState(() => _selectedId = id),
          borderRadius: BorderRadius.circular(Spacing.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.sm,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isNewSelection
                      ? AppColors.primary
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: Spacing.sm),
                Expanded(
                  child: Text(
                    isCurrent ? '$label (current)' : label,
                    style: TextStyle(
                      color: isCurrent
                          ? AppColors.textTertiary
                          : isNewSelection
                              ? AppColors.primary
                              : AppColors.textPrimary,
                      fontWeight:
                          isNewSelection ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check, size: 18, color: AppColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
