import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/dev_drawer.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/Providers/deck_list_provider.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';
import 'package:lapse/features/decks/presentation/widgets/empty_deck_state.dart';

class DeckListScreen extends ConsumerStatefulWidget {
  const DeckListScreen({super.key});

  @override
  ConsumerState<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends ConsumerState<DeckListScreen> {
  // Navigation stack for breadcrumb (list of parent deck IDs)
  final List<Deck> _navigationStack = [];

  /// Recursively get all descendant deck IDs (including the given deck)
  List<String> _getAllDescendantDeckIds(
    List<Deck> decks,
    String deckId,
  ) {
    final result = <String>[deckId];
    final children = decks.where((d) => d.parentID == deckId);
    for (final child in children) {
      result.addAll(_getAllDescendantDeckIds(decks, child.deckID));
    }
    return result;
  }

  /// Get aggregated card count for a deck (including all descendants)
  int _getAggregatedCardCount(List<Deck> decks, String deckId) {
    final deckIds = _getAllDescendantDeckIds(decks, deckId);
    return deckIds.fold(0, (sum, id) {
      final deck = decks.firstWhere((d) => d.deckID == id);
      return sum + deck.cardCount;
    });
  }

  /// Get aggregated due count for a deck (including all descendants)
  int _getAggregatedDueCount(List<Deck> decks, String deckId) {
    final deckIds = _getAllDescendantDeckIds(decks, deckId);
    return deckIds.fold(0, (sum, id) {
      final deck = decks.firstWhere((d) => d.deckID == id);
      return sum + deck.dueCount;
    });
  }

  List<Deck> _currentDecks(List<Deck> decks) {
    final parentId = _navigationStack.isEmpty ? '' : _navigationStack.last.deckID;
    return decks.where((d) => d.parentID == parentId).toList();
  }

  bool _hasChildren(List<Deck> decks, Deck deck) {
    return decks.any((d) => d.parentID == deck.deckID);
  }

  void _navigateInto(List<Deck> decks, Deck deck) {
    if (_hasChildren(decks, deck)) {
      setState(() {
        _navigationStack.add(deck);
      });
    } else {
      // Navigate to study session for this deck
      context.go(
        Routes.studyPath(deck.deckID),
        extra: {'name': deck.deckName, 'deckIds': [deck.deckID]},
      );
    }
  }

  void _studyAll(List<Deck> decks) {
    if (_navigationStack.isEmpty) return;
    final currentDeck = _navigationStack.last;
    final allDeckIds = _getAllDescendantDeckIds(decks, currentDeck.deckID);
    // TODO: Apply daily limit and due date filtering here when scheduling is implemented
    context.go(
      Routes.studyPath(currentDeck.deckID),
      extra: {'name': currentDeck.deckName, 'deckIds': allDeckIds},
    );
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
    final deckState = ref.watch(deckListProvider);
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      drawer: const DevDrawer(),
      body: deckState.when(
        data: (decks) => Column(
          children: [
            if (_navigationStack.isNotEmpty) _buildBreadcrumb(),
            if (_navigationStack.isNotEmpty) _buildStudyAllBar(decks),
            Expanded(child: _buildDeckList(decks)),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(Spacing.lg),
            child: Text(
              'Failed to load decks: $error',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(Routes.deckNew),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStudyAllBar(List<Deck> decks) {
    final currentDeck = _navigationStack.last;
    final totalCards = _getAggregatedCardCount(decks, currentDeck.deckID);
    final totalDue = _getAggregatedDueCount(decks, currentDeck.deckID);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      color: AppColors.surface,
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$totalCards cards total • $totalDue due',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ),
          TextButton.icon(
            onPressed: () => _studyAll(decks),
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
            _BreadcrumbItem(
              label: 'Home',
              onTap: () => _navigateToIndex(-1),
            ),
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

  Widget _buildDeckList(List<Deck> decks) {
    final visibleDecks = _currentDecks(decks);

    if (visibleDecks.isEmpty) {
      return EmptyDeckState(
        isSubfolder: _navigationStack.isNotEmpty,
        onCreateDeck: () => context.go(Routes.deckNew),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: visibleDecks.length,
      itemBuilder: (context, index) {
        final deck = visibleDecks[index];
        final hasChildren = _hasChildren(decks, deck);
        return DeckCard(
          deck: deck,
          hasChildren: hasChildren,
          cardCount: hasChildren
              ? _getAggregatedCardCount(decks, deck.deckID)
              : deck.cardCount,
          dueCount:
              hasChildren ? _getAggregatedDueCount(decks, deck.deckID) : deck.dueCount,
          onTap: () => _navigateInto(decks, deck),
        );
      },
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  final String label;
  final bool isLast;
  final VoidCallback? onTap;

  const _BreadcrumbItem({
    required this.label,
    this.isLast = false,
    this.onTap,
  });

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
            child: Icon(
              Icons.chevron_right,
              size: Spacing.lg,
              color: AppColors.textTertiary,
            ),
          ),
      ],
    );
  }
}
