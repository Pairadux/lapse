import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_scaffold.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';

class DeckFormScreen extends StatefulWidget {
  final Deck? deck;

  const DeckFormScreen({super.key, this.deck});

  bool get isEditing => deck != null;

  @override
  State<DeckFormScreen> createState() => _DeckFormScreenState();
}

class _DeckFormScreenState extends State<DeckFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  // TODO: Replace with state management provider
  final _repo = DeckRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.deck?.deckName ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);

    try {
      if (widget.isEditing) {
        final updated = widget.deck!.copyWith(deckName: _nameController.text.trim());
        // TODO: Replace with state management provider
        await _repo.update(updated);
      } else {
        final now = DateTime.now();
        final deck = Deck(
          deckId: const Uuid().v4(),
          deckName: _nameController.text.trim(),
          createdAt: now,
          updatedAt: now,
          cards: [],
          cardCount: 0,
          dueCount: 0,
        );
        // TODO: Replace with state management provider
        await _repo.create(deck);
      }
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete deck?',
      message: 'This will permanently remove "${widget.deck!.deckName}" and all its cards.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    // TODO: Replace with state management provider
    await _repo.delete(widget.deck!.deckId);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: widget.isEditing ? 'Edit Deck' : 'New Deck',
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Deck name',
                  hintText: 'e.g. Spanish Vocabulary',
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Name is required' : null,
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
