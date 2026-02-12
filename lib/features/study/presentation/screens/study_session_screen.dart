import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/presentation/Providers/study_session_provider.dart';

class StudySessionScreen extends ConsumerStatefulWidget {
  final String deckName;
  final List<String> deckIds;

  const StudySessionScreen({
    super.key,
    required this.deckName,
    required this.deckIds,
  });

  @override
  ConsumerState<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends ConsumerState<StudySessionScreen> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future<void>.microtask(() {
      ref.read(studySessionProvider.notifier).startSession(widget.deckIds);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(studySessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context),
        ),
        title: Text(widget.deckName),
        centerTitle: true,
      ),
      body: sessionState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _buildErrorState(),
        data: (session) => Column(
          children: [
            _buildProgressBar(session.progress),
            Expanded(
              child: session.isComplete
                  ? _buildSessionComplete(session)
                  : _buildStudyCard(session),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Failed to load study cards'),
            const SizedBox(height: Spacing.md),
            ElevatedButton(
              onPressed: () {
                ref.read(studySessionProvider.notifier).startSession(widget.deckIds);
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress) {
    return Container(
      height: Spacing.xs,
      width: double.infinity,
      color: AppColors.surfaceElevated,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
        ),
      ),
    );
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final session = ref.read(studySessionProvider).asData?.value;
    if (session == null || session.isComplete) return;

    final notifier = ref.read(studySessionProvider.notifier);
    if (!session.showingAnswer) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        notifier.revealAnswer();
      }
      return;
    }

    if (event.logicalKey == LogicalKeyboardKey.digit1) {
      notifier.rateCurrentCard(Rating.again);
    } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
      notifier.rateCurrentCard(Rating.hard);
    } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
      notifier.rateCurrentCard(Rating.good);
    } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
      notifier.rateCurrentCard(Rating.easy);
    }
  }

  Widget _buildStudyCard(StudySessionState session) {
    final card = session.currentCard!;
    return KeyboardListener(
      focusNode: _focusNode..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKeyPress,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: session.showingAnswer
                    ? null
                    : () => ref.read(studySessionProvider.notifier).revealAnswer(),
                child: Card(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(Spacing.xl),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          session.showingAnswer ? card.back : card.front,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: Spacing.xl),
                        Text(
                          session.showingAnswer ? '' : 'Tap or press Space to reveal',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            _buildRatingButtons(session.showingAnswer),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButtons(bool showingAnswer) {
    return Opacity(
      opacity: showingAnswer ? 1.0 : 0.3,
      child: IgnorePointer(
        ignoring: !showingAnswer,
        child: Row(
          children: [
            _RatingButton(
              label: 'Again',
              color: AppColors.ratingAgain,
              onPressed: () => ref
                  .read(studySessionProvider.notifier)
                  .rateCurrentCard(Rating.again),
            ),
            const SizedBox(width: Spacing.sm),
            _RatingButton(
              label: 'Hard',
              color: AppColors.ratingHard,
              onPressed: () => ref
                  .read(studySessionProvider.notifier)
                  .rateCurrentCard(Rating.hard),
            ),
            const SizedBox(width: Spacing.sm),
            _RatingButton(
              label: 'Good',
              color: AppColors.ratingGood,
              onPressed: () => ref
                  .read(studySessionProvider.notifier)
                  .rateCurrentCard(Rating.good),
            ),
            const SizedBox(width: Spacing.sm),
            _RatingButton(
              label: 'Easy',
              color: AppColors.ratingEasy,
              onPressed: () => ref
                  .read(studySessionProvider.notifier)
                  .rateCurrentCard(Rating.easy),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionComplete(StudySessionState session) {
    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.celebration_outlined,
            size: 64,
            color: AppColors.primary,
          ),
          const SizedBox(height: Spacing.lg),
          Text(
            'Session Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'You reviewed ${session.totalReviewed} cards',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: Spacing.xxl),
          _buildStatsGrid(session),
          const SizedBox(height: Spacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(studySessionProvider.notifier).endSession();
                context.go('/');
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(StudySessionState session) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          label: 'Again',
          count: session.ratingCounts[Rating.again] ?? 0,
          color: AppColors.ratingAgain,
        ),
        _StatItem(
          label: 'Hard',
          count: session.ratingCounts[Rating.hard] ?? 0,
          color: AppColors.ratingHard,
        ),
        _StatItem(
          label: 'Good',
          count: session.ratingCounts[Rating.good] ?? 0,
          color: AppColors.ratingGood,
        ),
        _StatItem(
          label: 'Easy',
          count: session.ratingCounts[Rating.easy] ?? 0,
          color: AppColors.ratingEasy,
        ),
      ],
    );
  }

  Future<void> _showExitConfirmation(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End session?'),
        content: const Text('Your progress in this session will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if (shouldExit == true && context.mounted) {
      ref.read(studySessionProvider.notifier).endSession();
      context.go('/');
    }
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _RatingButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 56,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
            padding: EdgeInsets.zero,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatItem({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }
}
