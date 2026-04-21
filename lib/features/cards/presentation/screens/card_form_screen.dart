import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_scaffold.dart';
import 'package:lapse/core/widgets/app_snack_bar.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/presentation/providers/deck_detail_provider.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';
import 'package:lapse/features/study/presentation/widgets/card_content.dart';

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _SaveAndAddAnotherIntent extends Intent {
  const _SaveAndAddAnotherIntent();
}

class CardFormScreen extends ConsumerStatefulWidget {
  final String deckId;
  final Flashcard? card;

  const CardFormScreen({super.key, required this.deckId, this.card});

  bool get isEditing => card != null;

  @override
  ConsumerState<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends ConsumerState<CardFormScreen> {
  static const int maxCardTextLength = 300;

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  final _frontFocus = FocusNode();
  CardRepository get _repo => ref.read(cardRepositoryProvider);
  bool _saving = false;
  int _createdCount = 0;
  bool _showPreview = false;
  CardType _cardType = CardType.twoSided;

  @override
  void initState() {
    super.initState();
    _cardType = widget.card?.cardType ?? CardType.twoSided;

    switch (widget.card) {
      case TwoSidedCard(:final front, :final back):
        _frontController = TextEditingController(text: front);
        _backController = TextEditingController(text: back);
      case ReverseCard(:final front, :final back):
        _frontController = TextEditingController(text: front);
        _backController = TextEditingController(text: back);
      case ClozeCard(:final text):
        _frontController = TextEditingController(text: text);
        _backController = TextEditingController(text: '');
      case null:
        _frontController = TextEditingController();
        _backController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _frontFocus.dispose();
    super.dispose();
  }

  /// Returns true if the user confirms saving despite a duplicate, or if
  /// no duplicate exists.
  Future<bool> _checkDuplicate() async {
    final front = _frontController.text.trim();
    if (front.isEmpty) return true;
    final exists = await _repo.frontExistsInDeck(
      front: front,
      deckId: widget.deckId,
      excludeCardId: widget.card?.cardId,
    );
    if (!exists || !mounted) return true;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate card'),
        content: const Text('A card with this front already exists in this deck. Save anyway?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save anyway')),
        ],
      ),
    );
    return proceed == true;
  }

  /// Validates fields, switching back to edit mode to show errors if needed.
  bool _validateFields() {
    if (_showPreview) {
      final frontEmpty = _frontController.text.trim().isEmpty;
      final backEmpty = _backController.text.trim().isEmpty;
      final isCloze = _cardType == CardType.cloze;
      if (frontEmpty || (!isCloze && backEmpty)) {
        setState(() => _showPreview = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _formKey.currentState?.validate();
        });
        return false;
      }
      return true;
    }
    return _formKey.currentState!.validate();
  }

  Future<void> _save() async {
  if (!_validateFields() || _saving) return;
  if (!await _checkDuplicate()) return;
  setState(() => _saving = true);
  try {
    if (widget.isEditing) {
      final updated = switch (widget.card!) {
        TwoSidedCard c => c.copyWith(
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        ReverseCard c => c.copyWith(
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        ClozeCard c => c.copyWith(
            text: _frontController.text.trim(),
          ),
      };
      await _repo.update(updated);
    } else {
      final card = switch (_cardType) {
        // these need user ID which seems to be an auth isssue
        CardType.twoSided => TwoSidedCard.newCard(
            deckId: widget.deckId,
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        CardType.reverse => ReverseCard.newCard(
            deckId: widget.deckId,
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        CardType.cloze => ClozeCard.newCard(
            deckId: widget.deckId,
            text: _frontController.text.trim(),
          ),
      };
      await _repo.create(card);
    }
    ref.invalidate(deckDetailProvider(widget.deckId));
      ref.invalidate(deckListProvider);
      ref.read(syncServiceProvider.notifier).schedulePush();
      if (mounted) {
        setState(() {
      _createdCount++;
      _frontController.clear();
      _backController.clear();
      });
      AppSnackBar.show(context, '$_createdCount card(s) created', duration: const Duration(seconds: 2));
      }
  } finally {
    if (mounted) setState(() => _saving = false);
  }

}

  Future<void> _saveAndAddAnother() async {
    if (!_validateFields() || _saving) return;
    if (!await _checkDuplicate()) return;
    setState(() => _saving = true);

    try {
    if (widget.isEditing) {
      final updated = switch (widget.card!) {
        TwoSidedCard c => c.copyWith(
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        ReverseCard c => c.copyWith(
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        ClozeCard c => c.copyWith(
            text: _frontController.text.trim(),
          ),
      };
      await _repo.update(updated);
    } else {
      final card = switch (_cardType) {
        CardType.twoSided => TwoSidedCard.newCard(
            deckId: widget.deckId,
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        CardType.reverse => ReverseCard.newCard(
            deckId: widget.deckId,
            front: _frontController.text.trim(),
            back: _backController.text.trim(),
          ),
        CardType.cloze => ClozeCard.newCard(
            deckId: widget.deckId,
            text: _frontController.text.trim(),
          ),
      };
      await _repo.create(card);
    }
      ref.invalidate(deckDetailProvider(widget.deckId));
      ref.invalidate(deckListProvider);
      ref.read(syncServiceProvider.notifier).schedulePush();
      if (mounted) {
        setState(() {
      _createdCount++;
      _frontController.clear();
      _backController.clear();
      });
      AppSnackBar.show(context, '$_createdCount card(s) created', duration: const Duration(seconds: 2));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete card?',
      message: 'This card will be permanently removed.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    await _repo.delete(widget.card!.cardId);
    ref.invalidate(deckDetailProvider(widget.deckId));
    ref.invalidate(deckListProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
    if (mounted) context.pop();
  }

  void _goBack() {
    if (_createdCount > 0) {
      AppSnackBar.show(
        context,
        '$_createdCount card${_createdCount == 1 ? '' : 's'} created',
        duration: const Duration(seconds: 2),
      );
    }
    context.pop();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _createdCount == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: AppScaffold(
        title: widget.isEditing ? 'Edit Card' : 'New Card',
        showBackButton: true,
        onBack: _goBack,
        actions: [
          IconButton(
            icon: Icon(_showPreview ? Icons.edit_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
          if (widget.isEditing) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
        body: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter, shift: true): _SaveAndAddAnotherIntent(),
            SingleActivator(LogicalKeyboardKey.enter, alt: true): _SaveIntent(),
          },
          child: Actions(
            actions: {
              _SaveIntent: CallbackAction<_SaveIntent>(
                onInvoke: (intent) {
                  _save();
                  return null;
                },
              ),
              _SaveAndAddAnotherIntent: CallbackAction<_SaveAndAddAnotherIntent>(
                onInvoke: (intent) {
                  if (widget.isEditing) {
                    _save();
                  } else {
                    _saveAndAddAnother();
                  }
                  return null;
                },
              ),
            },
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(child: _showPreview ? _buildPreviewContent() : _buildEditContent()),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Edit pane — text fields for the current card type.
  //
  // Future card types (cloze, image, etc.) can override or replace this
  // content via a card-type-specific editor widget.
  // ---------------------------------------------------------------------------

  Widget _buildEditContent() {
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        if (_createdCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: Spacing.lg),
            child: Text(
              '$_createdCount card${_createdCount == 1 ? '' : 's'} added',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        DropdownButtonFormField<CardType>(
          initialValue: _cardType,
          decoration: const InputDecoration(labelText: 'Card Type'),
          items: CardType.values.map((type) {
            return DropdownMenuItem(value: type, child: Text(_getCardTypeDisplayName(type)));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _cardType = value);
            }
          },
        ),
        const SizedBox(height: Spacing.lg),
        TextFormField(
          controller: _frontController,
          focusNode: _frontFocus,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          maxLines: 4,
          maxLength: maxCardTextLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: InputDecoration(
            labelText: 'Front',
            hintText: _getFrontHintText(_cardType),
            alignLabelWithHint: true,
          ),
          validator: (value) => (value == null || value.trim().isEmpty) ? 'Front is required' : null,
        ),
        const SizedBox(height: Spacing.lg),
        if (_cardType != CardType.cloze)
          TextFormField(
            controller: _backController,
            onChanged: (_) => setState(() {}),
            maxLines: 4,
            maxLength: maxCardTextLength,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            decoration: InputDecoration(
              labelText: 'Back',
              hintText: _getBackHintText(_cardType),
              alignLabelWithHint: true,
            ),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Back is required' : null,
          ),
        const SizedBox(height: Spacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                '**bold**  *italic*  `code`  # heading  - list  > quote',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ),
            const SizedBox(width: Spacing.sm),
            GestureDetector(
              onTap: () => setState(() => _showPreview = true),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_outlined, size: 14, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(
                    'Preview',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textTertiary,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preview pane — rendered markdown for the current card type.
  //
  // Future card types will provide their own preview widgets (e.g. cloze
  // with blanked portions, image cards with thumbnails, etc.).
  // ---------------------------------------------------------------------------

  Widget _buildPreviewContent() {
    // Create a temporary card for preview based on selected card type
    final now = DateTime.now();
    final previewCard = switch (_cardType) {
      CardType.twoSided => TwoSidedCard(
          cardId: 'preview',
          deckId: 'preview',
          front: _frontController.text.trim(),
          back: _backController.text.trim(),
          createdAt: now,
          updatedAt: now,
          dueDate: now,
          stability: 0.0,
          difficulty: 0.0,
          elapsedDays: 0,
          scheduledDays: 0,
          reps: 0,
          lapses: 0,
          cardState: CardState.newCard,
          isDeleted: false,
          syncStatus: SyncStatus.synced,
          userId: '', // preview card
        ),
      CardType.reverse => ReverseCard(
          cardId: 'preview',
          deckId: 'preview',
          front: _frontController.text.trim(),
          back: _backController.text.trim(),
          createdAt: now,
          updatedAt: now,
          dueDate: now,
          stability: 0.0,
          difficulty: 0.0,
          elapsedDays: 0,
          scheduledDays: 0,
          reps: 0,
          lapses: 0,
          cardState: CardState.newCard,
          isDeleted: false,
          syncStatus: SyncStatus.synced,
          userId: '', // preview card
        ),
      CardType.cloze => ClozeCard(
          cardId: 'preview',
          deckId: 'preview',
          text: _frontController.text.trim(),
          createdAt: now,
          updatedAt: now,
          dueDate: now,
          stability: 0.0,
          difficulty: 0.0,
          elapsedDays: 0,
          scheduledDays: 0,
          reps: 0,
          lapses: 0,
          cardState: CardState.newCard,
          isDeleted: false,
          syncStatus: SyncStatus.synced,
          userId: '', // preview card
        ),
    };

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _buildPreviewField(label: 'Front Preview', child: CardContentFactory.buildFront(previewCard)),
        const SizedBox(height: Spacing.lg),
        const Divider(),
        const SizedBox(height: Spacing.lg),
        if (_cardType != CardType.cloze)
          _buildPreviewField(label: 'Back Preview', child: CardContentFactory.buildBack(previewCard)),
      ],
    );
  }

  Widget _buildPreviewField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: Spacing.sm),
        Container(
          constraints: const BoxConstraints(minHeight: 200),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.outlineVariant),
            borderRadius: BorderRadius.circular(Spacing.radiusMd),
          ),
          child: child,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons — always pinned at the bottom of the screen.
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.md, Spacing.lg, Spacing.lg),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.outlineVariant, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isEditing) ...[
              OutlinedButton(
                onPressed: _saving
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _saveAndAddAnother();
                      },
                child: const Text('Save & Add Another'),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            ElevatedButton(
              onPressed: _saving
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      _save();
                    },
              child: Text(widget.isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCardTypeDisplayName(CardType type) {
    switch (type) {
      case CardType.twoSided:
        return 'Standard front and back card';
      case CardType.cloze:
        return 'Cloze Deletion';
      case CardType.reverse:
        return 'Reverse (both sides can be front or back)';
    }
  }

  String _getFrontHintText(CardType type) {
    switch (type) {
      case CardType.twoSided:
        return 'Question or prompt (Markdown supported)';
      case CardType.reverse:
        return 'Both sides can appear as front or back.';
      case CardType.cloze:
        return 'Text with {{c1::answer}} for cloze deletions';
    }
  }

  String _getBackHintText(CardType type) {
    switch (type) {
      case CardType.twoSided:
        return 'Answer (Markdown supported)';
      case CardType.reverse:
        return 'Both sides can appear as front or back.';
      case CardType.cloze:
        throw StateError('$type cards do not have a back field');
    }
  }
}
