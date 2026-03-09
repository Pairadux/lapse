import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';

export 'package:lapse/features/decks/data/deck_repository.dart';

final deckRepositoryProvider = Provider<DeckRepository>((ref) {
  return DeckRepository();
});
