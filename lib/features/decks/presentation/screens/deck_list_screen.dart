import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/context_menu_region.dart';
import 'package:lapse/core/widgets/dev_drawer.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/actions/deck_context_actions.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';
import 'package:lapse/features/decks/presentation/widgets/empty_deck_state.dart';

class DeckListScreen extends ConsumerStatefulWidget {
  const DeckListScreen({super.key});

  @override
  ConsumerState<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends ConsumerState<DeckListScreen> {
  DeckRepository get _deckRepo => ref.read(deckRepositoryProvider);
  CardRepository get _cardRepo => ref.read(cardRepositoryProvider);

  List<Deck> _rootDecks = [];
  Map<String, (int, int)> _deckCounts = {};
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    try {
      final rootDecks = await _deckRepo.getRootDecks();

      // Compute aggregated counts for all root decks in parallel
      final countFutures = rootDecks.map((deck) async {
        final allIds = await _deckRepo.getDescendantIds(deck.deckId);
        var totalCards = 0;
        var totalDue = 0;
        for (final id in allIds) {
          final counts = await Future.wait([
            _cardRepo.countByDeckId(id),
            _cardRepo.countDueByDeckId(id),
          ]);
          totalCards += counts[0];
          totalDue += counts[1];
        }
        return (deck.deckId, totalCards, totalDue);
      });

      final results = await Future.wait(countFutures);
      final countsMap = <String, (int, int)>{
        for (final (id, cards, due) in results) id: (cards, due),
      };

      if (mounted) {
        setState(() {
          _rootDecks = rootDecks;
          _deckCounts = countsMap;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasLoaded = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load decks: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: kDebugMode
            ? Builder(
                builder: (ctx) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(ctx).openDrawer(),
                ),
              )
            : null,
        title: const Text('Decks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      drawer: kDebugMode ? DevDrawer(onDataChanged: _loadDecks) : null,
      body: (!_hasLoaded && _rootDecks.isEmpty)
          ? const SizedBox.shrink()
          : _buildDeckList(),
      floatingActionButton: FloatingActionButton(
        heroTag: 'deck_list_fab',
        onPressed: () async {
          await context.push(Routes.deckNew);
          _loadDecks();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDeckList() {
    if (_rootDecks.isEmpty) {
      return EmptyDeckState(
        onCreateDeck: () async {
          await context.push(Routes.deckNew);
          _loadDecks();
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: _rootDecks.length,
      itemBuilder: (context, index) {
        final deck = _rootDecks[index];
        final counts = _deckCounts[deck.deckId];
        return ContextMenuRegion(
          onAction: (action) => handleDeckContextAction(
            context: context,
            deck: deck,
            action: action,
            deckRepository: _deckRepo,
            onChanged: _loadDecks,
          ),
          child: DeckCard(
            deck: deck,
            cardCount: counts?.$1 ?? 0,
            dueCount: counts?.$2 ?? 0,
            onTap: () async {
              await context.push(Routes.deckPath(deck.deckId), extra: deck);
              _loadDecks();
            },
          ),
        );
      },
    );
  }
}
