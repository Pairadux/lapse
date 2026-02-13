import 'package:flutter/material.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';

class SpeedDialAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const SpeedDialAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });
}

class SpeedDialFab extends StatefulWidget {
  final List<SpeedDialAction> actions;

  const SpeedDialFab({super.key, required this.actions});

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      if (_isOpen) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  void _close() {
    if (_isOpen) _toggle();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Action items (shown when open)
        ...widget.actions.reversed.map((action) {
          final index = widget.actions.indexOf(action);
          final delay = index / widget.actions.length;
          return _SpeedDialItem(
            icon: action.icon,
            label: action.label,
            animation: CurvedAnimation(
              parent: _controller,
              curve: Interval(delay, 1.0, curve: Curves.easeOut),
            ),
            onTap: () {
              _close();
              action.onPressed();
            },
          );
        }),
        // Main FAB
        FloatingActionButton(
          heroTag: null,
          onPressed: _toggle,
          child: AnimatedRotation(
            turns: _isOpen ? 0.125 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }
}

class _SpeedDialItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Animation<double> animation;
  final VoidCallback onTap;

  const _SpeedDialItem({
    required this.icon,
    required this.label,
    required this.animation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        if (animation.value == 0) return const SizedBox.shrink();
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: Spacing.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(Spacing.radiusSm),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.md,
                  vertical: Spacing.sm,
                ),
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
            ),
            const SizedBox(width: Spacing.md),
            FloatingActionButton.small(
              heroTag: null,
              onPressed: onTap,
              child: Icon(icon),
            ),
          ],
        ),
      ),
    );
  }
}
