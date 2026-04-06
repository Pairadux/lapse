import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/study/data/review_session_summary_repository_provider.dart';
import 'package:lapse/features/study/domain/review_streak.dart';

final reviewStreakProvider = FutureProvider<ReviewStreak>((ref) async {
  final repo = ref.watch(reviewSessionSummaryRepositoryProvider);
  return repo.getStreak();
});
