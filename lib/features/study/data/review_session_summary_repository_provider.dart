import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/study/data/review_session_summary_repository.dart';

final reviewSessionSummaryRepositoryProvider =
    Provider<ReviewSessionSummaryRepository>((ref) {
      return ReviewSessionSummaryRepository();
    });
