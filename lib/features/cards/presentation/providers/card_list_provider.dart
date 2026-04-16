import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/presentation/providers/deck_list_provider.dart';
import 'package:lapse/features/notifications/presentation/providers/notification_providers.dart';

final cardListProvider =
    AsyncNotifierProvider.family<CardListNotifier, List<Flashcard>, String>(
      (arg) => CardListNotifier(arg),
    );

class CardListNotifier extends AsyncNotifier<List<Flashcard>> {
  CardListNotifier(this.deckId);
  final String deckId;

  @override
  Future<List<Flashcard>> build() {
    return ref.watch(cardRepositoryProvider).getByDeckId(deckId);
  }

  Future<void> createCard(Flashcard card) async {
    state = await AsyncValue.guard(() async {
      await ref.read(cardRepositoryProvider).create(card);
      return ref.read(cardRepositoryProvider).getByDeckId(card.deckId);
    });
    ref.invalidate(deckListProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
  }

  Future<void> updateCard(Flashcard card) async {
    state = await AsyncValue.guard(() async {
      await ref.read(cardRepositoryProvider).update(card);
      return ref.read(cardRepositoryProvider).getByDeckId(card.deckId);
    });
    ref.invalidate(deckListProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
  }

  Future<void> deleteCard(String cardId) async {
    state = await AsyncValue.guard(() async {
      await ref.read(cardRepositoryProvider).delete(cardId);
      return ref.read(cardRepositoryProvider).getByDeckId(deckId);
    });
    ref.invalidate(deckListProvider);
    ref.read(syncServiceProvider.notifier).schedulePush();
    unawaited(ref.read(dueReminderSchedulerProvider).syncSchedule());
  }
}
