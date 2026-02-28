import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/features/study/domain/review.dart';

class ReviewRepository {
  final DatabaseHelper _dbHelper;

  ReviewRepository({DatabaseHelper? dbHelper}) : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  // Persists a new review record to the database
  Future<void> addReview(Review review) async {
    final db = await _dbHelper.database;

    // Use fields from constants as table name and column keys
    await db.insert(DatabaseConstants.tableReviews, {
      DatabaseConstants.colCardId: review.cardId,
      DatabaseConstants.colReviewedAt: review.reviewedAt.toIso8601String(),
      DatabaseConstants.colRating: _ratingToInt(review.rating),
      DatabaseConstants.colScheduledDays: review.scheduledDays,
      DatabaseConstants.colElapsedDays: review.elapsedDays,
      DatabaseConstants.colState: _stateToInt(review.state),
    });
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

  // Helpers to match the INT. types in the schema
  int _ratingToInt(dynamic rating) => rating.index;
  int _stateToInt(dynamic state) => state.index;
}
