import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/features/study/data/review_repository.dart';
import 'package:lapse/features/study/domain/review.dart';
import 'package:lapse/features/study/domain/rating.dart';

void main() {
  // Initialize sqflite for desktop/test environments
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late DatabaseHelper dbHelper;
  late ReviewRepository repository;

  setUp(() async {
    // Use the name you prefer, but we'll stick to 'test.db'
    dbHelper = DatabaseHelper.forTesting(dbName: 'review_test.db');
    repository = ReviewRepository(dbHelper: dbHelper);

    final db = await dbHelper.database;

    // 1. Force clear the table so we start at 0
    await db.delete(DatabaseConstants.tableReviews);

    // 2. Disable foreign keys
    await db.execute('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    // 4. Close and reset the database after every test
    await dbHelper.close();
  });

  group('ReviewRepository CRUD Tests', () {
    test('Should persist a new review record (Create)', () async {
      // Creates a test Review object
      final review = Review(
        cardId: 'test_card',
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 3,
        elapsedDays: 0,
        state: CardState.review,
      );

      // Calls repository.addReview()
      await repository.addReview(review);

      // Verifies the operation completes without error
      final db = await dbHelper.database;
      final result = await db.query(DatabaseConstants.tableReviews);

      expect(result.length, 1);
      expect(result.first[DatabaseConstants.colCardId], 'test_card');
    });

    test('Should retrieve history for a specific card (Read)', () async {
      // Inserts a review for 'test_card_2'
      final review = Review(
        cardId: 'test_card_2',
        reviewedAt: DateTime.now(),
        rating: Rating.easy,
        scheduledDays: 5,
        elapsedDays: 1,
        state: CardState.review,
      );

      await repository.addReview(review);

      // Calls repository.getReviewsForCard('test_card_2')
      final history = await repository.getReviewsForCard('test_card_2');

      // Asserts that the returned list contains the review you just saved
      expect(history.length, 1);
      expect(history.first.cardId, 'test_card_2');
      expect(history.first.rating, Rating.easy);
    });

    test('Should return reviews in descending chronological order', () async {
      final now = DateTime.now();

      // 1. Inserts an older review
      final oldReview = Review(
        cardId: 'test_card_2',
        reviewedAt: now.subtract(const Duration(days: 1)),
        rating: Rating.again,
        scheduledDays: 0,
        elapsedDays: 0,
        state: CardState.learning,
      );

      // 2. Inserts a newer review
      final newReview = Review(
        cardId: 'test_card_2',
        reviewedAt: now,
        rating: Rating.good,
        scheduledDays: 3,
        elapsedDays: 1,
        state: CardState.review,
      );

      await repository.addReview(oldReview);
      await repository.addReview(newReview);

      // 3. Fetches the reviews and checks the order
      final history = await repository.getReviewsForCard('test_card_2');
      expect(history.length, 2);
      expect(
        history.first.rating,
        Rating.good,
      ); // Checks that the first item in the list is the most recent one
    });
  });

  group('ReviewRepository edge-case testing', () {
    test('addReview throws on empty cardId', () async {
      final review = Review(
        cardId: '', // Edge case: empty string
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 1,
        elapsedDays: 0,
        state: CardState.review,
      );
      expect(() => repository.addReview(review), throwsA(isA<ArgumentError>()));
    });

    test('addReview throws on whitespace cardId', () async {
      final review = Review(
        cardId: '   ', // whitespace only
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 1,
        elapsedDays: 0,
        state: CardState.review,
      );
      expect(() => repository.addReview(review), throwsA(isA<ArgumentError>()));
    });

    test(
      'addReview accepts large scheduledDays and verifies retrieval',
      () async {
        final largeValue = 100000;
        final review = Review(
          cardId: 'test_large',
          reviewedAt: DateTime.now(),
          rating: Rating.good,
          scheduledDays: largeValue,
          elapsedDays: 0,
          state: CardState.review,
        );
        await repository.addReview(review);

        // Optionally fetch and assert
        final history = await repository.getReviewsForCard('test_large');
        expect(history.length, 1);
        expect(history.first.scheduledDays, largeValue);
      },
    );

    test('scheduledDays throws on negative value', () async {
      final review = Review(
        cardId: 'test_days',
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: -7,
        elapsedDays: 0,
        state: CardState.review,
      );
      expect(() => repository.addReview(review), throwsA(isA<ArgumentError>()));
    });

    test(
      'addReview accepts large elapsedDays and verifies retrieval',
      () async {
        final largeValue = 100000;
        final review = Review(
          cardId: 'test_large_elapsed',
          reviewedAt: DateTime.now(),
          rating: Rating.good,
          scheduledDays: 1,
          elapsedDays: largeValue,
          state: CardState.review,
        );
        await repository.addReview(review);

        // Optionally fetch and assert
        final history = await repository.getReviewsForCard(
          'test_large_elapsed',
        );
        expect(history.length, 1);
        expect(history.first.elapsedDays, largeValue);
      },
    );

    test('elapsedDays throws on negative value', () async {
      final review = Review(
        cardId: 'test_elapsed_days',
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 0,
        elapsedDays: -2,
        state: CardState.review,
      );
      expect(() => repository.addReview(review), throwsA(isA<ArgumentError>()));
    });
  });

  group('sync status', () {
    test('addReview sets syncStatus to pending', () async {
      final review = Review(
        cardId: 'sync_test',
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 1,
        elapsedDays: 0,
        state: CardState.review,
      );
      await repository.addReview(review);

      final db = await dbHelper.database;
      final rows = await db.query(
        DatabaseConstants.tableReviews,
        where: '${DatabaseConstants.colCardId} = ?',
        whereArgs: ['sync_test'],
      );
      expect(rows.first[DatabaseConstants.colSyncStatus], 'pending');
    });

    test('getUnsynced returns pending reviews only', () async {
      final r1 = Review(
        reviewId: 'r1',
        cardId: 'card_a',
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 1,
        elapsedDays: 0,
        state: CardState.review,
      );
      final r2 = Review(
        reviewId: 'r2',
        cardId: 'card_b',
        reviewedAt: DateTime.now(),
        rating: Rating.hard,
        scheduledDays: 1,
        elapsedDays: 0,
        state: CardState.review,
      );
      await repository.addReview(r1);
      await repository.addReview(r2);

      await repository.markSynced(['r1']);

      final unsynced = await repository.getUnsynced();
      expect(unsynced, hasLength(1));
      expect(unsynced.first.reviewId, 'r2');
    });

    test('markSynced updates sync status', () async {
      final review = Review(
        reviewId: 'r1',
        cardId: 'card_a',
        reviewedAt: DateTime.now(),
        rating: Rating.good,
        scheduledDays: 1,
        elapsedDays: 0,
        state: CardState.review,
      );
      await repository.addReview(review);
      await repository.markSynced(['r1']);

      final unsynced = await repository.getUnsynced();
      expect(unsynced, isEmpty);
    });

    test('markSynced with empty list is a no-op', () async {
      await repository.markSynced([]);
    });
  });
}
