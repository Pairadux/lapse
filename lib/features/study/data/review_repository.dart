import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/features/study/domain/review.dart';

class ReviewRepository {
  final DatabaseHelper _dbHelper;

  ReviewRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // Persists a new review record to the database
  Future<void> addReview(Review review) async {
    // Validation logic
    if (review.cardId.trim().isEmpty) {
      throw ArgumentError('cardId cannot be empty or whitespace');
    }
    if (review.scheduledDays < 0) {
      throw ArgumentError('scheduledDays cannot be negative');
    }
    if (review.elapsedDays < 0) {
      throw ArgumentError('elapsedDays cannot be negative');
    }

    final db = await _dbHelper.database;

    await db.insert(DatabaseConstants.tableReviews, review.toMap());
  }

  /// Fetches all historical reviews for cardId from the database.
  Future<List<Review>> getReviewsForCard(String cardId) async {
    final db = await _dbHelper.database;

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseConstants.tableReviews,
      where: '${DatabaseConstants.colCardId} = ?',
      whereArgs: [cardId],
      orderBy:
          '${DatabaseConstants.colReviewedAt} DESC', // Sorts by reviewedAt() descending so the most recent is at the top
    );

    // Converts the List<Map> into a List<Review>
    return maps.map((map) => Review.fromMap(map)).toList();
  }

}
