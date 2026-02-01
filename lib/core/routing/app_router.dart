import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/debug_widget_screen.dart';
import 'routes.dart';

final appRouter = GoRouter(
  initialLocation: Routes.home,
  routes: [
    GoRoute(
      path: Routes.home,
      builder: (context, state) => const _PlaceholderScreen(title: 'Decks'),
    ),
    GoRoute(
      path: Routes.debug,
      builder: (context, state) => const DebugWidgetScreen(),
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
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      drawer: const _DevNavigationDrawer(),
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

class _DevNavigationDrawer extends StatelessWidget {
  const _DevNavigationDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Dev Navigation',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  'Navigate between screens',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          _NavItem(
            icon: Icons.bug_report,
            label: 'Widget Preview',
            route: Routes.debug,
          ),
          const Divider(),
          _NavItem(
            icon: Icons.home,
            label: 'Home (Deck List)',
            route: Routes.home,
          ),
          _NavItem(
            icon: Icons.add,
            label: 'New Deck',
            route: Routes.deckNew,
          ),
          _NavItem(
            icon: Icons.folder,
            label: 'Deck Detail (mock)',
            route: Routes.deckPath('demo'),
          ),
          _NavItem(
            icon: Icons.edit,
            label: 'Edit Deck (mock)',
            route: Routes.deckEditPath('demo'),
          ),
          const Divider(),
          _NavItem(
            icon: Icons.note_add,
            label: 'New Card (mock)',
            route: Routes.cardNewPath('demo'),
          ),
          _NavItem(
            icon: Icons.credit_card,
            label: 'Edit Card (mock)',
            route: Routes.cardPath('demo', 'card1'),
          ),
          const Divider(),
          _NavItem(
            icon: Icons.play_arrow,
            label: 'Study Session (mock)',
            route: Routes.studyPath('demo'),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final currentRoute = GoRouterState.of(context).uri.toString();
    final isActive = currentRoute == route;

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: isActive,
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}
