import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/study/data/review_session_summary_repository_provider.dart';
import 'package:lapse/features/study/domain/review_streak.dart';

/// Emits on first watch and again whenever the local day rolls over.
final _streakDayRefreshProvider = StreamProvider.autoDispose<int>((ref) async* {
  var tick = 0;
  yield tick;

  while (true) {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);
    await Future<void>.delayed(delay);
    tick++;
    yield tick;
  }
});

/// Emits when the app resumes so stale cached values refresh after background.
final _streakResumeRefreshProvider = StreamProvider.autoDispose<int>((ref) {
  final controller = StreamController<int>();
  var tick = 0;
  controller.add(tick);
  final listener = AppLifecycleListener(
    onResume: () {
      tick++;
      if (!controller.isClosed) {
        controller.add(tick);
      }
    },
  );

  ref.onDispose(() {
    listener.dispose();
    controller.close();
  });

  return controller.stream;
});

final reviewStreakProvider = FutureProvider.autoDispose<ReviewStreak>((
  ref,
) async {
  ref.watch(_streakDayRefreshProvider);
  ref.watch(_streakResumeRefreshProvider);
  final repo = ref.watch(reviewSessionSummaryRepositoryProvider);
  return repo.getStreak();
});
