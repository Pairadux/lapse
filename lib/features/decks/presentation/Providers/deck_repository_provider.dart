import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'deck_repository.dart';
import 'deck_repository_impl.dart';
import 'deck_seed.dart';

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return LocalDeckRepository(seedDecks: buildSeedDecks());
});
