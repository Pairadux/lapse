import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/features/decks/presentation/screens/deck_list_screen.dart';
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
      builder: (context, state) => const _PlaceholderScreen(title: 'New Deck'),
    ),
    GoRoute(
      path: Routes.deck,
      builder: (context, state) {
        final deckId = state.pathParameters['deckId']!;
        return _PlaceholderScreen(title: 'Deck: $deckId');
      },
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) {
            final deckId = state.pathParameters['deckId']!;
            return _PlaceholderScreen(title: 'Edit Deck: $deckId');
          },
        ),
        GoRoute(
          path: 'card/new',
          builder: (context, state) => const _PlaceholderScreen(title: 'New Card'),
        ),
        GoRoute(
          path: 'card/:cardId',
          builder: (context, state) {
            final cardId = state.pathParameters['cardId']!;
            return _PlaceholderScreen(title: 'Edit Card: $cardId');
          },
        ),
        GoRoute(
          path: 'study',
          builder: (context, state) {
            final deckId = state.pathParameters['deckId']!;
            return _PlaceholderScreen(title: 'Study: $deckId');
          },
        ),
      ],
    ),
  ],
);

class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: title,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            const Text('Screen not implemented yet'),
            const SizedBox(height: 8),
            Text(
              'Swipe right or tap ☰ for navigation',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

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
