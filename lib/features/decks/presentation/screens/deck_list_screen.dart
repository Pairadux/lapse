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
    final parentId = _navigationStack.isEmpty ? '' : _navigationStack.last.deckID;
    return _mockDecks.where((d) => d.parentID == parentId).toList();
  }

  bool _hasChildren(Deck deck) {
    return _mockDecks.any((d) => d.parentID == deck.deckID);
  }

  void _navigateInto(Deck deck) {
    if (_hasChildren(deck)) {
      setState(() {
        _navigationStack.add(deck);
      });
    } else {
      // Navigate to study session for this deck
      context.go(Routes.studyPath(deck.deckID), extra: deck.deckName);
    }
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      drawer: const DevDrawer(),
      body: Column(
        children: [
          if (_navigationStack.isNotEmpty) _buildBreadcrumb(),
          Expanded(child: _buildDeckList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go(Routes.deckNew),
        child: const Icon(Icons.add),
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

  Widget _buildDeckList() {
    final decks = _currentDecks;

    if (decks.isEmpty) {
      return EmptyDeckState(
        isSubfolder: _navigationStack.isNotEmpty,
        onCreateDeck: () => context.go(Routes.deckNew),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final deck = decks[index];
        return DeckCard(
          deck: deck,
          hasChildren: _hasChildren(deck),
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

// =============================================================================
// MOCK DATA - TODO: Remove when providers/state management are ready
// =============================================================================
List<Deck> _generateMockDecks() {
  final now = DateTime.now();
  return [
    // Root-level decks (parentID: '')
    Deck(
      deckID: '1',
      parentID: '',
      deckName: 'Languages',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 120,
      dueCount: 15,
    ),
    Deck(
      deckID: '2',
      parentID: '',
      deckName: 'Science',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 85,
      dueCount: 8,
    ),
    Deck(
      deckID: '3',
      parentID: '',
      deckName: 'History 101',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 45,
      dueCount: 3,
    ),
    // Nested under Languages (parentID: '1')
    Deck(
      deckID: '1-1',
      parentID: '1',
      deckName: 'Spanish',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 60,
      dueCount: 8,
    ),
    Deck(
      deckID: '1-2',
      parentID: '1',
      deckName: 'Japanese',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 60,
      dueCount: 7,
    ),
    // Nested under Science (parentID: '2')
    Deck(
      deckID: '2-1',
      parentID: '2',
      deckName: 'Biology',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 45,
      dueCount: 5,
    ),
    Deck(
      deckID: '2-2',
      parentID: '2',
      deckName: 'Chemistry',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 40,
      dueCount: 3,
    ),
  ];
}
// =============================================================================
