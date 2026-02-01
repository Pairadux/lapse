import 'package:flutter/material.dart';
import 'package:lapse/core/widgets/empty_state_widget.dart';

class EmptyDeckState extends StatelessWidget {
  final VoidCallback onCreateDeck;
  final bool isSubfolder;

  const EmptyDeckState({
    super.key,
    required this.onCreateDeck,
    this.isSubfolder = false,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: isSubfolder ? Icons.folder_open : Icons.style_outlined,
      title: isSubfolder ? 'No decks here yet' : 'No decks yet',
      subtitle: isSubfolder
          ? 'Create a deck or subfolder to organize your cards'
          : 'Create your first deck to start studying',
      actionLabel: 'Create Deck',
      onAction: onCreateDeck,
    );
  }
}
