import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/features/cards/data/card_repository.dart';

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository();
});
