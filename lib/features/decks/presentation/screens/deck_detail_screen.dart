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
import 'package:lapse/core/widgets/speed_dial_fab.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';

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
  Map<String, (int, int)> _childCounts = {};
  List<Flashcard> _cards = [];
  int _totalCardCount = 0;
  int _totalDueCount = 0;
  bool _hasLoaded = false;

  @override
  void initState() {
    super.initState();
    _deck = widget.deck;
    _loadData();
  }

  @override
  void dispose() {
    _breadcrumbScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Run independent queries in parallel
      final results = await Future.wait([
        _deckRepo.getById(widget.deckId),
        _deckRepo.getAncestors(widget.deckId),
        _deckRepo.getChildren(widget.deckId),
        _cardRepo.getByDeckId(widget.deckId),
      ]);

      final deck = results[0] as Deck?;
      if (deck == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Deck not found')),
          );
          context.pop();
        }
        return;
      }

      final ancestors = results[1] as List<Deck>;
      final children = results[2] as List<Deck>;
      final cards = results[3] as List<Flashcard>;

      // Hydrate children with aggregated counts in parallel
      final childCountFutures = children.map(
        (child) => _getAggregatedCounts(child.deckId),
      );
      final totalCountsFuture = _getAggregatedCounts(widget.deckId);
      final allCounts = await Future.wait([
        Future.wait(childCountFutures.toList()),
        totalCountsFuture,
      ]);

      final childCounts = allCounts[0] as List<(int, int)>;
      final totalCounts = allCounts[1] as (int, int);

      final childCountMap = <String, (int, int)>{};
      for (var i = 0; i < children.length; i++) {
        childCountMap[children[i].deckId] = childCounts[i];
      }

      if (mounted) {
        setState(() {
          _deck = deck;
          _ancestors = ancestors;
          _children = children;
          _childCounts = childCountMap;
          _cards = cards;
          _totalCardCount = totalCounts.$1;
          _totalDueCount = totalCounts.$2;
          _hasLoaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _hasLoaded = true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load deck: $e')),
        );
      }
    }
  }

  /// Returns (totalCards, totalDue) across a deck and all descendants.
  Future<(int, int)> _getAggregatedCounts(String deckId) async {
    final allIds = await _deckRepo.getDescendantIds(deckId);
    var cards = 0;
    var due = 0;
    for (final id in allIds) {
      final counts = await Future.wait([
        _cardRepo.countByDeckId(id),
        _cardRepo.countDueByDeckId(id),
      ]);
      cards += counts[0];
      due += counts[1];
    }
    return (cards, due);
  }

  Future<void> _study() async {
    if (_totalCardCount == 0 || _totalDueCount == 0) {
      if (mounted) {
        final empty = _totalCardCount == 0;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(empty ? 'No cards yet' : 'All caught up!'),
            content: Text(empty
                ? 'Add some cards before studying.'
                : 'No cards are due right now.'),
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

    final allIds = await _deckRepo.getDescendantIds(widget.deckId);
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
      message:
          'This will permanently remove "${_deck!.deckName}" and all its cards.',
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
      body: _deck == null
          ? const LoadingIndicator()
          : _buildBody(),
      floatingActionButton: SpeedDialFab(
        actions: [
          SpeedDialAction(
            icon: Icons.style_outlined,
            label: 'New Card',
            onPressed: () async {
              await context.push(Routes.cardNewPath(widget.deckId));
              _loadData();
            },
          ),
          SpeedDialAction(
            icon: Icons.folder_outlined,
            label: 'New Deck',
            onPressed: () async {
              await context.push(Routes.deckNew, extra: widget.deckId);
              _loadData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final hasChildren = _children.isNotEmpty;
    final hasCards = _cards.isNotEmpty;
    final isEmpty = !hasChildren && !hasCards;

    if (isEmpty) {
      return Column(
        children: [
          _buildHeader(),
          if (_hasLoaded)
            const Expanded(
              child: EmptyStateWidget(
                icon: Icons.style_outlined,
                title: 'No cards yet',
                subtitle: 'Tap + to add your first card',
              ),
            ),
        ],
      );
    }

    return CustomScrollView(
      slivers: [
        // Header (breadcrumb + stats)
        SliverToBoxAdapter(child: _buildHeader()),
        // Sub-decks section
        if (hasChildren) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final child = _children[index];
                  final counts = _childCounts[child.deckId];
                  return DeckCard(
                    deck: child,
                    cardCount: counts?.$1 ?? 0,
                    dueCount: counts?.$2 ?? 0,
                    onTap: () async {
                      await context.push(
                        Routes.deckPath(child.deckId),
                        extra: child,
                      );
                      _loadData();
                    },
                  );
                },
                childCount: _children.length,
              ),
            ),
          ),
          // Divider between sub-decks and cards
          if (hasCards)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: Spacing.md),
                      child: Text(
                        'Cards',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
            ),
        ],
        // Cards section
        if (hasCards)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildCardItem(_cards[index]),
                childCount: _cards.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        _buildBreadcrumb(),
        _buildStatsRow(),
      ],
    );
  }

  final ScrollController _breadcrumbScrollController = ScrollController();

  void _scrollBreadcrumbToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_breadcrumbScrollController.hasClients) {
        _breadcrumbScrollController.jumpTo(
          _breadcrumbScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  Widget _buildBreadcrumb() {
    _scrollBreadcrumbToEnd();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      color: AppColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _breadcrumbScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _BreadcrumbItem(
              label: 'Home',
              onTap: () => context.go(Routes.home),
            ),
            ..._ancestors.map((ancestor) {
              return _BreadcrumbItem(
                label: ancestor.deckName,
                onTap: () => context.push(
                  Routes.deckPath(ancestor.deckId),
                  extra: ancestor,
                ),
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

  Widget _buildStatsRow() {
    final cardLabel = '$_totalCardCount cards';
    final dueLabel = '$_totalDueCount due';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.lg,
        vertical: Spacing.sm,
      ),
      child: Row(
        children: [
          Text(
            cardLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Text(
              '·',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.textTertiary),
            ),
          ),
          Text(
            dueLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: _study,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Study'),
          ),
        ],
      ),
    );
  }

  Widget _buildCardItem(Flashcard card) {
    return InkWell(
      onTap: () async {
        await context.push(
          Routes.cardPath(widget.deckId, card.cardId),
          extra: card,
        );
        _loadData();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: card.front,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    TextSpan(
                      text: '  →  ',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textTertiary),
                    ),
                    TextSpan(
                      text: card.back,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: Spacing.sm),
            const Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isLast ? AppColors.textPrimary : AppColors.primary,
                    fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
