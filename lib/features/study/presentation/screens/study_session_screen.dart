import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/rating.dart';

class StudySessionScreen extends StatefulWidget {
  final String deckName;
  final List<String> deckIds;

  const StudySessionScreen({super.key, required this.deckName, required this.deckIds});

  @override
  State<StudySessionScreen> createState() => _StudySessionScreenState();
}

class _StudySessionScreenState extends State<StudySessionScreen> {
  // TODO: Replace with state management provider
  final _cardRepo = CardRepository();

  List<Flashcard> _cards = [];
  bool _isLoading = true;

  int _currentIndex = 0;
  bool _showingAnswer = false;
  final Map<Rating, int> _ratingCounts = {Rating.again: 0, Rating.hard: 0, Rating.good: 0, Rating.easy: 0};

  Flashcard get _currentCard => _cards[_currentIndex];
  bool get _isSessionComplete => _cards.isEmpty || _currentIndex >= _cards.length;
  double get _progress => _cards.isEmpty ? 0 : (_currentIndex / _cards.length);

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  Future<void> _loadCards() async {
    try {
      final allCards = <Flashcard>[];
      for (final deckId in widget.deckIds) {
        // TODO: Replace with state management provider
        final due = await _cardRepo.getDueCards(deckId);
        allCards.addAll(due);
      }
      if (mounted) {
        setState(() {
          _cards = allCards;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load cards: $e')),
        );
      }
    }
  }

  void _flipCard() {
    setState(() {
      _showingAnswer = true;
    });
  }

  void _rateCard(Rating rating) {
    setState(() {
      _ratingCounts[rating] = _ratingCounts[rating]! + 1;
      _currentIndex++;
      _showingAnswer = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => _showExitConfirmation(context)),
        title: Text(widget.deckName),
        centerTitle: true,
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                _buildProgressBar(),
                Expanded(child: _isSessionComplete ? _buildSessionComplete() : _buildStudyCard()),
              ],
            ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: Spacing.xs,
      width: double.infinity,
      color: AppColors.surfaceElevated,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _progress,
        child: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: [AppColors.primary, AppColors.secondary])),
        ),
      ),
    );
  }

  void _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    if (!_showingAnswer) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _flipCard();
      }
    } else {
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        _rateCard(Rating.again);
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        _rateCard(Rating.hard);
      } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
        _rateCard(Rating.good);
      } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
        _rateCard(Rating.easy);
      }
    }
  }

  Widget _buildStudyCard() {
    return KeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      autofocus: true,
      onKeyEvent: _handleKeyPress,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          children: [
            Expanded(
              child: MouseRegion(
                cursor: _showingAnswer ? SystemMouseCursors.basic : SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: _showingAnswer ? null : _flipCard,
                  child: Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(Spacing.xl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _showingAnswer ? _currentCard.back : _currentCard.front,
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: Spacing.xl),
                          Text(
                            _showingAnswer ? '' : 'Tap or press Space to reveal',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: Spacing.lg),
            _buildRatingButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButtons() {
    return Opacity(
      opacity: _showingAnswer ? 1.0 : 0.3,
      child: IgnorePointer(
        ignoring: !_showingAnswer,
        child: Row(
          children: [
            _RatingButton(label: 'Again', color: AppColors.ratingAgain, onPressed: () => _rateCard(Rating.again)),
            const SizedBox(width: Spacing.sm),
            _RatingButton(label: 'Hard', color: AppColors.ratingHard, onPressed: () => _rateCard(Rating.hard)),
            const SizedBox(width: Spacing.sm),
            _RatingButton(label: 'Good', color: AppColors.ratingGood, onPressed: () => _rateCard(Rating.good)),
            const SizedBox(width: Spacing.sm),
            _RatingButton(label: 'Easy', color: AppColors.ratingEasy, onPressed: () => _rateCard(Rating.easy)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionComplete() {
    final totalReviewed = _ratingCounts.values.reduce((a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.all(Spacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration_outlined, size: 64, color: AppColors.primary),
          const SizedBox(height: Spacing.lg),
          Text('Session Complete!', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: Spacing.sm),
          Text(
            'You reviewed $totalReviewed cards',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Spacing.xxl),
          _buildStatsGrid(),
          const SizedBox(height: Spacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(onPressed: () => context.go('/'), child: const Text('Done')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(label: 'Again', count: _ratingCounts[Rating.again]!, color: AppColors.ratingAgain),
        _StatItem(label: 'Hard', count: _ratingCounts[Rating.hard]!, color: AppColors.ratingHard),
        _StatItem(label: 'Good', count: _ratingCounts[Rating.good]!, color: AppColors.ratingGood),
        _StatItem(label: 'Easy', count: _ratingCounts[Rating.easy]!, color: AppColors.ratingEasy),
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
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('End')),
        ],
      ),
    );
    if (shouldExit == true && context.mounted) {
      context.go('/');
    }
  }
}

class _RatingButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _RatingButton({required this.label, required this.color, required this.onPressed});

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

  const _StatItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          '$count',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: Spacing.xs),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
      ],
    );
  }
}
