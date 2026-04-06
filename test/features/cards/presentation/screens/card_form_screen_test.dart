import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lapse/core/sync/sync_service.dart';
import 'package:lapse/features/cards/data/card_repository_provider.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/cards/presentation/screens/card_form_screen.dart';

class _FakeCardRepository extends CardRepository {
  _FakeCardRepository({Map<String, List<Flashcard>>? seedCards})
    : _cardsByDeck = {
        for (final entry in (seedCards ?? <String, List<Flashcard>>{}).entries)
          entry.key: [...entry.value],
      };

  final Map<String, List<Flashcard>> _cardsByDeck;

  int countInDeck(String deckId) => _cardsByDeck[deckId]?.length ?? 0;

  @override
  Future<Flashcard> create(Flashcard card) async {
    _cardsByDeck.putIfAbsent(card.deckId, () => <Flashcard>[]).add(card);
    return card;
  }

  @override
  Future<bool> frontExistsInDeck({
    required String front,
    required String deckId,
    String? excludeCardId,
  }) async {
    final target = front.trim().toLowerCase();
    return (_cardsByDeck[deckId] ?? <Flashcard>[]).any((card) {
      final sameCard = excludeCardId != null && card.cardId == excludeCardId;
      return !sameCard && card.front.trim().toLowerCase() == target;
    });
  }

  @override
  Future<Flashcard> update(Flashcard card) async => card;

  @override
  Future<void> delete(String cardId) async {}

  @override
  Future<Flashcard?> getById(String cardId) {
    throw UnimplementedError('Unexpected getById call in CardFormScreen tests');
  }

  @override
  Future<List<Flashcard>> getByDeckId(
    String deckId, {
    int? limit,
    int? offset,
  }) {
    throw UnimplementedError(
      'Unexpected getByDeckId call in CardFormScreen tests',
    );
  }

  @override
  Future<List<Flashcard>> getDueCards(String deckId, {DateTime? asOf}) {
    throw UnimplementedError(
      'Unexpected getDueCards call in CardFormScreen tests',
    );
  }

  @override
  Future<int> countByDeckId(String deckId) {
    throw UnimplementedError(
      'Unexpected countByDeckId call in CardFormScreen tests',
    );
  }

  @override
  Future<int> countDueByDeckId(String deckId) {
    throw UnimplementedError(
      'Unexpected countDueByDeckId call in CardFormScreen tests',
    );
  }

  @override
  Future<Map<DateTime, int>> getDueDateCounts() {
    throw UnimplementedError(
      'Unexpected getDueDateCounts call in CardFormScreen tests',
    );
  }

  @override
  Future<List<Flashcard>> getUnsynced() {
    throw UnimplementedError(
      'Unexpected getUnsynced call in CardFormScreen tests',
    );
  }

  @override
  Future<void> markSynced(Map<String, String> idToUpdatedAt) {
    throw UnimplementedError(
      'Unexpected markSynced call in CardFormScreen tests',
    );
  }
}

class _FakeSyncServiceNotifier extends SyncServiceNotifier {
  @override
  SyncState build() => const SyncState();

  @override
  void schedulePush() {}
}

Finder _frontFieldFinder() => find.byType(TextFormField).first;

Finder _backFieldFinder() => find.byType(TextFormField).at(1);

String _fieldText(WidgetTester tester, Finder finder) {
  final field = tester.widget<TextFormField>(finder);
  return field.controller?.text ?? '';
}

Flashcard _seedCard({
  required String deckId,
  required String front,
  required String back,
}) {
  return Flashcard.newCard(deckId: deckId, front: front, back: back);
}

Future<void> _pumpCardForm(
  WidgetTester tester, {
  required String deckId,
  required CardRepository repo,
}) async {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => CardFormScreen(deckId: deckId),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        cardRepositoryProvider.overrideWith((ref) => repo),
        syncServiceProvider.overrideWith(_FakeSyncServiceNotifier.new),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _saveAndExpectCleared(
  WidgetTester tester, {
  required _FakeCardRepository repo,
  required String deckId,
  required String front,
  required String back,
  required int sessionCreatedCount,
}) async {
  await tester.enterText(_frontFieldFinder(), front);
  await tester.enterText(_backFieldFinder(), back);
  await tester.tap(find.widgetWithText(OutlinedButton, 'Save & Add Another'));
  // First frame applies form state updates; second frame renders snackbar/count.
  await tester.pump();
  await tester.pump();

  expect(_fieldText(tester, _frontFieldFinder()), isEmpty);
  expect(_fieldText(tester, _backFieldFinder()), isEmpty);
  expect(
    find.text(
      '$sessionCreatedCount card${sessionCreatedCount == 1 ? '' : 's'} added',
    ),
    findsOneWidget,
  );
  expect(repo.countInDeck(deckId), greaterThanOrEqualTo(sessionCreatedCount));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('Save & Add Another clears fields in an empty top-level deck', (
    tester,
  ) async {
    const deckId = 'top-level-empty';
    final repo = _FakeCardRepository();

    await _pumpCardForm(tester, deckId: deckId, repo: repo);

    await _saveAndExpectCleared(
      tester,
      repo: repo,
      deckId: deckId,
      front: 'Top-level question 1',
      back: 'Top-level answer 1',
      sessionCreatedCount: 1,
    );
    await _saveAndExpectCleared(
      tester,
      repo: repo,
      deckId: deckId,
      front: 'Top-level question 2',
      back: 'Top-level answer 2',
      sessionCreatedCount: 2,
    );
  });

  testWidgets('Save & Add Another clears fields in an empty nested deck', (
    tester,
  ) async {
    const deckId = 'nested-empty';
    final repo = _FakeCardRepository();

    await _pumpCardForm(tester, deckId: deckId, repo: repo);

    await _saveAndExpectCleared(
      tester,
      repo: repo,
      deckId: deckId,
      front: 'Nested question 1',
      back: 'Nested answer 1',
      sessionCreatedCount: 1,
    );
    await _saveAndExpectCleared(
      tester,
      repo: repo,
      deckId: deckId,
      front: 'Nested question 2',
      back: 'Nested answer 2',
      sessionCreatedCount: 2,
    );
  });

  testWidgets(
    'Save & Add Another clears fields when nested deck already has cards',
    (tester) async {
      const deckId = 'nested-with-existing';
      final repo = _FakeCardRepository(
        seedCards: {
          deckId: [
            _seedCard(
              deckId: deckId,
              front: 'Existing front',
              back: 'Existing back',
            ),
          ],
        },
      );

      await _pumpCardForm(tester, deckId: deckId, repo: repo);

      await _saveAndExpectCleared(
        tester,
        repo: repo,
        deckId: deckId,
        front: 'Fresh question 1',
        back: 'Fresh answer 1',
        sessionCreatedCount: 1,
      );
      await _saveAndExpectCleared(
        tester,
        repo: repo,
        deckId: deckId,
        front: 'Fresh question 2',
        back: 'Fresh answer 2',
        sessionCreatedCount: 2,
      );
    },
  );
}
