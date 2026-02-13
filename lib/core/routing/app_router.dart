import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/presentation/screens/card_form_screen.dart';
import 'package:lapse/features/decks/domain/deck.dart';
import 'package:lapse/features/decks/presentation/screens/deck_detail_screen.dart';
import 'package:lapse/features/decks/presentation/screens/deck_form_screen.dart';
import 'package:lapse/features/decks/presentation/screens/deck_list_screen.dart';
import 'package:lapse/features/study/presentation/screens/study_session_screen.dart';
import '../widgets/app_scaffold.dart';
import '../widgets/debug_widget_screen.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const DeckListScreen(),
    ),
    GoRoute(
      path: Routes.debug,
      builder: (context, state) => const DebugWidgetScreen(),
    ),
    GoRoute(
      path: Routes.settings,
      builder: (context, state) => const _SettingsPlaceholder(),
    ),
    GoRoute(
      path: Routes.deckNew,
      builder: (context, state) =>
          DeckFormScreen(parentId: state.extra as String?),
    ),
    GoRoute(
      path: Routes.deck,
      builder: (context, state) {
        final deckId = state.pathParameters['deckId']!;
        return DeckDetailScreen(
          deckId: deckId,
          deck: state.extra as Deck?,
        );
      },
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) =>
              DeckFormScreen(deck: state.extra as Deck?),
        ),
        GoRoute(
          path: 'card/new',
          builder: (context, state) => CardFormScreen(
            deckId: state.pathParameters['deckId']!,
          ),
        ),
        GoRoute(
          path: 'card/:cardId',
          builder: (context, state) => CardFormScreen(
            deckId: state.pathParameters['deckId']!,
            card: state.extra as Flashcard?,
          ),
        ),
        GoRoute(
          path: 'study',
          builder: (context, state) {
            final deckId = state.pathParameters['deckId']!;
            final extra = state.extra as Map<String, dynamic>?;
            final deckName = extra?['name'] as String? ?? 'Study';
            final deckIds = extra?['deckIds'] as List<String>? ?? [deckId];
            return StudySessionScreen(deckName: deckName, deckIds: deckIds);
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
