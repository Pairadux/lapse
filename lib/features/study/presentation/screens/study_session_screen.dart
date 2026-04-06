import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/routing/page_transitions.dart' show isDesktop;
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/widgets/app_snack_bar.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/core/widgets/loading_indicator.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/features/study/data/review_repository_provider.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';
import 'package:lapse/features/study/data/review_session_summary_repository_provider.dart';
import 'package:lapse/features/study/application/study_session_service.dart';
import 'package:lapse/features/study/domain/review_session_summary.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/study/domain/study_session.dart';
import 'package:lapse/features/study/presentation/providers/review_streak_provider.dart';
import 'package:lapse/features/study/presentation/widgets/card_stack.dart';
import 'package:lapse/features/study/presentation/widgets/flip_card.dart';
import 'package:lapse/features/study/presentation/widgets/swipeable_card.dart';
import 'package:lapse/features/decks/presentation/providers/deck_detail_provider.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';

/// Snapshot of FSRS-relevant card fields for debug comparison.
class _CardSnapshot {
  final double stability;
  final double difficulty;
  final DateTime dueDate;
  final CardState cardState;
  final int? step;
  final int reps;
  final int lapses;
  final int scheduledDays;
  final int elapsedDays;
  final DateTime? lastReview;

  _CardSnapshot.fromCard(Flashcard c)
    : stability = c.stability,
      difficulty = c.difficulty,
      dueDate = c.dueDate,
      cardState = c.cardState,
      step = c.step,
      reps = c.reps,
      lapses = c.lapses,
      scheduledDays = c.scheduledDays,
      elapsedDays = c.elapsedDays,
      lastReview = c.lastReview;
}

class _ReviewLogEntry {
  final String cardFront;
  final Rating rating;
  final _CardSnapshot before;
  final _CardSnapshot after;
  final DateTime timestamp;

  _ReviewLogEntry({
    required this.cardFront,
    required this.rating,
    required this.before,
    required this.after,
  }) : timestamp = DateTime.now();
}

/// Buffers one card's DB write so the most recent rating can be undone.
///
/// Instead of writing card updates and reviews to the DB immediately after
/// each rating, we hold the write here for one card. The pending write is
/// flushed to DB when the next card is rated or when the session ends.
/// If the user hits undo, the pending write is simply discarded — no DB
/// rollback needed.
class _PendingRating {
  final StudySessionResult result;
  final StudySession previousSession;
  final Rating rating;
  final bool graduated;

  const _PendingRating({
    required this.result,
    required this.previousSession,
    required this.rating,
    required this.graduated,
  });
}

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

class _StudySessionScreenState extends ConsumerState<StudySessionScreen>
    with SingleTickerProviderStateMixin {
  CardRepository get _cardRepo => ref.read(cardRepositoryProvider);
  ReviewRepository get _reviewRepo => ref.read(reviewRepositoryProvider);
  ReviewSessionSummaryRepository get _summaryRepo =>
      ref.read(reviewSessionSummaryRepositoryProvider);
  final _studySessionService = StudySessionService();
  late StudySession _session;
  late final SyncServiceNotifier _syncNotifier;

  // Fix: FocusNode leak, stores it as a state variable
  late final FocusNode _focusNode;

  // Desktop dismiss animation — slides card off-screen left on rate.
  late final AnimationController _dismissController;
  double _dismissOffset = 0;

  // Mobile swipe progress for shadow card animations (0.0–1.0).
  double _swipeProgress = 0;

  bool _isProcessing = false;

  /// Holds the most recent rating's DB write, deferred by one card for undo.
  /// Null when there is nothing to undo (start of session or after undo).
  _PendingRating? _pendingRating;

  List<Flashcard> _cards = [];
  bool _isLoading = true;
  int _initialCardCount = 0;

  int _currentIndex = 0;
  bool _showingAnswer = false;
  final Map<Rating, int> _ratingCounts = {
    Rating.again: 0,
    Rating.hard: 0,
    Rating.good: 0,
    Rating.easy: 0,
  };
  final Set<String> _graduatedCardIds = {};

  // Debug panel state
  bool _showDebugPanel = false;
  final List<_ReviewLogEntry> _reviewLog = [];
  bool _sessionSummarySaved = false;

  Flashcard get _currentCard => _cards[_currentIndex];
  bool get _isSessionComplete =>
      _cards.isEmpty || _currentIndex >= _cards.length;
  double get _progress => _initialCardCount == 0
      ? 0
      : (_graduatedCardIds.length / _initialCardCount).clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _syncNotifier = ref.read(syncServiceProvider.notifier);
    _focusNode = FocusNode();
    _dismissController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 200),
        )..addListener(() {
          final value = _dismissController.value;
          if (value != _dismissOffset) {
            setState(() => _dismissOffset = value);
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNotifier.pause();
    });
    _loadCards();
  }

  /// Invalidates deck providers so list/detail screens show updated counts.
  /// Must be called while ref is still valid (before pop), not in dispose.
  void _invalidateDeckProviders() {
    ref.invalidate(deckListProvider);
    for (final deckId in widget.deckIds) {
      ref.invalidate(deckDetailProvider(deckId));
    }
  }

  @override
  void dispose() {
    // Safety-net flush: persist any remaining buffered write.
    // Writes directly to repos without ref (which is unsafe in dispose).
    // The primary flush + invalidation happens in Done/exit handlers.
    final pending = _pendingRating;
    if (pending != null) {
      _pendingRating = null;
      _cardRepo.update(pending.result.updatedCard);
      _reviewRepo.addReview(pending.result.review);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncNotifier.resume();
    });
    _focusNode.dispose();
    _dismissController.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    try {
      // Perf: Parallelize card loading
      // Create a list of Futures instead of awaiting in a for loop
      final futures = widget.deckIds.map((id) => _cardRepo.getDueCards(id));

      // Waits on complete result
      final results = await Future.wait(futures);

      //Flattens List<List<Flashcard>> into List<Flashcard>
      final allCards = results.expand((cards) => cards).toList();

      if (mounted) {
        setState(() {
          _cards = allCards;
          _initialCardCount = allCards.length;
          _session = _studySessionService.startSession(
            widget.deckIds.first,
            _cards,
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppSnackBar.show(context, 'Failed to load cards: $e');
      }
    }
  }

  void _flipCard() {
    setState(() {
      _showingAnswer = true;
    });
  }

  /// Desktop only: animate card off-screen left, then perform the rating.
  Future<void> _dismissAndRate(Rating rating) async {
    if (_isProcessing) return;
    HapticFeedback.mediumImpact();
    _dismissController.reset();
    await _dismissController.forward();
    // _rateCard's setState atomically resets _dismissOffset and swaps to the
    // next card. No trailing reset() — the guarded listener would ignore it
    // anyway, and the next _dismissAndRate starts with reset().
    await _rateCard(rating);
  }

  /// Persists the buffered rating's card update and review to the database.
  /// Called before buffering the next rating, and on session exit.
  Future<void> _flushPendingWrite() async {
    final pending = _pendingRating;
    if (pending == null) return;
    _pendingRating = null;
    await _cardRepo.update(pending.result.updatedCard);
    await _reviewRepo.addReview(pending.result.review);
    ref.read(syncServiceProvider.notifier).schedulePush();
  }

  Future<void> _persistSessionSummaryIfNeeded() async {
    if (_sessionSummarySaved) return;

    final totalReviewed = _ratingCounts.values.fold(0, (sum, v) => sum + v);
    if (totalReviewed <= 0) return;

    var newCount = 0;
    var learningCount = 0;
    var reviewCount = 0;

    for (final entry in _reviewLog) {
      switch (entry.before.cardState) {
        case CardState.newCard:
          newCount++;
          break;
        case CardState.learning:
        case CardState.relearning:
          learningCount++;
          break;
        case CardState.review:
          reviewCount++;
          break;
      }
    }

    final summary = ReviewSessionSummary.fromSession(
      startedAt: _session.startedAt,
      endedAt: DateTime.now(),
      againCount: _ratingCounts[Rating.again] ?? 0,
      hardCount: _ratingCounts[Rating.hard] ?? 0,
      goodCount: _ratingCounts[Rating.good] ?? 0,
      easyCount: _ratingCounts[Rating.easy] ?? 0,
      newCount: newCount,
      learningCount: learningCount,
      reviewCount: reviewCount,
    );

    await _summaryRepo.add(summary);
    ref.invalidate(reviewStreakProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
    _sessionSummarySaved = true;
  }

  /// Undoes the most recent rating by discarding the pending DB write
  /// and restoring local state to before that rating.
  /// Only one level of undo — button is disabled when [_pendingRating] is null.
  void _undo() {
    final pending = _pendingRating;
    if (pending == null) return;
    HapticFeedback.lightImpact();
    setState(() {
      _pendingRating = null;
      _session = pending.previousSession;
      _cards = pending.previousSession.cards;
      _currentIndex--;
      _ratingCounts[pending.rating] = _ratingCounts[pending.rating]! - 1;
      if (pending.graduated) {
        _graduatedCardIds.remove(pending.result.updatedCard.cardId);
      }
      if (_reviewLog.isNotEmpty) _reviewLog.removeLast();
      _showingAnswer = false;
      _dismissOffset = 0;
      _swipeProgress = 0;
    });
  }

  Future<void> _rateCard(Rating rating) async {
    if (_isProcessing) return;
    _isProcessing = true;
    try {
      // Flush the previous card's pending write before buffering a new one.
      // This keeps DB writes at most one card behind, balancing crash safety
      // with the ability to undo the most recent rating.
      await _flushPendingWrite();

      final before = _CardSnapshot.fromCard(_currentCard);
      final result = _studySessionService.rateCard(
        _session,
        _currentCard,
        rating,
      );
      final after = _CardSnapshot.fromCard(result.updatedCard);
      final graduated = result.updatedCard.cardState == CardState.review;
      final previousSession = _session;

      setState(() {
        // Buffer this rating — written to DB on the next rating or session end.
        _pendingRating = _PendingRating(
          result: result,
          previousSession: previousSession,
          rating: rating,
          graduated: graduated,
        );
        // Reset dismiss offset atomically with card change so the old
        // card never reappears at center between animation and swap.
        _dismissOffset = 0;
        _swipeProgress = 0;
        _session = result.session;
        _cards = result.session.cards;
        _ratingCounts[rating] = _ratingCounts[rating]! + 1;
        if (graduated) {
          _graduatedCardIds.add(result.updatedCard.cardId);
        }
        _reviewLog.add(
          _ReviewLogEntry(
            cardFront: _currentCard.front,
            rating: rating,
            before: before,
            after: after,
          ),
        );
        _currentIndex++;
        _showingAnswer = false;
      });
    } catch (e) {
      if (mounted) {
        AppSnackBar.show(context, 'Failed to save review: $e');
      }
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context),
        ),
        title: Text(widget.deckName),
        centerTitle: true,
        actions: [
          // Undo: enabled when there is a buffered (not-yet-persisted) rating.
          // Disabled after use — only one level of undo is supported.
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'Undo last rating',
            onPressed: _pendingRating != null ? _undo : null,
          ),
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _showDebugPanel ? Icons.bug_report : Icons.bug_report_outlined,
              ),
              color: _showDebugPanel ? AppColors.warning : null,
              onPressed: () =>
                  setState(() => _showDebugPanel = !_showDebugPanel),
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingIndicator()
          : Column(
              children: [
                _buildProgressBar(),
                if (_showDebugPanel) _buildDebugPanel(),
                Expanded(
                  child: _isSessionComplete
                      ? _buildSessionComplete()
                      : _buildStudyCard(),
                ),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.secondary],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDebugPanel() {
    // Show upcoming card state if session is still active
    Widget? currentCardInfo;
    if (!_isSessionComplete) {
      final c = _currentCard;
      currentCardInfo = _buildDebugSection('Next Card', AppColors.primary, {
        'front': c.front.length > 40
            ? '${c.front.substring(0, 40)}...'
            : c.front,
        'state': c.cardState.name,
        'step': '${c.step ?? '-'}',
        'stability': c.stability.toStringAsFixed(4),
        'difficulty': c.difficulty.toStringAsFixed(4),
        'reps': '${c.reps}',
        'lapses': '${c.lapses}',
        'due': _formatDate(c.dueDate),
        'lastReview': c.lastReview != null
            ? _formatDate(c.lastReview!)
            : 'never',
      });
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A20),
        border: Border(
          bottom: BorderSide(color: AppColors.outline, width: 0.5),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        children: [
          ?currentCardInfo,
          if (_reviewLog.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: Spacing.sm,
                bottom: Spacing.xs,
              ),
              child: Text(
                'Review Log (${_reviewLog.length})',
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            // Show most recent first
            for (final entry in _reviewLog.reversed) _buildReviewEntry(entry),
          ],
          if (_reviewLog.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: Spacing.md),
              child: Text(
                'No reviews yet — rate a card to see FSRS changes.',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewEntry(_ReviewLogEntry entry) {
    final ratingColor = switch (entry.rating) {
      Rating.again => AppColors.ratingAgain,
      Rating.hard => AppColors.ratingHard,
      Rating.good => AppColors.ratingGood,
      Rating.easy => AppColors.ratingEasy,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ratingColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.rating.name.toUpperCase(),
                  style: TextStyle(
                    color: ratingColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  entry.cardFront.length > 30
                      ? '${entry.cardFront.substring(0, 30)}...'
                      : entry.cardFront,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.xs),
          _buildDiffTable(entry.before, entry.after),
        ],
      ),
    );
  }

  Widget _buildDiffTable(_CardSnapshot before, _CardSnapshot after) {
    final rows = <_DiffRow>[
      _DiffRow('state', before.cardState.name, after.cardState.name),
      _DiffRow('step', '${before.step ?? '-'}', '${after.step ?? '-'}'),
      _DiffRow(
        'stability',
        before.stability.toStringAsFixed(4),
        after.stability.toStringAsFixed(4),
      ),
      _DiffRow(
        'difficulty',
        before.difficulty.toStringAsFixed(4),
        after.difficulty.toStringAsFixed(4),
      ),
      _DiffRow('reps', '${before.reps}', '${after.reps}'),
      _DiffRow('lapses', '${before.lapses}', '${after.lapses}'),
      _DiffRow('due', _formatDate(before.dueDate), _formatDate(after.dueDate)),
      _DiffRow(
        'scheduledDays',
        '${before.scheduledDays}',
        '${after.scheduledDays}',
      ),
      _DiffRow('elapsedDays', '${before.elapsedDays}', '${after.elapsedDays}'),
    ];

    return DefaultTextStyle(
      style: const TextStyle(
        fontFamily: 'monospace',
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(90),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(20),
          3: FlexColumnWidth(),
        },
        children: [
          for (final row in rows)
            TableRow(
              children: [
                Text(
                  row.label,
                  style: const TextStyle(color: AppColors.textTertiary),
                ),
                Text(row.before),
                const Text(
                  ' → ',
                  style: TextStyle(color: AppColors.textTertiary),
                ),
                Text(
                  row.after,
                  style: TextStyle(
                    color: row.before != row.after
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: row.before != row.after
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDebugSection(
    String title,
    Color color,
    Map<String, String> fields,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          DefaultTextStyle(
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            child: Column(
              children: [
                for (final e in fields.entries)
                  Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          e.key,
                          style: const TextStyle(color: AppColors.textTertiary),
                        ),
                      ),
                      Expanded(child: Text(e.value)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  KeyEventResult _handleKeyPress(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    if (!_showingAnswer) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _flipCard();
        return KeyEventResult.handled;
      }
    } else {
      if (event.logicalKey == LogicalKeyboardKey.digit1) {
        _dismissAndRate(Rating.again);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit2) {
        _dismissAndRate(Rating.hard);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit3) {
        _dismissAndRate(Rating.good);
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.digit4) {
        _dismissAndRate(Rating.easy);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildCardContent(String text) {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Spacing.xl),
                  child: MarkdownBody(
                    data: text,
                    onTapLink: (text, href, title) {
                      if (href != null) launchUrl(Uri.parse(href));
                    },
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.normal),
                          strong: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: WrapAlignment.center,
                          listBullet: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.normal),
                          blockquote: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.normal,
                                color: AppColors.textSecondary,
                              ),
                        ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStudyCard() {
    // Fix: Requests focus after build finishes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_focusNode.canRequestFocus) _focusNode.requestFocus();
    });

    final remaining = _cards.length - _currentIndex;

    Widget flipCard = FlipCard(
      key: ValueKey(_currentIndex),
      isFlipped: _showingAnswer,
      onFlip: _flipCard,
      front: Stack(
        children: [
          Positioned.fill(child: _buildCardContent(_currentCard.front)),
          Positioned(
            left: 0,
            right: 0,
            bottom: Spacing.lg,
            child: Text(
              'Tap to reveal',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
            ),
          ),
        ],
      ),
      back: _buildCardContent(_currentCard.back),
    );

    // On touch platforms, wrap with swipe gesture.
    // Key ensures a fresh SwipeableCard state per card — the old one stays
    // off-screen until _rateCard's setState swaps _currentIndex.
    if (!isDesktop) {
      flipCard = SwipeableCard(
        key: ValueKey('swipe_$_currentIndex'),
        enabled: _showingAnswer,
        onRate: _rateCard,
        onDismissProgress: (progress) {
          if (progress != _swipeProgress) {
            setState(() => _swipeProgress = progress);
          }
        },
        child: flipCard,
      );
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (_, event) => _handleKeyPress(event),
      child: Column(
        children: [
          Expanded(
            child: CardStack(
              remainingCards: remaining,
              dismissProgress: isDesktop ? _dismissOffset : _swipeProgress,
              topCard: LayoutBuilder(
                builder: (context, constraints) {
                  final dx =
                      -constraints.maxWidth *
                      Curves.easeIn.transform(_dismissOffset);
                  return Transform.translate(
                    offset: Offset(dx, 0),
                    child: Opacity(
                      opacity: 1.0 - _dismissOffset,
                      child: MouseRegion(
                        cursor: _showingAnswer
                            ? SystemMouseCursors.basic
                            : SystemMouseCursors.click,
                        child: flipCard,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (isDesktop) ...[
            const SizedBox(height: Spacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
              child: _buildRatingButtons(),
            ),
            const SizedBox(height: Spacing.lg),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingButtons() {
    // Fade from full → dimmed as dismiss animation plays.
    final baseOpacity = _showingAnswer ? 1.0 : 0.3;
    final opacity = baseOpacity - (_dismissOffset * (baseOpacity - 0.3));
    return Opacity(
      opacity: opacity,
      child: IgnorePointer(
        ignoring: !_showingAnswer || _dismissOffset > 0,
        child: Row(
          children: [
            _RatingButton(
              label: 'Again',
              color: AppColors.ratingAgain,
              onPressed: () => _dismissAndRate(Rating.again),
            ),
            const SizedBox(width: Spacing.sm),
            _RatingButton(
              label: 'Hard',
              color: AppColors.ratingHard,
              onPressed: () => _dismissAndRate(Rating.hard),
            ),
            const SizedBox(width: Spacing.sm),
            _RatingButton(
              label: 'Good',
              color: AppColors.ratingGood,
              onPressed: () => _dismissAndRate(Rating.good),
            ),
            const SizedBox(width: Spacing.sm),
            _RatingButton(
              label: 'Easy',
              color: AppColors.ratingEasy,
              onPressed: () => _dismissAndRate(Rating.easy),
            ),
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
          Text(
            'Session Complete!',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'You reviewed $totalReviewed cards',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: Spacing.xxl),
          _buildStatsGrid(),
          const SizedBox(height: Spacing.xxl),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await _flushPendingWrite();
                await _persistSessionSummaryIfNeeded();
                _invalidateDeckProviders();
                if (mounted) context.pop();
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _StatItem(
          label: 'Again',
          count: _ratingCounts[Rating.again]!,
          color: AppColors.ratingAgain,
        ),
        _StatItem(
          label: 'Hard',
          count: _ratingCounts[Rating.hard]!,
          color: AppColors.ratingHard,
        ),
        _StatItem(
          label: 'Good',
          count: _ratingCounts[Rating.good]!,
          color: AppColors.ratingGood,
        ),
        _StatItem(
          label: 'Easy',
          count: _ratingCounts[Rating.easy]!,
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
        content: const Text(
          'Already-reviewed cards are saved. You can resume later.',
        ),
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
      await _flushPendingWrite();
      await _persistSessionSummaryIfNeeded();
      _invalidateDeckProviders();
      if (context.mounted) context.pop();
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

class _DiffRow {
  final String label;
  final String before;
  final String after;
  const _DiffRow(this.label, this.before, this.after);
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
