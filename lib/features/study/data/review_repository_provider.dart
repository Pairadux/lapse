import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/study/data/review_repository.dart';

export 'package:lapse/features/study/data/review_repository.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  return ReviewRepository();
});
