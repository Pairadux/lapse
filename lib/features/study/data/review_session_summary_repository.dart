import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/features/study/domain/review_session_summary.dart';

class ReviewSessionSummaryRepository {
  final DatabaseHelper _dbHelper;

  ReviewSessionSummaryRepository({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Persists a completed session summary.
  Future<void> add(ReviewSessionSummary summary) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseConstants.tableReviewSessionSummary,
      summary.toMap(),
    );
  }

  /// Returns all session summaries for a given date (YYYY-MM-DD).
  Future<List<ReviewSessionSummary>> getByDate(String date) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseConstants.tableReviewSessionSummary,
      where: '${DatabaseConstants.colDate} = ?',
      whereArgs: [date],
      orderBy: '${DatabaseConstants.colStartedAt} ASC',
    );
    return maps.map(ReviewSessionSummary.fromMap).toList();
  }

  /// Returns all session summaries within a date range (inclusive).
  Future<List<ReviewSessionSummary>> getByDateRange(
    String startDate,
    String endDate,
  ) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseConstants.tableReviewSessionSummary,
      where: '${DatabaseConstants.colDate} >= ? AND ${DatabaseConstants.colDate} <= ?',
      whereArgs: [startDate, endDate],
      orderBy: '${DatabaseConstants.colStartedAt} ASC',
    );
    return maps.map(ReviewSessionSummary.fromMap).toList();
  }

  /// Returns all session summaries, ordered by most recent first.
  Future<List<ReviewSessionSummary>> getAll() async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseConstants.tableReviewSessionSummary,
      orderBy: '${DatabaseConstants.colStartedAt} DESC',
    );
    return maps.map(ReviewSessionSummary.fromMap).toList();
  }

  /// Returns aggregate daily stats: total reviews, duration, and rating
  /// breakdown for each date in the range. Uses SQL aggregation to avoid
  /// pulling full rows into Dart.
  Future<List<Map<String, dynamic>>> getDailyStats(
    String startDate,
    String endDate,
  ) async {
    final db = await _dbHelper.database;
    return db.rawQuery('''
      SELECT
        ${DatabaseConstants.colDate},
        SUM(${DatabaseConstants.colTotalReviews}) AS ${DatabaseConstants.colTotalReviews},
        SUM(${DatabaseConstants.colAgainCount}) AS ${DatabaseConstants.colAgainCount},
        SUM(${DatabaseConstants.colHardCount}) AS ${DatabaseConstants.colHardCount},
        SUM(${DatabaseConstants.colGoodCount}) AS ${DatabaseConstants.colGoodCount},
        SUM(${DatabaseConstants.colEasyCount}) AS ${DatabaseConstants.colEasyCount},
        SUM(${DatabaseConstants.colNewCount}) AS ${DatabaseConstants.colNewCount},
        SUM(${DatabaseConstants.colLearningCount}) AS ${DatabaseConstants.colLearningCount},
        SUM(${DatabaseConstants.colReviewCount}) AS ${DatabaseConstants.colReviewCount},
        SUM(${DatabaseConstants.colDurationMs}) AS ${DatabaseConstants.colDurationMs}
      FROM ${DatabaseConstants.tableReviewSessionSummary}
      WHERE ${DatabaseConstants.colDate} >= ? AND ${DatabaseConstants.colDate} <= ?
      GROUP BY ${DatabaseConstants.colDate}
      ORDER BY ${DatabaseConstants.colDate} ASC
    ''', [startDate, endDate]);
  }
}
