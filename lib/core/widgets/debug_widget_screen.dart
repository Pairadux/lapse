import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../routing/routes.dart';
import '../theme/app_colors.dart';
import 'empty_state_widget.dart';
import 'loading_indicator.dart';
import 'confirm_dialog.dart';

class DebugWidgetScreen extends StatelessWidget {
  const DebugWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Preview')),
      drawer: const _DevDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            context,
            'Empty State Widget',
            [
              _WidgetPreview(
                label: 'With action button',
                height: 300,
                child: EmptyStateWidget(
                  icon: Icons.folder_outlined,
                  title: 'No decks yet',
                  subtitle: 'Create your first deck to start studying',
                  actionLabel: 'Create Deck',
                  onAction: () {},
                ),
              ),
              _WidgetPreview(
                label: 'Without action',
                height: 220,
                child: const EmptyStateWidget(
                  icon: Icons.search_off,
                  title: 'No results found',
                  subtitle: 'Try a different search term',
                ),
              ),
              _WidgetPreview(
                label: 'Minimal',
                height: 200,
                child: const EmptyStateWidget(
                  icon: Icons.inbox_outlined,
                  title: 'All caught up!',
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            'Loading Indicator',
            [
              _WidgetPreview(
                label: 'Default (32px)',
                height: 80,
                child: const LoadingIndicator(),
              ),
              _WidgetPreview(
                label: 'Small (20px)',
                height: 60,
                child: const LoadingIndicator(size: 20),
              ),
              _WidgetPreview(
                label: 'Large (48px)',
                height: 100,
                child: const LoadingIndicator(size: 48),
              ),
              _WidgetPreview(
                label: 'Custom color',
                height: 80,
                child: const LoadingIndicator(color: AppColors.secondary),
              ),
            ],
          ),
          _buildSection(
            context,
            'Confirm Dialog',
            [
              _WidgetPreview(
                label: 'Tap to preview',
                height: 100,
                child: Center(
                  child: Wrap(
                    spacing: 12,
                    children: [
                      ElevatedButton(
                        onPressed: () => _showConfirmDialog(context, false),
                        child: const Text('Normal'),
                      ),
                      ElevatedButton(
                        onPressed: () => _showConfirmDialog(context, true),
                        child: const Text('Destructive'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            'Theme Colors',
            [
              _WidgetPreview(
                label: 'Primary palette',
                height: 60,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ColorDot(AppColors.primaryDark, 'Dark'),
                    _ColorDot(AppColors.primary, 'Primary'),
                    _ColorDot(AppColors.primaryLight, 'Light'),
                  ],
                ),
              ),
              _WidgetPreview(
                label: 'Secondary palette',
                height: 60,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ColorDot(AppColors.secondaryDark, 'Dark'),
                    _ColorDot(AppColors.secondary, 'Secondary'),
                    _ColorDot(AppColors.secondaryLight, 'Light'),
                  ],
                ),
              ),
              _WidgetPreview(
                label: 'Rating colors',
                height: 60,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ColorDot(AppColors.ratingAgain, 'Again'),
                    _ColorDot(AppColors.ratingHard, 'Hard'),
                    _ColorDot(AppColors.ratingGood, 'Good'),
                    _ColorDot(AppColors.ratingEasy, 'Easy'),
                  ],
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            'Buttons',
            [
              _WidgetPreview(
                label: 'Button styles',
                height: 120,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () {},
                      child: const Text('Elevated'),
                    ),
                    OutlinedButton(
                      onPressed: () {},
                      child: const Text('Outlined'),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('Text'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            'Text Inputs',
            [
              _WidgetPreview(
                label: 'TextField states',
                height: 180,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'Default state',
                        ),
                      ),
                      SizedBox(height: 12),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'With label',
                          labelText: 'Deck name',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ...children,
      ],
    );
  }

  Future<void> _showConfirmDialog(BuildContext context, bool destructive) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: destructive ? 'Delete deck?' : 'Save changes?',
      message: destructive
          ? 'This action cannot be undone. All cards in this deck will be permanently deleted.'
          : 'Do you want to save your changes before leaving?',
      confirmLabel: destructive ? 'Delete' : 'Save',
      cancelLabel: 'Cancel',
      isDestructive: destructive,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(confirmed ? 'Confirmed' : 'Cancelled')),
      );
    }
  }
}

class _WidgetPreview extends StatelessWidget {
  final String label;
  final double height;
  final Widget child;

  const _WidgetPreview({
    required this.label,
    required this.height,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          SizedBox(
            height: height,
            width: double.infinity,
            child: child,
          ),
        ],
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ColorDot(this.color, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _DevDrawer extends StatelessWidget {
  const _DevDrawer();

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
