import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/dev_drawer.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';
import 'package:lapse/features/decks/presentation/widgets/empty_deck_state.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  // TODO: Replace with state management provider
  final _deckRepo = DeckRepository();
  final _cardRepo = CardRepository();

  List<Deck> _rootDecks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      final decks = await _deckRepo.getAll();
      final rootDecks = decks.where((d) => d.parentId == null).toList();
      final hydrated = <Deck>[];
      for (final deck in rootDecks) {
        final allIds = await _deckRepo.getDescendantIds(deck.deckId);
        var totalCards = 0;
        var totalDue = 0;
        for (final id in allIds) {
          final c = await _cardRepo.getByDeckId(id);
          final d = await _cardRepo.getDueCards(id);
          totalCards += c.length;
          totalDue += d.length;
        }
        hydrated.add(deck.copyWith(
          cardCount: totalCards,
          dueCount: totalDue,
        ));
      }
      if (mounted) {
        setState(() {
          _rootDecks = hydrated;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load decks: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Decks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      drawer: const DevDrawer(),
      body: _isLoading ? const LoadingIndicator() : _buildDeckList(),
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
      return EmptyDeckState(onCreateDeck: () async {
        await context.push(Routes.deckNew);
        _loadDecks();
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: _rootDecks.length,
      itemBuilder: (context, index) {
        final deck = _rootDecks[index];
        return DeckCard(
          deck: deck,
          onTap: () async {
            await context.push(Routes.deckPath(deck.deckId), extra: deck);
            _loadDecks();
          },
        );
      },
    );
  }
}
