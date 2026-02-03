import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/routes.dart';

class DevDrawer extends StatelessWidget {
  const DevDrawer({super.key});

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
          _DrawerItem(
            icon: Icons.bug_report,
            label: 'Widget Preview',
            route: Routes.debug,
          ),
          const Divider(),
          _DrawerItem(
            icon: Icons.home,
            label: 'Home (Deck List)',
            route: Routes.home,
          ),
          _DrawerItem(
            icon: Icons.settings,
            label: 'Settings',
            route: Routes.settings,
          ),
          _DrawerItem(
            icon: Icons.add,
            label: 'New Deck',
            route: Routes.deckNew,
          ),
          _DrawerItem(
            icon: Icons.folder,
            label: 'Deck Detail (mock)',
            route: Routes.deckPath('demo'),
          ),
          _DrawerItem(
            icon: Icons.edit,
            label: 'Edit Deck (mock)',
            route: Routes.deckEditPath('demo'),
          ),
          const Divider(),
          _DrawerItem(
            icon: Icons.note_add,
            label: 'New Card (mock)',
            route: Routes.cardNewPath('demo'),
          ),
          _DrawerItem(
            icon: Icons.credit_card,
            label: 'Edit Card (mock)',
            route: Routes.cardPath('demo', 'card1'),
          ),
          const Divider(),
          _DrawerItem(
            icon: Icons.play_arrow,
            label: 'Study Session (mock)',
            route: Routes.studyPath('demo'),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;

  const _DrawerItem({
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
