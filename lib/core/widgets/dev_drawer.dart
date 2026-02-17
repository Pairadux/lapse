import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import '../routing/routes.dart';

class DevDrawer extends StatelessWidget {
  const DevDrawer({super.key});

  Future<void> _clearDatabase(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Clear database?',
      message: 'This will permanently delete all decks, cards, and reviews.',
      confirmLabel: 'Clear',
      isDestructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await DatabaseHelper.instance.clearAllData();
    if (context.mounted) {
      Navigator.pop(context);
      context.go(Routes.home);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Database cleared')),
      );
    }
  }

  Future<void> _loadMockData(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Load mock data?',
      message:
          'This will add sample decks and cards. Existing data is kept.',
      confirmLabel: 'Load',
    );
    if (!confirmed || !context.mounted) return;

    await _insertMockData();
    if (context.mounted) {
      Navigator.pop(context);
      context.go(Routes.home);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mock data loaded')),
      );
    }
  }

  Future<void> _insertMockData() async {
    const uuid = Uuid();
    final deckRepo = DeckRepository();
    final cardRepo = CardRepository();
    final now = DateTime.now();

    // Root decks
    final spanish = Deck(
      deckId: uuid.v4(), deckName: 'Spanish',
      createdAt: now, updatedAt: now, cards: [], cardCount: 0, dueCount: 0,
    );
    final programming = Deck(
      deckId: uuid.v4(), deckName: 'Programming',
      createdAt: now, updatedAt: now, cards: [], cardCount: 0, dueCount: 0,
    );

    // Sub-decks
    final vocab = Deck(
      deckId: uuid.v4(), parentId: spanish.deckId, deckName: 'Vocabulary',
      createdAt: now, updatedAt: now, cards: [], cardCount: 0, dueCount: 0,
    );
    final grammar = Deck(
      deckId: uuid.v4(), parentId: spanish.deckId, deckName: 'Grammar',
      createdAt: now, updatedAt: now, cards: [], cardCount: 0, dueCount: 0,
    );
    final dart = Deck(
      deckId: uuid.v4(), parentId: programming.deckId, deckName: 'Dart',
      createdAt: now, updatedAt: now, cards: [], cardCount: 0, dueCount: 0,
    );

    for (final deck in [spanish, programming, vocab, grammar, dart]) {
      await deckRepo.create(deck);
    }

    // Cards
    final mockCards = <(String, String, String)>[
      (vocab.deckId, 'Hola', 'Hello'),
      (vocab.deckId, 'Adiós', 'Goodbye'),
      (vocab.deckId, 'Gracias', 'Thank you'),
      (vocab.deckId, 'Por favor', 'Please'),
      (vocab.deckId, 'Buenos días', 'Good morning'),
      (grammar.deckId, 'Ser vs Estar', 'Ser = permanent, Estar = temporary'),
      (grammar.deckId, 'Preterite vs Imperfect', 'Preterite = completed, Imperfect = ongoing/habitual'),
      (dart.deckId, 'final vs const', 'final = runtime constant, const = compile-time constant'),
      (dart.deckId, 'Null safety operator', 'Use ? for nullable, ! for assertion, ?? for fallback'),
      (dart.deckId, 'async/await', 'async marks a function as returning a Future, await pauses until it completes'),
      (programming.deckId, 'Big O of binary search', 'O(log n)'),
      (programming.deckId, 'SOLID - S', 'Single Responsibility Principle'),
    ];

    for (final (deckId, front, back) in mockCards) {
      await cardRepo.create(Flashcard.newCard(
        cardId: uuid.v4(), deckId: deckId, front: front, back: back,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Dev Navigation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Navigate between screens',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _DrawerItem(
            icon: Icons.bug_report,
            label: 'Widget Preview',
            route: Routes.debug,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: const Text('Load Mock Data'),
            onTap: () => _loadMockData(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Clear Database'),
            onTap: () => _clearDatabase(context),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isActive = currentRoute == route;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isActive,
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
