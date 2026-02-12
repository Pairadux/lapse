import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/app_colors.dart';
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
  final List<Deck> _navigationStack = [];

  // TODO: Replace with state management provider
  final _deckRepo = DeckRepository();
  final _cardRepo = CardRepository();

  List<Deck> _allDecks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDecks();
  }

  Future<void> _loadDecks() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with state management provider
      final decks = await _deckRepo.getAll();
      final updatedDecks = <Deck>[];
      for (final deck in decks) {
        // TODO: Replace with state management provider
        final cards = await _cardRepo.getByDeckId(deck.deckId);
        final dueCards = await _cardRepo.getDueCards(deck.deckId);
        updatedDecks.add(deck.copyWith(
          cardCount: cards.length,
          dueCount: dueCards.length,
        ));
      }
      if (mounted) {
        setState(() {
          _allDecks = updatedDecks;
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

  Future<void> _refreshDecks() async {
    await _loadDecks();
  }

  List<Deck> get _currentDecks {
    final parentId = _navigationStack.isEmpty ? null : _navigationStack.last.deckId;
    return _allDecks.where((d) => d.parentId == parentId).toList();
  }

  bool _hasChildren(Deck deck) {
    return _allDecks.any((d) => d.parentId == deck.deckId);
  }

  /// Recursively get all descendant deck IDs (including the given deck)
  List<String> _getAllDescendantDeckIds(String deckId) {
    final result = <String>[deckId];
    final children = _allDecks.where((d) => d.parentId == deckId);
    for (final child in children) {
      result.addAll(_getAllDescendantDeckIds(child.deckId));
    }
    return result;
  }

  /// Get aggregated card count for a deck (including all descendants)
  int _getAggregatedCardCount(String deckId) {
    final deckIds = _getAllDescendantDeckIds(deckId);
    return deckIds.fold(0, (sum, id) {
      final deck = _allDecks.firstWhere((d) => d.deckId == id);
      return sum + deck.cardCount;
    });
  }

  /// Get aggregated due count for a deck (including all descendants)
  int _getAggregatedDueCount(String deckId) {
    final deckIds = _getAllDescendantDeckIds(deckId);
    return deckIds.fold(0, (sum, id) {
      final deck = _allDecks.firstWhere((d) => d.deckId == id);
      return sum + deck.dueCount;
    });
  }

  void _navigateInto(Deck deck) {
    if (_hasChildren(deck)) {
      setState(() {
        _navigationStack.add(deck);
      });
    } else {
      context.go(
        Routes.studyPath(deck.deckId),
        extra: {
          'name': deck.deckName,
          'deckIds': [deck.deckId],
        },
      );
    }
  }

  void _studyAll() {
    if (_navigationStack.isEmpty) return;
    final currentDeck = _navigationStack.last;
    final allDeckIds = _getAllDescendantDeckIds(currentDeck.deckId);
    context.go(Routes.studyPath(currentDeck.deckId), extra: {'name': currentDeck.deckName, 'deckIds': allDeckIds});
  }

  void _navigateToIndex(int index) {
    if (index == -1) {
      setState(() {
        _navigationStack.clear();
      });
    } else {
      setState(() {
        _navigationStack.removeRange(index + 1, _navigationStack.length);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_navigationStack.isEmpty ? 'Decks' : _navigationStack.last.deckName),
        leading: _navigationStack.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _navigateToIndex(_navigationStack.length - 2),
              )
            : null,
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => context.push(Routes.settings)),
        ],
      ),
      drawer: const DevDrawer(),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                if (_navigationStack.isNotEmpty) _buildBreadcrumb(),
                if (_navigationStack.isNotEmpty) _buildStudyAllBar(),
                Expanded(child: _buildDeckList()),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push(Routes.deckNew);
          _refreshDecks();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStudyAllBar() {
    final currentDeck = _navigationStack.last;
    final totalCards = _getAggregatedCardCount(currentDeck.deckId);
    final totalDue = _getAggregatedDueCount(currentDeck.deckId);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalCards cards total • $totalDue due',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton.icon(
            onPressed: _studyAll,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Study All'),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      color: AppColors.surfaceElevated,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _BreadcrumbItem(label: 'Home', onTap: () => _navigateToIndex(-1)),
            ..._navigationStack.asMap().entries.map((entry) {
              final index = entry.key;
              final deck = entry.value;
              final isLast = index == _navigationStack.length - 1;
              return _BreadcrumbItem(
                label: deck.deckName,
                isLast: isLast,
                onTap: isLast ? null : () => _navigateToIndex(index),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDeckList() {
    final decks = _currentDecks;

    if (decks.isEmpty) {
      return EmptyDeckState(isSubfolder: _navigationStack.isNotEmpty, onCreateDeck: () async {
        await context.push(Routes.deckNew);
        _refreshDecks();
      });
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        final hasChildren = _hasChildren(deck);
        return DeckCard(
          deck: deck,
          hasChildren: hasChildren,
          cardCount: hasChildren ? _getAggregatedCardCount(deck.deckId) : deck.cardCount,
          dueCount: hasChildren ? _getAggregatedDueCount(deck.deckId) : deck.dueCount,
          onTap: () => _navigateInto(deck),
        );
      },
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  const _BreadcrumbItem({required this.label, this.isLast = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: GestureDetector(
            onTap: onTap,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isLast ? AppColors.textPrimary : AppColors.primary,
                fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Icon(Icons.chevron_right, size: Spacing.lg, color: AppColors.textTertiary),
          ),
      ],
    );
  }
}
