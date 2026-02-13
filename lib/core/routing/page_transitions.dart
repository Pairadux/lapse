import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

bool get isDesktop =>
    Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// Returns a platform-appropriate page for GoRouter routes.
///
/// Desktop: 150ms crossfade for a standard desktop feel.
/// Mobile: default MaterialPage (inherits theme transitions).
Page<void> buildPage(GoRouterState state, Widget child) {
  if (isDesktop) {
    return CustomTransitionPage(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 150),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
      },
    );
  }
  return MaterialPage(key: state.pageKey, child: child);
}
