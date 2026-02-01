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
    final parentId = _navigationStack.isEmpty ? null : _navigationStack.last.deckID;
    // TODO: Filter by parentId when model supports it
    // For now, show all decks at root, none in subfolders (mock behavior)
    if (parentId == null) {
      return _mockDecks;
    }
    return []; // Empty for subfolders until parentId is implemented
  }

  bool _hasChildren(Deck deck) {
    // TODO: Check if deck has children when parentId is implemented
    // Mock: decks with "Languages" or "Science" in name have children
    return deck.deckName.contains('Languages') || deck.deckName.contains('Science');
  }

  void _navigateInto(Deck deck) {
    if (_hasChildren(deck)) {
      setState(() {
        _navigationStack.add(deck);
      });
    } else {
      // Navigate to card list for this deck
      context.go(Routes.deckPath(deck.deckID));
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

// Mock data generator - remove when providers are ready
List<Deck> _generateMockDecks() {
  final now = DateTime.now();
  return [
    Deck(
      deckID: '1',
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
      deckName: 'History 101',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 45,
      dueCount: 0,
    ),
    Deck(
      deckID: '4',
      deckName: 'Programming',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: [],
      cardCount: 200,
      dueCount: 32,
    ),
  ];
}
