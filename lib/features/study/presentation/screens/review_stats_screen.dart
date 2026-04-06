import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/widgets/app_snack_bar.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';
import 'package:lapse/features/study/data/review_session_summary_repository_provider.dart';
import 'package:lapse/features/study/domain/review_streak.dart';

class ReviewStatsScreen extends ConsumerStatefulWidget {
  const ReviewStatsScreen({super.key});

  @override
  ConsumerState<ReviewStatsScreen> createState() => _ReviewStatsScreenState();
}

class _ReviewStatsScreenState extends ConsumerState<ReviewStatsScreen> {
  CardRepository get _cardRepo => ref.read(cardRepositoryProvider);
  ReviewSessionSummaryRepository get _summaryRepo =>
      ref.read(reviewSessionSummaryRepositoryProvider);

  Map<int, int> _dueCounts = {}; // dayOffset → count
  bool _isLoading = true;
  int _maxDay = 7;
  ReviewStreak _streak = const ReviewStreak.empty();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final (raw, streak) = await (
        _cardRepo.getDueDateCounts(),
        _summaryRepo.getStreak(),
      ).wait;
      final today = DateUtils.dateOnly(DateTime.now());

      // Convert calendar dates to day offsets from today.
      // Overdue cards (negative offset) bucket into day 0.
      final byOffset = <int, int>{};
      for (final entry in raw.entries) {
        final offset = DateUtils.dateOnly(entry.key).difference(today).inDays;
        final bucket = offset < 0 ? 0 : offset;
        byOffset[bucket] = (byOffset[bucket] ?? 0) + entry.value;
      }

      // Scale: minimum 7 days, otherwise ~20% past the farthest value
      final farthest = byOffset.keys.fold(0, max);
      final maxDay = max(7, (farthest * 1.2).ceil());

      if (mounted) {
        setState(() {
          _dueCounts = byOffset;
          _maxDay = maxDay;
          _streak = streak;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.show(context, 'Failed to load stats: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('Review Stats'),
      ),
      body: _isLoading ? const LoadingIndicator() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStreakRow(),
          const SizedBox(height: Spacing.lg),
          Text(
            'Due Date Forecast',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Cards due per day from today',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: Spacing.lg),
          Expanded(
            child: _dueCounts.isEmpty
                ? const Center(
                    child: Text(
                      'No cards yet — study some cards first.',
                      style: TextStyle(color: AppColors.textTertiary),
                    ),
                  )
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStreakCard(
            label: 'Current Streak',
            value: '${_streak.currentStreak}',
            caption: _streak.currentStreak == 1 ? 'day' : 'days',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _buildStreakCard(
            label: 'Longest Streak',
            value: '${_streak.longestStreak}',
            caption: _streak.longestStreak == 1 ? 'day' : 'days',
            color: AppColors.secondary,
          ),
        ),
        const SizedBox(width: Spacing.md),
        Expanded(
          child: _buildStreakCard(
            label: 'Last Completed',
            value: _streak.lastCompletedDate ?? '—',
            caption: 'date',
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStreakCard({
    required String label,
    required String value,
    required String caption,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(Spacing.radiusMd),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final maxY = _dueCounts.values.fold(0, max).toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY + (maxY * 0.15).ceilToDouble().clamp(1, double.infinity),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surfaceElevated,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final day = group.x;
              final count = rod.toY.toInt();
              final label = day == 0 ? 'Today' : 'Day $day';
              return BarTooltipItem(
                '$label\n$count card${count == 1 ? '' : 's'}',
                const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final day = value.toInt();
                // Show label for day 0, then every few days to avoid crowding
                final interval = (_maxDay / 7).ceil().clamp(1, 999);
                if (day != 0 && day % interval != 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Text(
                    day == 0 ? 'Today' : 'd$day',
                    style: const TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    color: AppColors.textTertiary,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: AppColors.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: _buildBarGroups(),
      ),
    );
  }

  List<BarChartGroupData> _buildBarGroups() {
    return List.generate(_maxDay + 1, (day) {
      final count = _dueCounts[day] ?? 0;
      final isOverdue = day == 0 && _dueCounts.containsKey(0);

      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: count.toDouble(),
            color: isOverdue ? AppColors.ratingAgain : AppColors.primary,
            width: _maxDay > 30 ? 4 : 8,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
          ),
        ],
      );
    });
  }
}
