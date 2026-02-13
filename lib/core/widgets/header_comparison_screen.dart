import 'package:flutter/material.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/app_scaffold.dart';

/// Temporary screen for comparing 3 header layout options for DeckDetailScreen.
/// Remove after design decision is made.
class HeaderComparisonScreen extends StatelessWidget {
  const HeaderComparisonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Header Comparison',
      showBackButton: true,
      showSettingsButton: false,
      body: ListView(
        padding: const EdgeInsets.all(Spacing.lg),
        children: [
          _buildSectionLabel(context, 'Option A — Stats Row + TabBar'),
          const SizedBox(height: Spacing.sm),
          _OptionAHeader(),
          const SizedBox(height: Spacing.sm),
          _buildDescription(context,
              'Breadcrumb on top, compact stats row with tonal Study button, '
              'slim underline TabBar. Leaf decks skip the TabBar.'),
          const SizedBox(height: Spacing.xxl),
          _buildSectionLabel(context, 'Option B — All-in-One Card'),
          const SizedBox(height: Spacing.sm),
          _OptionBHeader(),
          const SizedBox(height: Spacing.sm),
          _buildDescription(context,
              'Single styled card containing stats, study action, and tab '
              'switcher. More visually grouped but slightly heavier.'),
          const SizedBox(height: Spacing.xxl),
          _buildSectionLabel(context, 'Option C — Minimal Inline'),
          const SizedBox(height: Spacing.sm),
          _OptionCHeader(),
          const SizedBox(height: Spacing.sm),
          _buildDescription(context,
              'Stats inline with breadcrumb (right-aligned). Study button '
              'next to the TabBar. Most compact, least visual weight.'),
          const SizedBox(height: Spacing.xxl),
          const Divider(),
          const SizedBox(height: Spacing.lg),
          _buildSectionLabel(context, 'Leaf Deck Variants (no sub-decks)'),
          const SizedBox(height: Spacing.lg),
          _buildSectionLabel(context, 'Option A — Leaf'),
          const SizedBox(height: Spacing.sm),
          _OptionALeafHeader(),
          const SizedBox(height: Spacing.xxl),
          _buildSectionLabel(context, 'Option B — Leaf'),
          const SizedBox(height: Spacing.sm),
          _OptionBLeafHeader(),
          const SizedBox(height: Spacing.xxl),
          _buildSectionLabel(context, 'Option C — Leaf'),
          const SizedBox(height: Spacing.sm),
          _OptionCLeafHeader(),
          const SizedBox(height: Spacing.xxxl),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }

  Widget _buildDescription(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textTertiary,
          ),
    );
  }
}

// ─── Shared breadcrumb ────────────────────────────────────────────────────

Widget _buildBreadcrumb(BuildContext context) {
  return Row(
    children: [
      Text('Home',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.primary)),
      _chevron(context),
      Text('Languages',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.primary)),
      _chevron(context),
      Text('Spanish',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(fontWeight: FontWeight.w600)),
    ],
  );
}

Widget _chevron(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
    child: Icon(Icons.chevron_right, size: Spacing.lg, color: AppColors.textTertiary),
  );
}

// ─── Option A: Stats Row + TabBar ─────────────────────────────────────────

class _OptionAHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          // Breadcrumb
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Spacing.radiusMd),
                topRight: Radius.circular(Spacing.radiusMd),
              ),
            ),
            child: _buildBreadcrumb(context),
          ),
          // Stats + Study
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.sm),
            child: Row(
              children: [
                Text(
                  '12 cards',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Text('·',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary)),
                ),
                Text(
                  '5 due',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Study'),
                ),
              ],
            ),
          ),
          // TabBar
          DefaultTabController(
            length: 2,
            child: TabBar(
              tabs: const [
                Tab(text: 'Sub-decks (3)'),
                Tab(text: 'Cards (12)'),
              ],
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              dividerColor: AppColors.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionALeafHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Spacing.radiusMd),
                topRight: Radius.circular(Spacing.radiusMd),
              ),
            ),
            child: _buildBreadcrumb(context),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.sm),
            child: Row(
              children: [
                Text('12 cards',
                    style: Theme.of(context).textTheme.bodySmall),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
                  child: Text('·',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textTertiary)),
                ),
                Text('5 due',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        )),
                const Spacer(),
                FilledButton.tonalIcon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Study'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Option B: All-in-One Card ────────────────────────────────────────────

class _OptionBHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Breadcrumb (outside card)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          color: AppColors.surfaceElevated,
          child: _buildBreadcrumb(context),
        ),
        // Card
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Spacing.radiusLg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                // Stats row
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Spacing.lg, Spacing.md, Spacing.lg, Spacing.sm),
                  child: Row(
                    children: [
                      _StatChip(
                          icon: Icons.style_outlined,
                          label: '12 cards',
                          context: context),
                      const SizedBox(width: Spacing.lg),
                      _StatChip(
                          icon: Icons.schedule,
                          label: '5 due',
                          color: AppColors.primary,
                          context: context),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.play_arrow, size: 18),
                        label: const Text('Study'),
                      ),
                    ],
                  ),
                ),
                // Tab bar inside card
                DefaultTabController(
                  length: 2,
                  child: TabBar(
                    tabs: const [
                      Tab(text: 'Sub-decks (3)'),
                      Tab(text: 'Cards (12)'),
                    ],
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.primary,
                    unselectedLabelColor: AppColors.textSecondary,
                    dividerColor: AppColors.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionBLeafHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          color: AppColors.surfaceElevated,
          child: _buildBreadcrumb(context),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: Spacing.lg, vertical: Spacing.sm),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(Spacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(Spacing.radiusLg),
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                _StatChip(
                    icon: Icons.style_outlined,
                    label: '12 cards',
                    context: context),
                const SizedBox(width: Spacing.lg),
                _StatChip(
                    icon: Icons.schedule,
                    label: '5 due',
                    color: AppColors.primary,
                    context: context),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow, size: 18),
                  label: const Text('Study'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final BuildContext context;

  const _StatChip({
    required this.icon,
    required this.label,
    this.color,
    required this.context,
  });

  @override
  Widget build(BuildContext _) {
    final c = color ?? AppColors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: Spacing.xs),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: c, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ─── Option C: Minimal Inline ─────────────────────────────────────────────

class _OptionCHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        children: [
          // Breadcrumb + stats on same row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: Spacing.lg, vertical: Spacing.sm),
            decoration: const BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(Spacing.radiusMd),
                topRight: Radius.circular(Spacing.radiusMd),
              ),
            ),
            child: Row(
              children: [
                Expanded(child: _buildBreadcrumb(context)),
                Text(
                  '12 cards · 5 due',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ],
            ),
          ),
          // TabBar + Study on same row
          Padding(
            padding: const EdgeInsets.only(left: Spacing.sm, right: Spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: DefaultTabController(
                    length: 2,
                    child: TabBar(
                      tabs: const [
                        Tab(text: 'Sub-decks'),
                        Tab(text: 'Cards'),
                      ],
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      dividerColor: Colors.transparent,
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  onPressed: () {},
                  icon: const Icon(Icons.play_arrow, size: 20),
                  tooltip: 'Study',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptionCLeafHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
        border: Border.all(color: AppColors.outline),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: Spacing.lg, vertical: Spacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(Spacing.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(child: _buildBreadcrumb(context)),
            Text(
              '12 cards · 5 due',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textTertiary,
                  ),
            ),
            const SizedBox(width: Spacing.sm),
            IconButton.filledTonal(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow, size: 20),
              tooltip: 'Study',
            ),
          ],
        ),
      ),
    );
  }
}
