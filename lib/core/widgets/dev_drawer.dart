import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:lapse/features/import_export/data/import_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/sync/sync_pull_service.dart';
import 'package:lapse/core/widgets/app_snack_bar.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/core/widgets/deck_picker_dialog.dart';
import 'package:lapse/features/import_export/data/export_service.dart';


class DevDrawer extends StatelessWidget {
  final VoidCallback? onDataChanged;

  const DevDrawer({super.key, this.onDataChanged});

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
    await SyncPullService.resetLastPullTimestamp();
    if (context.mounted) {
      Navigator.pop(context);
      onDataChanged?.call();
      AppSnackBar.show(context, 'Database cleared');
    }
  }

  Future<void> _loadMockData(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Load mock data?',
      message: 'This will add sample decks and cards. Existing data is kept.',
      confirmLabel: 'Load',
    );
    if (!confirmed || !context.mounted) return;

    await _insertMockData();
    if (context.mounted) {
      Navigator.pop(context);
      onDataChanged?.call();
      AppSnackBar.show(context, 'Mock data loaded');
    }
  }

  Future<void> _insertMockData() async {
    final db = await DatabaseHelper.instance.database;
    final deckRepo = DeckRepository();
    final cardRepo = CardRepository();

    // Root decks
    final spanish = Deck.create(deckName: 'Spanish');
    final programming = Deck.create(deckName: 'Programming');

    // Sub-decks
    final vocab = Deck.create(deckName: 'Vocabulary', parentId: spanish.deckId);
    final grammar = Deck.create(deckName: 'Grammar', parentId: spanish.deckId);
    final dart = Deck.create(deckName: 'Dart', parentId: programming.deckId);

    final seedDecks = [spanish, programming, vocab, grammar, dart];

    // Cards
    final mockCards = <(String, String, String)>[
      (vocab.deckId, 'Hola', 'Hello'),
      (vocab.deckId, 'Adiós', 'Goodbye'),
      (vocab.deckId, 'Gracias', 'Thank you'),
      (vocab.deckId, 'Por favor', 'Please'),
      (vocab.deckId, 'Buenos días', 'Good morning'),
      (grammar.deckId, 'Ser vs Estar', 'Ser = permanent, Estar = temporary'),
      (
        grammar.deckId,
        'Preterite vs Imperfect',
        'Preterite = completed, Imperfect = ongoing/habitual',
      ),
      (
        dart.deckId,
        'final vs const',
        'final = runtime constant, const = compile-time constant',
      ),
      (
        dart.deckId,
        'Null safety operator',
        'Use ? for nullable, ! for assertion, ?? for fallback',
      ),
      (
        dart.deckId,
        'async/await',
        'async marks a function as returning a Future, await pauses until it completes',
      ),
      (programming.deckId, 'Big O of binary search', 'O(log n)'),
      (programming.deckId, 'SOLID - S', 'Single Responsibility Principle'),
    ];

    final seedFlashcards = [
      for (final (deckId, front, back) in mockCards)
        Flashcard.newCard(deckId: deckId, front: front, back: back),
    ];

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final deck in seedDecks) {
        batch.insert(DatabaseConstants.tableDecks, deck.toMap());
      }
      for (final card in seedFlashcards) {
        batch.insert(DatabaseConstants.tableCards, card.toMap());
      }
      await batch.commit(noResult: true);
    });

    await _insertEdgeCaseData(deckRepo, cardRepo);
  }

  /// Programmatically generated edge case data for UI stress testing.
  Future<void> _insertEdgeCaseData(
    DeckRepository deckRepo,
    CardRepository cardRepo,
  ) async {
    // -- Deep nesting: 8 levels deep to stress breadcrumb scrolling --
    const nestingDepth = 8;
    String? parentId;
    String deepLeafDeckId = '';
    for (var i = 1; i <= nestingDepth; i++) {
      final deck = Deck.create(
        deckName: 'Nesting Level $i',
        parentId: parentId,
      );
      await deckRepo.create(deck);
      parentId = deck.deckId;
      deepLeafDeckId = deck.deckId;
    }
    // Add a card in the deepest deck so it's studyable
    await cardRepo.create(
      Flashcard.newCard(
        deckId: deepLeafDeckId,
        front: 'Deep card front',
        back: 'Deep card back',
      ),
    );

    // -- Max-length content: names and card text at the enforced limits --
    // These lengths must stay in sync with the limits in DeckFormScreen
    // and CardFormScreen (currently 50 and 300 respectively).
    const maxDeckNameLength = 50;
    const maxCardTextLength = 300;

    final maxNameDeck = Deck.create(deckName: 'A' * maxDeckNameLength);
    await deckRepo.create(maxNameDeck);

    await cardRepo.create(
      Flashcard.newCard(
        deckId: maxNameDeck.deckId,
        front: 'F' * maxCardTextLength,
        back: 'B' * maxCardTextLength,
      ),
    );

    // -- Large card count: 200 cards to stress list rendering --
    const bulkCardCount = 200;
    final bulkDeck = Deck.create(deckName: 'Bulk Cards ($bulkCardCount)');
    await deckRepo.create(bulkDeck);

    for (var i = 1; i <= bulkCardCount; i++) {
      await cardRepo.create(
        Flashcard.newCard(
          deckId: bulkDeck.deckId,
          front: 'Card $i front',
          back: 'Card $i back',
        ),
      );
    }

    // -- Minimal content: single character to test layout with short text --
    final minimalDeck = Deck.create(deckName: 'X');
    await deckRepo.create(minimalDeck);

    await cardRepo.create(
      Flashcard.newCard(deckId: minimalDeck.deckId, front: 'A', back: 'B'),
    );
  }

  Future<void> _exportDeck(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final cardRepo = CardRepository();
    final deckRepo = DeckRepository();
    final allDecks = await deckRepo.getAll();

    if (!context.mounted) return;
    final selectedId = await DeckPickerDialog.show(
      context: context,
      decks: allDecks,
      excludeIds: {},
      showRoot: false,
    );
    if (selectedId == null) return;
    final selectedDeck = allDecks.firstWhere((d) => d.deckId == selectedId);
    final exporter = DeckExportService();
    final csv = await exporter.exportDeckWithRepositories(
      selectedDeck, cardRepo, deckRepo,
    );

    final safeName = selectedDeck.deckName
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    var exported = false;

    if (Platform.isAndroid || Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$safeName.csv');
      await file.writeAsString(csv);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')]);
      exported = true;
    } else {
      final location = await getSaveLocation(
        suggestedName: '$safeName.csv',
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location != null) {
        final file = File(location.path);
        await file.writeAsString(csv);
        exported = true;
      }
    }
    if (exported) {
      messenger.showSnackBar(const SnackBar(content: Text('Export complete')));
    }
  }

  Future<void> _importDeck(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final importer = DeckImportService(DeckRepository(), CardRepository());

    try {
      await importer.importDeckFromCSV(file);
      if (context.mounted) {
        onDataChanged?.call();
        messenger.showSnackBar(
          const SnackBar(content: Text('Import complete')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
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
          _DrawerItem(
            icon: Icons.bar_chart,
            label: 'Review Stats',
            route: Routes.devStats,
          ),
          _DrawerItem(
            icon: Icons.cloud_outlined,
            label: 'Supabase Dev',
            route: Routes.devSupabase,
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
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Trigger Snackbar'),
            onTap: () {
              Scaffold.of(context).closeDrawer();
              AppSnackBar.show(context, 'Test snackbar message');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: const Text('Import'),
            onTap: () => _importDeck(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: const Text('Export'),
            onTap: () => _exportDeck(context),
          ),
          const Divider(),
          const _AnimationSpeedSlider(),
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
        context.push(route);
      },
    );
  }
}

class _AnimationSpeedSlider extends StatefulWidget {
  const _AnimationSpeedSlider();

  @override
  State<_AnimationSpeedSlider> createState() => _AnimationSpeedSliderState();
}

class _AnimationSpeedSliderState extends State<_AnimationSpeedSlider> {
  double _dilation = timeDilation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.slow_motion_video, size: 20),
              const SizedBox(width: 8),
              Text(
                'Animation Slowdown',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Text(
                _dilation == 1.0
                    ? 'Off'
                    : '${_dilation.toStringAsFixed(1)}x slower',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Slider(
            value: _dilation,
            min: 1.0,
            max: 20.0,
            divisions: 38,
            onChanged: (value) {
              setState(() => _dilation = value);
              timeDilation = value;
            },
          ),
        ],
      ),
    );
  }
}
