import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_scaffold.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

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

  @override
  void initState() {
    super.initState();
    _frontController = TextEditingController(text: widget.card?.front ?? '');
    _backController = TextEditingController(text: widget.card?.back ?? '');
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
        content: const Text(
          'A card with this front already exists in this deck. Save anyway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save anyway'),
          ),
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
      if (frontEmpty || backEmpty) {
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
        final updated = widget.card!.copyWith(
          front: _frontController.text.trim(),
          back: _backController.text.trim(),
        );
        await _repo.update(updated);
      } else {
        final card = Flashcard.newCard(
          deckId: widget.deckId,
          front: _frontController.text.trim(),
          back: _backController.text.trim(),
        );
        await _repo.create(card);
      }
      if (mounted) {
        final label = widget.isEditing
            ? 'Card updated'
            : _createdCount > 0
                ? '${_createdCount + 1} cards created'
                : 'Card created';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(label),
            duration: const Duration(seconds: 2),
          ),
        );
        context.pop();
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
      final card = Flashcard.newCard(
        deckId: widget.deckId,
        front: _frontController.text.trim(),
        back: _backController.text.trim(),
      );
      await _repo.create(card);

      if (mounted) {
        setState(() {
          _createdCount++;
          _showPreview = false;
          _frontController.clear();
          _backController.clear();
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _frontFocus.requestFocus();
        });
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
    if (mounted) context.pop();
  }

  void _goBack() {
    if (_createdCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$_createdCount card${_createdCount == 1 ? '' : 's'} created',
          ),
          duration: const Duration(seconds: 2),
        ),
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
            icon: Icon(
              _showPreview ? Icons.edit_outlined : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _showPreview = !_showPreview),
          ),
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
        body: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter, shift: true):
                _SaveAndAddAnotherIntent(),
            SingleActivator(LogicalKeyboardKey.enter, alt: true):
                _SaveIntent(),
          },
          child: Actions(
            actions: {
              _SaveIntent: CallbackAction<_SaveIntent>(
                onInvoke: (intent) {
                  _save();
                  return null;
                },
              ),
              _SaveAndAddAnotherIntent:
                  CallbackAction<_SaveAndAddAnotherIntent>(
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
                  Expanded(
                    child: _showPreview
                        ? _buildPreviewContent()
                        : _buildEditContent(),
                  ),
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        TextFormField(
          controller: _frontController,
          focusNode: _frontFocus,
          autofocus: true,
          onChanged: (_) => setState(() {}),
          maxLines: 4,
          maxLength: maxCardTextLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: const InputDecoration(
            labelText: 'Front',
            hintText: 'Question or prompt (Markdown supported)',
            alignLabelWithHint: true,
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Front is required'
              : null,
        ),
        const SizedBox(height: Spacing.lg),
        TextFormField(
          controller: _backController,
          onChanged: (_) => setState(() {}),
          maxLines: 4,
          maxLength: maxCardTextLength,
          maxLengthEnforcement: MaxLengthEnforcement.enforced,
          decoration: const InputDecoration(
            labelText: 'Back',
            hintText: 'Answer (Markdown supported)',
            alignLabelWithHint: true,
          ),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? 'Back is required'
              : null,
        ),
        const SizedBox(height: Spacing.md),
        Text(
          'Markdown: **bold**, *italic*, `code`, - list item',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
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
    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        _buildPreviewField(
          label: 'Front',
          text: _frontController.text,
          placeholder: '_No front text_',
        ),
        const SizedBox(height: Spacing.lg),
        const Divider(),
        const SizedBox(height: Spacing.lg),
        _buildPreviewField(
          label: 'Back',
          text: _backController.text,
          placeholder: '_No back text_',
        ),
      ],
    );
  }

  Widget _buildPreviewField({
    required String label,
    required String text,
    required String placeholder,
  }) {
    final hasContent = text.trim().isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: Spacing.sm),
        MarkdownBody(
          data: hasContent ? text : placeholder,
          styleSheet:
              MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Action buttons — always pinned at the bottom of the screen.
  // ---------------------------------------------------------------------------

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Spacing.lg,
        Spacing.md,
        Spacing.lg,
        Spacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.outlineVariant,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.isEditing) ...[
              OutlinedButton(
                onPressed: _saving ? null : _saveAndAddAnother,
                child: const Text('Save & Add Another'),
              ),
              const SizedBox(height: Spacing.sm),
            ],
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(widget.isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
