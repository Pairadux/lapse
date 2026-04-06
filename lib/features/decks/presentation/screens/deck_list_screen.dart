import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/routes.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_snack_bar.dart';
import 'package:lapse/core/widgets/confirm_dialog.dart';
import 'package:lapse/core/widgets/context_menu_region.dart';
import 'package:lapse/core/widgets/deck_picker_dialog.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/decks/data/deck_repository_provider.dart';
import 'package:lapse/core/widgets/dev_drawer.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/domain/deck_with_counts.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';
import 'package:lapse/features/decks/presentation/widgets/deck_card.dart';
import 'package:lapse/features/decks/presentation/widgets/empty_deck_state.dart';
import 'package:lapse/features/study/presentation/providers/review_streak_provider.dart';

class DeckListScreen extends ConsumerWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncDecks = ref.watch(deckListProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: kDebugMode ? () => Scaffold.of(ctx).openDrawer() : null,
          ),
        ),
        title: const Text('Decks'),
        actions: [
          const _StreakAppBarAction(),
          IconButton(
            icon: const Icon(Icons.view_list),
            tooltip: 'View all cards',
            onPressed: () => context.push(Routes.cardBrowser),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(Routes.settings),
          ),
        ],
      ),
      drawer: kDebugMode
          ? DevDrawer(onDataChanged: () => ref.invalidate(deckListProvider))
          : null,
      body: asyncDecks.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => Center(child: Text('Failed to load decks: $e')),
        data: (decks) => _DeckList(decks: decks),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'deck_list_fab',
        onPressed: () async {
          await context.push(Routes.deckNew);
          ref.invalidate(deckListProvider);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _StreakAppBarAction extends ConsumerWidget {
  const _StreakAppBarAction();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streakAsync = ref.watch(reviewStreakProvider);

    return streakAsync.when(
      data: (streak) {
        if (streak.currentStreak <= 0) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
          child: Container(
            margin: const EdgeInsets.only(right: Spacing.xs),
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Spacing.radiusMd),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _AnimatedFlameIcon(),
                const SizedBox(width: Spacing.xs),
                Text(
                  '${streak.currentStreak}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _AnimatedFlameIcon extends StatefulWidget {
  const _AnimatedFlameIcon();

  @override
  State<_AnimatedFlameIcon> createState() => _AnimatedFlameIconState();
}

class _AnimatedFlameIconState extends State<_AnimatedFlameIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    final curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _scale = Tween<double>(begin: 0.92, end: 1.10).animate(curve);
    _glow = Tween<double>(begin: 0.15, end: 0.55).animate(curve);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scale.value,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color.lerp(
                    Colors.transparent,
                    AppColors.warning,
                    _glow.value,
                  )!,
                  blurRadius: 8,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
      child: const Icon(
        Icons.local_fire_department_rounded,
        size: 16,
        color: AppColors.warning,
      ),
    );
  }
}

class _DeckList extends ConsumerWidget {
  final List<DeckWithCounts> decks;

  const _DeckList({required this.decks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (decks.isEmpty) {
      return EmptyDeckState(
        onCreateDeck: () async {
          await context.push(Routes.deckNew);
          ref.invalidate(deckListProvider);
        },
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: Spacing.sm, bottom: Spacing.sm + 80),
      itemCount: decks.length,
      itemBuilder: (context, index) {
        final item = decks[index];
        return ContextMenuRegion(
          onAction: (action) =>
              _handleContextAction(context, ref, item.deck, action),
          child: DeckCard(
            deck: item.deck,
            cardCount: item.cardCount,
            dueCount: item.dueCount,
            onTap: () async {
              await context.push(
                Routes.deckPath(item.deck.deckId),
                extra: item.deck,
              );
              ref.invalidate(deckListProvider);
            },
          ),
        );
      },
    );
  }

  Future<void> _handleContextAction(
    BuildContext context,
    WidgetRef ref,
    Deck deck,
    ContextMenuAction action,
  ) async {
    try {
      switch (action) {
        case ContextMenuAction.edit:
          await context.push(Routes.deckEditPath(deck.deckId), extra: deck);
          ref.invalidate(deckListProvider);
          break;
        case ContextMenuAction.delete:
          final confirmed = await ConfirmDialog.show(
            context: context,
            title: 'Delete deck?',
            message: 'This will delete "${deck.deckName}" and all its cards.',
            confirmLabel: 'Delete',
            isDestructive: true,
          );
          if (!confirmed || !context.mounted) return;
          await ref.read(deckListProvider.notifier).deleteDeck(deck.deckId);
          break;
        case ContextMenuAction.move:
          final deckRepo = ref.read(deckRepositoryProvider);
          final allDecks = await deckRepo.getAll();
          final excludeIds = (await deckRepo.getDescendantIds(
            deck.deckId,
          )).toSet();

          if (!context.mounted) return;
          final targetId = await DeckPickerDialog.show(
            context: context,
            decks: allDecks,
            excludeIds: excludeIds,
            currentParentId: deck.parentId,
          );
          if (targetId == null || !context.mounted) return;

          final newParentId = targetId.isEmpty ? null : targetId;
          if (newParentId == deck.parentId) return;

          final nameConflict = await deckRepo.nameExistsAtLevel(
            name: deck.deckName,
            parentId: newParentId,
            excludeDeckId: deck.deckId,
          );
          if (nameConflict) {
            if (!context.mounted) return;
            AppSnackBar.show(
              context,
              'A deck named "${deck.deckName}" already exists there',
            );
            return;
          }

          final deckToMove = deck.copyWith(
            parentId: Optional.value(newParentId),
          );
          await deckRepo.update(deckToMove);
          ref.invalidate(deckListProvider);
          ref.read(syncServiceProvider.notifier).schedulePush();
          if (!context.mounted) return;
          AppSnackBar.show(context, 'Moved "${deck.deckName}"');
          break;
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(context, 'Action failed: $e');
      }
    }
  }
}
