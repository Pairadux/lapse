import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/dev_drawer.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';
import 'package:lapse/features/decks/presentation/widgets/empty_deck_state.dart';

class DeckListScreen extends StatefulWidget {
  const DeckListScreen({super.key});

  @override
  State<DeckListScreen> createState() => _DeckListScreenState();
}

class _DeckListScreenState extends State<DeckListScreen> {
  // Navigation stack for breadcrumb (list of parent deck IDs)
  final List<Deck> _navigationStack = [];

  // TODO: Replace with provider
  final List<Deck> _mockDecks = _generateMockDecks();

  List<Deck> get _currentDecks {
    final parentId = _navigationStack.isEmpty ? '' : _navigationStack.last.deckId;
    return _mockDecks.where((d) => d.parentId == parentId).toList();
  }

  bool _hasChildren(Deck deck) {
    return _mockDecks.any((d) => d.parentId == deck.deckId);
  }

  /// Recursively get all descendant deck IDs (including the given deck)
  List<String> _getAllDescendantDeckIds(String deckId) {
    final result = <String>[deckId];
    final children = _mockDecks.where((d) => d.parentId == deckId);
    for (final child in children) {
      result.addAll(_getAllDescendantDeckIds(child.deckId));
    }
    return result;
  }

  /// Get aggregated card count for a deck (including all descendants)
  int _getAggregatedCardCount(String deckId) {
    final deckIds = _getAllDescendantDeckIds(deckId);
    return deckIds.fold(0, (sum, id) {
      final deck = _mockDecks.firstWhere((d) => d.deckId == id);
      return sum + deck.cardCount;
    });
  }

  /// Get aggregated due count for a deck (including all descendants)
  int _getAggregatedDueCount(String deckId) {
    final deckIds = _getAllDescendantDeckIds(deckId);
    return deckIds.fold(0, (sum, id) {
      final deck = _mockDecks.firstWhere((d) => d.deckId == id);
      return sum + deck.dueCount;
    });
  }

  void _navigateInto(Deck deck) {
    if (_hasChildren(deck)) {
      setState(() {
        _navigationStack.add(deck);
      });
    } else {
      // Navigate to study session for this deck
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
    // TODO: Apply daily limit and due date filtering here when scheduling is implemented
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
      body: Column(
        children: [
          if (_navigationStack.isNotEmpty) _buildBreadcrumb(),
          if (_navigationStack.isNotEmpty) _buildStudyAllBar(),
          Expanded(child: _buildDeckList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(Routes.deckNew),
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
      return EmptyDeckState(isSubfolder: _navigationStack.isNotEmpty, onCreateDeck: () => context.go(Routes.deckNew));
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

// =============================================================================
// MOCK DATA - TODO: Remove when providers/state management are ready
// Card counts match mock cards in study_session_screen.dart
// =============================================================================
List<Deck> _generateMockDecks() {
  final now = DateTime.now();
  return [
    // Root-level decks (parentID: '')
    // Languages is a folder - no direct cards, children have 10 total
    Deck(
      deckId: '1',
      parentId: '',
      deckName: 'Languages',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 0,
      dueCount: 0,
    ),
    // Science is a folder - no direct cards, children have 6 total
    Deck(
      deckId: '2',
      parentId: '',
      deckName: 'Science',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 0,
      dueCount: 0,
    ),
    // History 101 is a leaf deck with 3 cards
    Deck(
      deckId: '3',
      parentId: '',
      deckName: 'History 101',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 3,
      dueCount: 3,
    ),
    // Nested under Languages (parentID: '1')
    Deck(
      deckId: '1-1',
      parentId: '1',
      deckName: 'Spanish',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 5,
      dueCount: 5,
    ),
    Deck(
      deckId: '1-2',
      parentId: '1',
      deckName: 'Japanese',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 5,
      dueCount: 5,
    ),
    // Nested under Science (parentID: '2')
    Deck(
      deckId: '2-1',
      parentId: '2',
      deckName: 'Biology',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 3,
      dueCount: 3,
    ),
    Deck(
      deckId: '2-2',
      parentId: '2',
      deckName: 'Chemistry',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 3,
      dueCount: 3,
    ),
  ];
}

// =============================================================================
