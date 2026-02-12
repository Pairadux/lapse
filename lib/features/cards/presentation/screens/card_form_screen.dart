import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_scaffold.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

class CardFormScreen extends StatefulWidget {
  final String deckId;
  final Flashcard? card;

  const CardFormScreen({super.key, required this.deckId, this.card});

  bool get isEditing => card != null;

  @override
  State<CardFormScreen> createState() => _CardFormScreenState();
}

class _CardFormScreenState extends State<CardFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _frontController;
  late final TextEditingController _backController;
  // TODO: Replace with state management provider
  final _repo = CardRepository();
  bool _saving = false;

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
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    try {
      if (widget.isEditing) {
        final updated = widget.card!.copyWith(
          front: _frontController.text.trim(),
          back: _backController.text.trim(),
        );
        // TODO: Replace with state management provider
        await _repo.update(updated);
      } else {
        final card = Flashcard.newCard(
          cardId: const Uuid().v4(),
          deckId: widget.deckId,
          front: _frontController.text.trim(),
          back: _backController.text.trim(),
        );
        // TODO: Replace with state management provider
        await _repo.create(card);
      }
      if (mounted) context.pop();
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

    // TODO: Replace with state management provider
    await _repo.delete(widget.card!.cardId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.isEditing ? 'Edit Card' : 'New Card',
      showBackButton: true,
      actions: [
        if (widget.isEditing)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _delete,
          ),
      ],
      body: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _frontController,
                autofocus: true,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Front',
                  hintText: 'Question or prompt',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Front is required' : null,
              ),
              const SizedBox(height: Spacing.lg),
              TextFormField(
                controller: _backController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Back',
                  hintText: 'Answer',
                  alignLabelWithHint: true,
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Back is required' : null,
              ),
              const SizedBox(height: Spacing.xl),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: Text(widget.isEditing ? 'Save' : 'Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
