import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/presentation/screens/card_form_screen.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/screens/deck_detail_screen.dart';
import 'package:lapse/features/decks/presentation/screens/deck_form_screen.dart';
import 'package:lapse/features/decks/presentation/screens/deck_list_screen.dart';
import 'package:lapse/features/study/presentation/screens/study_session_screen.dart';
import 'package:lapse/features/study/presentation/screens/review_stats_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/debug_widget_screen.dart';
import 'page_transitions.dart';
import 'route_observer.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.home,
  observers: [routeObserver],
  routes: [
    GoRoute(
      path: Routes.home,
      pageBuilder: (context, state) =>
          buildPage(state, const DeckListScreen()),
    ),
    GoRoute(
      path: Routes.debug,
      pageBuilder: (context, state) =>
          buildPage(state, const DebugWidgetScreen()),
    ),
    GoRoute(
      path: Routes.devStats,
      pageBuilder: (context, state) =>
          buildPage(state, const ReviewStatsScreen()),
    ),
    GoRoute(
      path: Routes.settings,
      pageBuilder: (context, state) =>
          buildPage(state, const _SettingsPlaceholder()),
    ),
    GoRoute(
      path: Routes.deckNew,
      pageBuilder: (context, state) =>
          buildPage(state, DeckFormScreen(parentId: state.extra as String?)),
    ),
    GoRoute(
      path: Routes.deck,
      pageBuilder: (context, state) {
        final deckId = state.pathParameters['deckId']!;
        final extra = state.extra;
        // Extra can be a Deck (simple push) or a Map with deck + ancestors.
        final deck = extra is Deck
            ? extra
            : (extra is Map<String, dynamic>
                ? extra['deck'] as Deck?
                : null);
        final ancestors = extra is Map<String, dynamic>
            ? extra['ancestors'] as List<Deck>?
            : null;
        return buildPage(
          state,
          DeckDetailScreen(
            deckId: deckId,
            deck: deck,
            initialAncestors: ancestors,
          ),
        );
      },
      routes: [
        GoRoute(
          path: 'edit',
          pageBuilder: (context, state) =>
              buildPage(state, DeckFormScreen(deck: state.extra as Deck?)),
        ),
        GoRoute(
          path: 'card/new',
          pageBuilder: (context, state) => buildPage(
            state,
            CardFormScreen(deckId: state.pathParameters['deckId']!),
          ),
        ),
        GoRoute(
          path: 'card/:cardId',
          pageBuilder: (context, state) => buildPage(
            state,
            CardFormScreen(
              deckId: state.pathParameters['deckId']!,
              card: state.extra as Flashcard?,
            ),
          ),
        ),
        GoRoute(
          path: 'study',
          pageBuilder: (context, state) {
            final deckId = state.pathParameters['deckId']!;
            final extra = state.extra as Map<String, dynamic>?;
            final deckName = extra?['name'] as String? ?? 'Study';
            final deckIds = extra?['deckIds'] as List<String>? ?? [deckId];
            return buildPage(
              state,
              StudySessionScreen(deckName: deckName, deckIds: deckIds),
            );
          },
        ),
      ],
    ),
  ],
);

class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Settings',
      showBackButton: true,
      showSettingsButton: false,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text('Screen not implemented yet'),
          ],
        ),
      ),
    );
  }
}
