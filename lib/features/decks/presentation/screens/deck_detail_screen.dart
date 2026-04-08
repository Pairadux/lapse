import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/route_observer.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_snack_bar.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/core/widgets/context_menu_region.dart';
import 'package:lapse/core/widgets/deck_picker_dialog.dart';
import 'package:lapse/core/widgets/empty_state_widget.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/core/widgets/speed_dial_fab.dart';
import 'package:lapse/features/decks/presentation/providers/deck_detail_provider.dart';
import 'package:lapse/features/decks/presentation/providers/deck_detail_state.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';
import 'package:lapse/features/decks/presentation/widgets/card_preview.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';

class DeckDetailScreen extends ConsumerStatefulWidget {
  final String deckId;
  final Deck? deck;
  final List<Deck>? initialAncestors;
  final int? initialCardCount;
  final int? initialDueCount;

  const DeckDetailScreen({
    super.key,
    required this.deckId,
    this.deck,
    this.initialAncestors,
    this.initialCardCount,
    this.initialDueCount,
  });

  @override
  ConsumerState<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends ConsumerState<DeckDetailScreen> with RouteAware {
  final ScrollController _breadcrumbScrollController = ScrollController();
  final ScrollController _cardsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _cardsScrollController.addListener(_onCardsScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _breadcrumbScrollController.dispose();
    _cardsScrollController.dispose();
    super.dispose();
  }

  /// Invalidate the provider when returning from a child route so we pick up
  /// any changes (card edits, new sub-decks, study session results, etc.).
  @override
  void didPopNext() {
    ref.invalidate(deckDetailProvider(widget.deckId));
  }

  void _onCardsScroll() {
    if (!_cardsScrollController.hasClients) return;

    const loadMoreThreshold = 320.0;
    final extentAfter = _cardsScrollController.position.extentAfter;
    if (extentAfter > loadMoreThreshold) return;

    final detail = ref.read(deckDetailProvider(widget.deckId)).asData?.value;
    if (detail == null || !detail.hasMoreCards || detail.isLoadingMoreCards) {
      return;
    }

    ref.read(deckDetailProvider(widget.deckId).notifier).loadMoreCards();
  }

  // ── Navigation helpers ──────────────────────────────────────────

  /// Rebuild the navigation stack to match the deck hierarchy.
  /// Stack becomes: home → ancestorChain[0] → ... → target.
  void _navigateWithAncestorStack(List<Deck> ancestorChain, Deck? target) {
    context.go(Routes.home);
    for (var i = 0; i < ancestorChain.length; i++) {
      context.push(
        Routes.deckPath(ancestorChain[i].deckId),
        extra: {'deck': ancestorChain[i], 'ancestors': ancestorChain.sublist(0, i)},
      );
    }
    if (target != null) {
      context.push(Routes.deckPath(target.deckId), extra: {'deck': target, 'ancestors': ancestorChain});
    }
  }

  // ── Actions ─────────────────────────────────────────────────────

  Future<void> _study(DeckDetailState detail) async {
    if (detail.totalCardCount == 0 || detail.totalDueCount == 0) {
      if (!mounted) return;
      final empty = detail.totalCardCount == 0;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(empty ? 'No cards yet' : 'All caught up!'),
          content: Text(empty ? 'Add some cards before studying.' : 'No cards are due right now.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
      return;
    }

    final allIds = await ref.read(deckRepositoryProvider).getDescendantIds(widget.deckId);
    if (mounted) {
      context.push(Routes.studyPath(widget.deckId), extra: {'name': detail.deck.deckName, 'deckIds': allIds});
    }
  }

  Future<void> _deleteDeck(DeckDetailState detail) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Delete deck?',
      message: 'This will delete "${detail.deck.deckName}" and all its cards.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await ref.read(deckRepositoryProvider).delete(widget.deckId);
    ref.invalidate(deckListProvider);
    if (!mounted) return;
    if (detail.ancestors.isNotEmpty) {
      _navigateWithAncestorStack(detail.ancestors.sublist(0, detail.ancestors.length - 1), detail.ancestors.last);
    } else {
      context.go(Routes.home);
    }
  }

  Future<void> _handleDeckContextAction(Deck deck, ContextMenuAction action) async {
    try {
      switch (action) {
        case ContextMenuAction.edit:
          context.push(Routes.deckEditPath(deck.deckId), extra: deck);
          break;
        case ContextMenuAction.delete:
          final confirmed = await ConfirmDialog.show(
            context: context,
            title: 'Delete deck?',
            message: 'This will delete "${deck.deckName}" and all its cards.',
            confirmLabel: 'Delete',
            isDestructive: true,
          );
          if (!confirmed || !mounted) return;
          await ref.read(deckDetailProvider(widget.deckId).notifier).deleteChildDeck(deck.deckId);
          break;
        case ContextMenuAction.move:
          final deckRepo = ref.read(deckRepositoryProvider);
          final allDecks = await deckRepo.getAll();
          final excludeIds = (await deckRepo.getDescendantIds(deck.deckId)).toSet();

          if (!mounted) return;
          final targetId = await DeckPickerDialog.show(
            context: context,
            decks: allDecks,
            excludeIds: excludeIds,
            currentParentId: deck.parentId,
            title: 'Move to',
            confirmLabel: 'Move',
          );
          if (targetId == null || !mounted) return;

          final newParentId = targetId.isEmpty ? null : targetId;
          if (newParentId == deck.parentId) return;

          final nameConflict = await deckRepo.nameExistsAtLevel(
            name: deck.deckName,
            parentId: newParentId,
            excludeDeckId: deck.deckId,
          );
          if (nameConflict) {
            if (!mounted) return;
            AppSnackBar.show(context, 'A deck named "${deck.deckName}" already exists there');
            return;
          }

          await ref.read(deckDetailProvider(widget.deckId).notifier).moveChildDeck(deck.deckId, newParentId);
          if (!mounted) return;
          AppSnackBar.show(context, 'Moved "${deck.deckName}"');
          break;
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Action failed: $e');
      }
    }
  }

  Future<void> _handleCardContextAction(Flashcard card, ContextMenuAction action) async {
    try {
      switch (action) {
        case ContextMenuAction.edit:
          context.push(Routes.cardPath(widget.deckId, card.cardId), extra: card);
          break;
        case ContextMenuAction.delete:
          final confirmed = await ConfirmDialog.show(
            context: context,
            title: 'Delete card?',
            message: 'This card will be deleted.',
            confirmLabel: 'Delete',
            isDestructive: true,
          );
          if (!confirmed || !mounted) return;
          await ref.read(deckDetailProvider(widget.deckId).notifier).deleteCard(card.cardId);
          break;
        case ContextMenuAction.move:
          final deckRepo = ref.read(deckRepositoryProvider);
          final allDecks = await deckRepo.getAll();

          if (!mounted) return;
          final targetId = await DeckPickerDialog.show(
            context: context,
            decks: allDecks,
            excludeIds: const <String>{},
            currentParentId: card.deckId,
            showRoot: false,
            title: 'Move to',
            confirmLabel: 'Move',
          );
          if (targetId == null || !mounted) return;
          if (targetId == card.deckId) return;

          await ref.read(deckDetailProvider(widget.deckId).notifier).moveCard(card.cardId, targetId);
          if (!mounted) return;
          AppSnackBar.show(context, 'Card moved');
          break;
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Action failed: $e');
      }
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final asyncDetail = ref.watch(deckDetailProvider(widget.deckId));

    return asyncDetail.when(
      loading: () => _buildScaffold(
        deckName: widget.deck?.deckName ?? 'Deck',
        deck: widget.deck,
        body: widget.deck == null ? const LoadingIndicator() : _buildOptimisticBody(),
      ),
      error: (e, _) {
        if (e is DeckNotFoundException) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              AppSnackBar.show(context, 'Deck not found');
              context.pop();
            }
          });
          return const SizedBox.shrink();
        }
        return _buildScaffold(
          deckName: 'Deck',
          body: Center(child: Text('Failed to load deck: $e')),
        );
      },
      data: (detail) =>
          _buildScaffold(deckName: detail.deck.deckName, deck: detail.deck, detail: detail, body: _buildBody(detail)),
    );
  }

  Widget _buildScaffold({required String deckName, Deck? deck, DeckDetailState? detail, required Widget body}) {
    return Scaffold(
      appBar: AppBar(
        title: Text(deckName),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: deck == null ? null : () => context.push(Routes.deckEditPath(widget.deckId), extra: deck),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: detail == null ? null : () => _deleteDeck(detail),
          ),
        ],
      ),
      body: body,
      floatingActionButton: SpeedDialFab(
        actions: [
          SpeedDialAction(
            icon: Icons.style_outlined,
            label: 'New Card',
            onPressed: () => context.push(Routes.cardNewPath(widget.deckId)),
          ),
          SpeedDialAction(
            icon: Icons.folder_outlined,
            label: 'New Deck',
            onPressed: () => context.push(Routes.deckNew, extra: widget.deckId),
          ),
        ],
      ),
    );
  }

  /// Shown while the provider is loading, using optimistic data from
  /// navigation extras so the header appears instantly.
  Widget _buildOptimisticBody() {
    final ancestors = widget.initialAncestors ?? [];
    return Column(
      children: [
        _buildHeader(
          ancestors: ancestors,
          deckName: widget.deck?.deckName ?? '',
          totalCardCount: widget.initialCardCount ?? 0,
          totalDueCount: widget.initialDueCount ?? 0,
          onStudy: null,
        ),
      ],
    );
  }

  Widget _buildBody(DeckDetailState detail) {
    final hasChildren = detail.children.isNotEmpty;
    final hasCards = detail.cards.isNotEmpty;
    final isEmpty = !hasChildren && !hasCards;

    if (isEmpty) {
      return Column(
        children: [
          _buildHeader(
            ancestors: detail.ancestors,
            deckName: detail.deck.deckName,
            totalCardCount: detail.totalCardCount,
            totalDueCount: detail.totalDueCount,
            onStudy: () => _study(detail),
          ),
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
      controller: _cardsScrollController,
      slivers: [
        SliverToBoxAdapter(
          child: _buildHeader(
            ancestors: detail.ancestors,
            deckName: detail.deck.deckName,
            totalCardCount: detail.totalCardCount,
            totalDueCount: detail.totalDueCount,
            onStudy: () => _study(detail),
          ),
        ),
        if (hasChildren) ...[
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final child = detail.children[index];
                return ContextMenuRegion(
                  onAction: (action) => _handleDeckContextAction(child.deck, action),
                  child: DeckCard(
                    deck: child.deck,
                    cardCount: child.cardCount,
                    dueCount: child.dueCount,
                    onTap: () {
                      context.push(
                        Routes.deckPath(child.deck.deckId),
                        extra: {
                          'deck': child.deck,
                          'ancestors': [...detail.ancestors, detail.deck],
                          'cardCount': child.cardCount,
                          'dueCount': child.dueCount,
                        },
                      );
                    },
                  ),
                );
              }, childCount: detail.children.length),
            ),
          ),
          if (hasCards)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
                child: Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
                      child: Text('Cards', style: Theme.of(context).textTheme.labelMedium),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
              ),
            ),
        ],
        if (hasCards)
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index < detail.cards.length) {
                  return _buildCardItem(detail.cards[index]);
                }
                return _buildLoadMoreIndicator(isLoading: detail.isLoadingMoreCards);
              }, childCount: detail.cards.length + (detail.hasMoreCards ? 1 : 0)),
            ),
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
      ],
    );
  }

  // ── Header (breadcrumb + stats) ─────────────────────────────────

  Widget _buildHeader({
    required List<Deck> ancestors,
    required String deckName,
    required int totalCardCount,
    required int totalDueCount,
    required VoidCallback? onStudy,
  }) {
    return Column(
      children: [
        _buildBreadcrumb(ancestors: ancestors, deckName: deckName),
        _buildStatsRow(totalCardCount: totalCardCount, totalDueCount: totalDueCount, onStudy: onStudy),
      ],
    );
  }

  void _scrollBreadcrumbToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_breadcrumbScrollController.hasClients && _breadcrumbScrollController.position.hasContentDimensions) {
        _breadcrumbScrollController.jumpTo(_breadcrumbScrollController.position.maxScrollExtent);
      }
    });
  }

  Widget _buildBreadcrumb({required List<Deck> ancestors, required String deckName}) {
    _scrollBreadcrumbToEnd();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      color: AppColors.surfaceElevated,
      child: SingleChildScrollView(
        controller: _breadcrumbScrollController,
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _BreadcrumbItem(label: 'Home', onTap: () => context.go(Routes.home)),
            for (var i = 0; i < ancestors.length; i++)
              _BreadcrumbItem(
                label: ancestors[i].deckName,
                onTap: () => _navigateWithAncestorStack(ancestors.sublist(0, i), ancestors[i]),
              ),
            _BreadcrumbItem(label: deckName, isLast: true),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow({required int totalCardCount, required int totalDueCount, required VoidCallback? onStudy}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.sm),
      child: Row(
        children: [
          Text('$totalCardCount cards', style: Theme.of(context).textTheme.bodyMedium),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
            child: Text('·', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textTertiary)),
          ),
          Text(
            '$totalDueCount due',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          FilledButton.tonalIcon(
            onPressed: onStudy,
            icon: const Icon(Icons.play_arrow, size: 18),
            label: const Text('Study'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreIndicator({required bool isLoading}) {
    if (!isLoading) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: Spacing.lg),
      child: LoadingIndicator(size: 20),
    );
  }

  Widget _buildCardItem(Flashcard card) {
    return ContextMenuRegion(
      onAction: (action) => _handleCardContextAction(card, action),
      child: InkWell(
        onTap: () => context.push(Routes.cardPath(widget.deckId, card.cardId), extra: card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg, vertical: Spacing.md),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  CardPreviewFactory.buildPreview(card),
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: Spacing.sm),
              const Icon(Icons.chevron_right, size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
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
            child: Icon(Icons.chevron_right, size: Spacing.lg, color: AppColors.textTertiary),
          ),
      ],
    );
  }
}
