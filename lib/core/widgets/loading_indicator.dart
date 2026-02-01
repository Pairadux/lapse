import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/spacing.dart';

class LoadingIndicator extends StatelessWidget {
  final double size;
  final Color? color;

  const LoadingIndicator({
    super.key,
    this.size = Spacing.xxl,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(
          strokeWidth: 3,
          color: color ?? AppColors.primary,
        ),
      ),
    );
  }
}
