import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A card that flips to reveal its back side.
///
/// Tap to flip. The animation is a subtle 3D rotation (~250ms).
/// Front and back content swap at the midpoint so the back reads correctly
/// (not mirrored).
///
/// The flip axis adapts to aspect ratio: horizontal flip (rotateY) in
/// portrait, vertical flip (rotateX) in landscape. This keeps the
/// rotation along the shorter axis, avoiding a jarring wide-arc sweep.
class FlipCard extends StatefulWidget {
  final Widget front;
  final Widget back;
  final bool isFlipped;
  final VoidCallback onFlip;
  final Duration duration;

  const FlipCard({
    super.key,
    required this.front,
    required this.back,
    required this.isFlipped,
    required this.onFlip,
    this.duration = const Duration(milliseconds: 250),
  });

  @override
  State<FlipCard> createState() => _FlipCardState();
}

class _FlipCardState extends State<FlipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(FlipCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final useVerticalFlip = size.width > size.height;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onFlip();
      },
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final value = _animation.value;
          final showFront = value < 0.5;

          // Front: rotates 0 → π/2 (disappears at edge).
          // Back: rotates -π/2 → 0 (appears from edge, un-mirrored).
          final angle = showFront ? value * math.pi : (value - 1) * math.pi;

          final transform = Matrix4.identity()..setEntry(3, 2, 0.001);
          if (useVerticalFlip) {
            transform.rotateX(angle);
          } else {
            transform.rotateY(angle);
          }

          return Transform(
            alignment: Alignment.center,
            transform: transform,
            child: showFront ? widget.front : widget.back,
          );
        },
      ),
    );
  }
}
