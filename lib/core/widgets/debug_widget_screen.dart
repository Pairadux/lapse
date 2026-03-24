import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';
import 'app_scaffold.dart';
import 'empty_state_widget.dart';
import 'loading_indicator.dart';
import 'confirm_dialog.dart';

class DebugWidgetScreen extends StatelessWidget {
  const DebugWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Widget Preview',
      showBackButton: true,
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          _buildSection(context, 'Empty State Widget', [
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
          ]),
          _buildSection(context, 'Loading Indicator', [
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
          ]),
          _buildSection(context, 'Confirm Dialog', [
            _WidgetPreview(
              label: 'Tap to preview',
              height: 100,
              child: Center(
                child: Wrap(
                  spacing: Spacing.md,
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
          ]),
          _buildSection(context, 'Theme Colors', [
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
          ]),
          _buildSection(context, 'Buttons', [
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
                  TextButton(onPressed: () {}, child: const Text('Text')),
                ],
              ),
            ),
          ]),
          _buildSection(context, 'Text Inputs', [
            _WidgetPreview(
              label: 'TextField states',
              height: 180,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(hintText: 'Default state'),
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
          ]),
          _buildSection(context, 'Study Gradient', [
            _WidgetPreview(
              label: 'Linear gradient (violet BL → pink TR)',
              height: 400,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                    colors: [Color(0xBF8B5CF6), Color(0xBFF472B6)],
                  ),
                ),
              ),
            ),
          ]),
          const SizedBox(height: Spacing.xxl),
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
          padding: const EdgeInsets.symmetric(vertical: Spacing.lg),
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ...children,
      ],
    );
  }

  Future<void> _showConfirmDialog(
    BuildContext context,
    bool destructive,
  ) async {
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
      margin: const EdgeInsets.only(bottom: Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Spacing.md,
              Spacing.md,
              Spacing.md,
              Spacing.sm,
            ),
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          SizedBox(height: height, width: double.infinity, child: child),
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
          width: Spacing.xxl,
          height: Spacing.xxl,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: Spacing.xs),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}
