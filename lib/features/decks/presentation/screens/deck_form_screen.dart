import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_scaffold.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';

class DeckFormScreen extends StatefulWidget {
  final Deck? deck;
  final String? parentId;

  const DeckFormScreen({super.key, this.deck, this.parentId});

  bool get isEditing => deck != null;

  @override
  State<DeckFormScreen> createState() => _DeckFormScreenState();
}

class _DeckFormScreenState extends State<DeckFormScreen> {
  static const int maxDeckNameLength = 50;

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
      final name = _nameController.text.trim();
      final parentId = widget.isEditing ? widget.deck!.parentId : widget.parentId;
      final duplicate = await _repo.nameExistsAtLevel(
        name: name,
        parentId: parentId,
        excludeDeckId: widget.deck?.deckId,
      );
      if (duplicate) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A deck with this name already exists here')),
          );
        }
        return;
      }

      if (widget.isEditing) {
        final updated = widget.deck!.copyWith(deckName: name);
        // TODO: Replace with state management provider
        await _repo.update(updated);
      } else {
        final deck = Deck.create(deckName: name, parentId: widget.parentId);
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
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                maxLength: maxDeckNameLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
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
