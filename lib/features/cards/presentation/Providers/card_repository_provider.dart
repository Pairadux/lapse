import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card_repository.dart';
import 'card_repository_impl.dart';
import 'card_seed.dart';

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return LocalCardRepository(seedCards: buildSeedCards());
});
