import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/core/widgets/context_menu_region.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';

Future<void> handleDeckContextAction({
  required BuildContext context,
  required Deck deck,
  required ContextMenuAction action,
  required DeckRepository deckRepository,
  required Future<void> Function() onChanged,
}) async {
  try {
    switch (action) {
      case ContextMenuAction.edit:
        await context.push(Routes.deckEditPath(deck.deckId), extra: deck);
        if (context.mounted) await onChanged();
        break;
      case ContextMenuAction.delete:
        final confirmed = await ConfirmDialog.show(
          context: context,
          title: 'Delete deck?',
          message: 'This will delete "${deck.deckName}" and all its cards.',
          confirmLabel: 'Delete',
          isDestructive: true,
        );
        if (!confirmed || !context.mounted) return;
        await deckRepository.delete(deck.deckId);
        if (context.mounted) await onChanged();
        break;
      case ContextMenuAction.move:
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Move action is coming soon')),
        );
        break;
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }
}
