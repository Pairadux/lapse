import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/features/study/domain/rating.dart';

/// Wraps a child widget with pan-gesture swipe-to-rate on touch devices.
///
/// Swipe directions map to FSRS ratings:
///   Right → Good, Left → Hard, Up → Easy, Down → Again.
///
/// Only active when [enabled] is true (i.e. after card flip).
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final bool enabled;
  final ValueChanged<Rating> onRate;
  final ValueChanged<double>? onDismissProgress;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.enabled,
    required this.onRate,
    this.onDismissProgress,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard>
    with SingleTickerProviderStateMixin {
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isAnimating = false;

  late final AnimationController _returnController;
  late Animation<Offset> _returnAnimation;

  /// Fraction of screen dimension required to commit a swipe.
  static const _commitThresholdH = 0.25;
  static const _commitThresholdV = 0.20;

  /// Maximum rotation in radians during drag.
  static const _maxRotation = 0.15;

  @override
  void initState() {
    super.initState();
    _returnController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _returnController.addListener(() {
      setState(() => _dragOffset = _returnAnimation.value);
      _reportDismissProgress();
    });
    _returnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _isAnimating = false);
      }
    });
  }

  @override
  void dispose() {
    _returnController.dispose();
    super.dispose();
  }

  Rating? get _currentRating {
    if (_dragOffset.distance < 20) return null;

    final angle = _dragOffset.direction;
    // direction returns radians: 0=right, π/2=down, ±π=left, -π/2=up
    if (angle.abs() <= math.pi / 4) return Rating.good; // right
    if (angle.abs() >= 3 * math.pi / 4) return Rating.hard; // left
    if (angle > 0) return Rating.again; // down
    return Rating.easy; // up
  }

  double get _commitProgress {
    final size = MediaQuery.sizeOf(context);
    final isHorizontal =
        _currentRating == Rating.good || _currentRating == Rating.hard;
    final threshold = isHorizontal
        ? size.width * _commitThresholdH
        : size.height * _commitThresholdV;
    return (_dragOffset.distance / threshold).clamp(0.0, 1.0);
  }

  Color get _ratingColor => switch (_currentRating) {
        Rating.again => AppColors.ratingAgain,
        Rating.hard => AppColors.ratingHard,
        Rating.good => AppColors.ratingGood,
        Rating.easy => AppColors.ratingEasy,
        null => Colors.transparent,
      };

  String get _ratingLabel => switch (_currentRating) {
        Rating.again => 'Again',
        Rating.hard => 'Hard',
        Rating.good => 'Good',
        Rating.easy => 'Easy',
        null => '',
      };

  void _reportDismissProgress() {
    widget.onDismissProgress?.call(_commitProgress);
  }

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || _isAnimating) return;
    _returnController.stop();
    setState(() => _isDragging = true);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() => _dragOffset += details.delta);
    _reportDismissProgress();
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;
    setState(() => _isDragging = false);

    final rating = _currentRating;
    if (rating != null && _commitProgress >= 1.0) {
      _animateOffScreen(rating);
    } else {
      _animateReturn();
    }
  }

  void _animateReturn() {
    _isAnimating = true;
    _returnAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _returnController,
      curve: Curves.easeOut,
    ));
    _returnController
      ..reset()
      ..forward();
  }

  void _animateOffScreen(Rating rating) {
    HapticFeedback.mediumImpact();
    _isAnimating = true;
    // Fly off in the drag direction, well past the screen edge.
    final direction = _dragOffset / _dragOffset.distance;
    final size = MediaQuery.sizeOf(context);
    final exitDistance = size.longestSide * 1.5;
    final target = direction * exitDistance;

    _returnAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: target,
    ).animate(CurvedAnimation(
      parent: _returnController,
      curve: Curves.easeIn,
    ));

    _returnController
      ..reset()
      ..forward().then((_) {
        // Don't reset _dragOffset here — the parent's setState will change
        // _currentIndex, giving this widget a new key. The old state (with
        // the off-screen offset) is disposed; the new one starts at zero.
        widget.onRate(rating);
      });
  }

  @override
  Widget build(BuildContext context) {
    // Subtle rotation proportional to horizontal offset.
    final rotation = (_dragOffset.dx / MediaQuery.sizeOf(context).width)
        .clamp(-1.0, 1.0) * _maxRotation;

    // Slight scale-up as you drag (card "coming forward" from the stack).
    final scale = 1.0 + (_commitProgress * 0.04);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // The draggable card.
        Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..translateByDouble(_dragOffset.dx, _dragOffset.dy, 0, 1)
            ..rotateZ(rotation)
            ..scaleByDouble(scale, scale, 1, 1),
          child: GestureDetector(
            onPanStart: _onPanStart,
            onPanUpdate: _onPanUpdate,
            onPanEnd: _onPanEnd,
            child: Stack(
              children: [
                widget.child,
                // Rating label overlay.
                if (_currentRating != null && _commitProgress > 0.1)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _ratingColor
                                .withValues(alpha: _commitProgress * 0.6),
                            width: 3,
                          ),
                        ),
                        alignment: _ratingAlignment,
                        padding: const EdgeInsets.all(20),
                        child: Opacity(
                          opacity: _commitProgress.clamp(0.0, 1.0),
                          child: Transform.rotate(
                            angle: _labelRotation,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surface.withValues(alpha: 0.85),
                                border: Border.all(
                                  color: _ratingColor,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _ratingLabel.toUpperCase(),
                                style: TextStyle(
                                  color: _ratingColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Alignment get _ratingAlignment => switch (_currentRating) {
        Rating.good => Alignment.centerLeft,
        Rating.hard => Alignment.centerRight,
        Rating.easy => Alignment.bottomCenter,
        Rating.again => Alignment.topCenter,
        null => Alignment.center,
      };

  double get _labelRotation => switch (_currentRating) {
        Rating.good => -0.2,
        Rating.hard => 0.2,
        _ => 0.0,
      };
}
