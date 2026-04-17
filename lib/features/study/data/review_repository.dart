import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/study/domain/review.dart';

class ReviewRepository {
  final DatabaseHelper _dbHelper;

  ReviewRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

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
    final syncReady = review.copyWith(syncStatus: SyncStatus.pending);
    await db.insert(DatabaseConstants.tableReviews, syncReady.toMap());
  }

  /// Fetches all historical reviews for cardId from the database.
  Future<List<Review>> getReviewsForCard(String cardId) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseConstants.tableReviews,
      where: '${DatabaseConstants.colCardId} = ?',
      whereArgs: [cardId],
      orderBy: '${DatabaseConstants.colReviewedAt} DESC',
    );
    return maps.map(Review.fromMap).toList();
  }

  /// Returns all reviews with pending sync status.
  Future<List<Review>> getUnsynced() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableReviews,
      where: '${DatabaseConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.synced.name],
    );
    return rows.map(Review.fromMap).toList();
  }

  /// Marks the given review IDs as synced.
  Future<void> markSynced(List<String> reviewIds) async {
    if (reviewIds.isEmpty) return;
    final db = await _dbHelper.database;
    final placeholders = List.filled(reviewIds.length, '?').join(', ');
    await db.update(
      DatabaseConstants.tableReviews,
      {DatabaseConstants.colSyncStatus: SyncStatus.synced.name},
      where: '${DatabaseConstants.colReviewId} IN ($placeholders)',
      whereArgs: reviewIds,
    );
  }

  /// Prunes reviews exceeding 10K per user, keeping only the most recent.
  Future<int> pruneOldReviews(String userId) async {
    const int maxReviews = 10000;
    final db = await _dbHelper.database;

    return await db.transaction<int>((txn) async {
      // Count reviews for this user
      final countResult = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM ${DatabaseConstants.tableReviews} '
        'WHERE ${DatabaseConstants.colUserId} = ?',
        [userId],
      );
      final count = (countResult.first['count'] as int?) ?? 0;

      if (count <= maxReviews) {
        return 0; // No pruning needed
      }

      // Delete oldest reviews beyond the 10K limit
      final deleteCount = count - maxReviews;
      return await txn.rawDelete(
        '''DELETE FROM ${DatabaseConstants.tableReviews}
           WHERE ${DatabaseConstants.colReviewId} IN (
             SELECT ${DatabaseConstants.colReviewId}
             FROM ${DatabaseConstants.tableReviews}
             WHERE ${DatabaseConstants.colUserId} = ?
             ORDER BY ${DatabaseConstants.colReviewedAt} ASC
             LIMIT ?
           )''',
        [userId, deleteCount],
      );
    });
  }
}
