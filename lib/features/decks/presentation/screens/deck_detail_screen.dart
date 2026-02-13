import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/core/widgets/empty_state_widget.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';

enum _DetailTab { subDecks, cards }

class DeckDetailScreen extends StatefulWidget {
  final String deckId;
  final Deck? deck;

  const DeckDetailScreen({super.key, required this.deckId, this.deck});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final _deckRepo = DeckRepository();
  final _cardRepo = CardRepository();

  Deck? _deck;
  List<Deck> _ancestors = [];
  List<Deck> _children = [];
  List<Flashcard> _cards = [];
  bool _isLoading = true;
  _DetailTab _activeTab = _DetailTab.subDecks;

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final deck = await _deckRepo.getById(widget.deckId);
      if (deck == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deck not found')),
          );
          context.pop();
        }
        return;
      }

      final ancestors = await _deckRepo.getAncestors(widget.deckId);
      final children = await _deckRepo.getChildren(widget.deckId);
      final cards = await _cardRepo.getByDeckId(widget.deckId);

      // Hydrate children with card/due counts
      final hydratedChildren = <Deck>[];
      for (final child in children) {
        final childCards = await _cardRepo.getByDeckId(child.deckId);
        final childDue = await _cardRepo.getDueCards(child.deckId);
        hydratedChildren.add(child.copyWith(
          cardCount: childCards.length,
          dueCount: childDue.length,
        ));
      }

      if (mounted) {
        setState(() {
          _deck = deck.copyWith(
            cardCount: cards.length,
            dueCount: cards.where((c) => c.dueDate.isBefore(DateTime.now())).length,
          );
          _ancestors = ancestors;
          _children = hydratedChildren;
          _cards = cards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load deck: $e')),
        );
      }
    }
  }

  /// Recursively collects all descendant deck IDs (including this deck).
  Future<List<String>> _getAllDescendantDeckIds(String deckId) async {
    final result = <String>[deckId];
    final children = await _deckRepo.getChildren(deckId);
    for (final child in children) {
      result.addAll(await _getAllDescendantDeckIds(child.deckId));
    }
    return result;
  }

  Future<int> _getTotalDueCount() async {
    final allIds = await _getAllDescendantDeckIds(widget.deckId);
    var total = 0;
    for (final id in allIds) {
      final due = await _cardRepo.getDueCards(id);
      total += due.length;
    }
    return total;
  }

  Future<void> _study() async {
    final totalDue = await _getTotalDueCount();
    if (totalDue == 0) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('All caught up!'),
            content: const Text('No cards are due right now.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    final allIds = await _getAllDescendantDeckIds(widget.deckId);
    if (mounted) {
      await context.push(
        Routes.studyPath(widget.deckId),
        extra: {'name': _deck!.deckName, 'deckIds': allIds},
      );
      _loadData();
    }
  }

  Future<void> _deleteDeck() async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete deck?',
      message: 'This will permanently remove "${_deck!.deckName}" and all its cards.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await _deckRepo.delete(widget.deckId);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final deckName = _deck?.deckName ?? 'Deck';

    return Scaffold(
      appBar: AppBar(
        title: Text(deckName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _deck == null
                ? null
                : () async {
                    await context.push(
                      Routes.deckEditPath(widget.deckId),
                      extra: _deck,
                    );
                    _loadData();
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _deck == null ? null : _deleteDeck,
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                _buildBreadcrumb(),
                _buildSegmentedButton(),
                _buildStudyButton(),
                Expanded(
                  child: _activeTab == _DetailTab.subDecks
                      ? _buildSubDecks()
                      : _buildCards(),
                ),
              ],
            ),
      floatingActionButton: _isLoading
          ? null
          : FloatingActionButton(
              onPressed: () async {
                if (_activeTab == _DetailTab.subDecks) {
                  await context.push(Routes.deckNew, extra: widget.deckId);
                } else {
                  await context.push(Routes.cardNewPath(widget.deckId));
                }
                _loadData();
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  Widget _buildBreadcrumb() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      color: AppColors.surfaceElevated,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _BreadcrumbItem(
              label: 'Home',
              onTap: () {
                // Pop all the way back to home
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            ..._ancestors.asMap().entries.map((entry) {
              final depth = entry.key;
              return _BreadcrumbItem(
                label: entry.value.deckName,
                onTap: () {
                  // Pop back to this ancestor's depth
                  // We need to pop (ancestors.length - depth) times
                  final popCount = _ancestors.length - depth;
                  for (var i = 0; i < popCount; i++) {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                  }
                },
              );
            }),
            _BreadcrumbItem(
              label: _deck?.deckName ?? '',
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentedButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<_DetailTab>(
          segments: [
            ButtonSegment(
              value: _DetailTab.subDecks,
              label: Text('Sub-decks (${_children.length})'),
              icon: const Icon(Icons.folder_outlined, size: 18),
            ),
            ButtonSegment(
              value: _DetailTab.cards,
              label: Text('Cards (${_cards.length})'),
              icon: const Icon(Icons.style_outlined, size: 18),
            ),
          ],
          selected: {_activeTab},
          onSelectionChanged: (selected) {
            setState(() => _activeTab = selected.first);
          },
        ),
      ),
    );
  }

  Widget _buildStudyButton() {
    return FutureBuilder<int>(
      future: _getTotalDueCount(),
      builder: (context, snapshot) {
        final totalDue = snapshot.data ?? 0;
        final label = _children.isNotEmpty
            ? 'Study All ($totalDue due)'
            : 'Study ($totalDue due)';

        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg,
            vertical: Spacing.xs,
          ),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _study,
              icon: const Icon(Icons.play_arrow),
              label: Text(label),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubDecks() {
    if (_children.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.folder_open,
        title: 'No sub-decks yet',
        subtitle: 'Create a sub-deck to organize your cards',
        actionLabel: 'Create Deck',
        onAction: () async {
          await context.push(Routes.deckNew, extra: widget.deckId);
          _loadData();
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: _children.length,
      itemBuilder: (context, index) {
        final child = _children[index];
        return DeckCard(
          deck: child,
          hasChildren: false, // Will be updated on detail load
          onTap: () async {
            await context.push(
              Routes.deckPath(child.deckId),
              extra: child,
            );
            _loadData();
          },
        );
      },
    );
  }

  Widget _buildCards() {
    if (_cards.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.style_outlined,
        title: 'No cards yet',
        subtitle: 'Add cards to start studying',
        actionLabel: 'Add Card',
        onAction: () async {
          await context.push(Routes.cardNewPath(widget.deckId));
          _loadData();
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
      itemCount: _cards.length,
      itemBuilder: (context, index) {
        final card = _cards[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: Spacing.cardMarginH,
            vertical: Spacing.cardMarginV,
          ),
          child: InkWell(
            onTap: () async {
              await context.push(
                Routes.cardPath(widget.deckId, card.cardId),
                extra: card,
              );
              _loadData();
            },
            borderRadius: BorderRadius.circular(Spacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(Spacing.cardPadding),
              child: Row(
                children: [
                  Container(
                    width: Spacing.iconContainerSize,
                    height: Spacing.iconContainerSize,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(Spacing.radiusMd),
                    ),
                    child: const Icon(
                      Icons.style,
                      color: AppColors.textSecondary,
                      size: Spacing.iconSize,
                    ),
                  ),
                  const SizedBox(width: Spacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          card.front,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: Spacing.xs),
                        Text(
                          card.back,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textTertiary,
                  ),
                ],
              ),
            ),
          ),
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
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(Spacing.radiusSm),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isLast ? AppColors.textPrimary : AppColors.primary,
                  fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
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
