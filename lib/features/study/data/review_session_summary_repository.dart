import 'package:lapse/core/database/database_helper.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/study/domain/review_streak.dart';
import 'package:lapse/features/study/domain/review_session_summary.dart';

class ReviewSessionSummaryRepository {
  final DatabaseHelper _dbHelper;

  ReviewSessionSummaryRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Persists a completed session summary.
  Future<void> add(ReviewSessionSummary summary) async {
    final db = await _dbHelper.database;
    final syncReady = summary.copyWith(syncStatus: SyncStatus.pending);
    await db.insert(
      DatabaseConstants.tableReviewSessionSummary,
      syncReady.toMap(),
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
      where:
          '${DatabaseConstants.colDate} >= ? AND ${DatabaseConstants.colDate} <= ?',
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

  /// Returns all session summaries with pending sync status.
  Future<List<ReviewSessionSummary>> getUnsynced() async {
    final db = await _dbHelper.database;
    final rows = await db.query(
      DatabaseConstants.tableReviewSessionSummary,
      where: '${DatabaseConstants.colSyncStatus} != ?',
      whereArgs: [SyncStatus.synced.name],
    );
    return rows.map(ReviewSessionSummary.fromMap).toList();
  }

  /// Marks the given session summaries as synced, guarded by `updated_at`
  /// to prevent a TOCTOU race (local edit between push read and markSynced).
  Future<void> markSynced(Map<String, String> idToUpdatedAt) async {
    if (idToUpdatedAt.isEmpty) return;
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final entry in idToUpdatedAt.entries) {
        await txn.update(
          DatabaseConstants.tableReviewSessionSummary,
          {DatabaseConstants.colSyncStatus: SyncStatus.synced.name},
          where:
              '${DatabaseConstants.colSessionId} = ? AND ${DatabaseConstants.colUpdatedAt} = ?',
          whereArgs: [entry.key, entry.value],
        );
      }
    });
  }

  /// Returns aggregate daily stats: total reviews, duration, and rating
  /// breakdown for each date in the range. Uses SQL aggregation to avoid
  /// pulling full rows into Dart.
  Future<List<Map<String, dynamic>>> getDailyStats(
    String startDate,
    String endDate,
  ) async {
    final db = await _dbHelper.database;
    return db.rawQuery(
      '''
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
    ''',
      [startDate, endDate],
    );
  }

  /// Returns streak stats derived from completed review sessions.
  ///
  /// Rules:
  /// - A day counts only if at least one session that day has total_reviews > 0.
  /// - Current streak is consecutive days ending at:
  ///   - today, if completed today
  ///   - yesterday, if not completed today but yesterday is completed
  ///   - otherwise 0
  /// - Longest streak is the max consecutive run across all completed days.
  Future<ReviewStreak> getStreak({DateTime? asOf}) async {
    final db = await _dbHelper.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT ${DatabaseConstants.colDate} AS ${DatabaseConstants.colDate}
      FROM ${DatabaseConstants.tableReviewSessionSummary}
      WHERE ${DatabaseConstants.colTotalReviews} > 0
      ORDER BY ${DatabaseConstants.colDate} ASC
      ''');

    if (rows.isEmpty) return const ReviewStreak.empty();

    final days =
        rows
            .map(
              (row) => _parseDateOnly(row[DatabaseConstants.colDate] as String),
            )
            .toList()
          ..sort();

    final longest = _computeLongest(days);
    final today = _dateOnly(asOf ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final daySet = days.toSet();

    int current = 0;
    if (daySet.contains(today)) {
      current = _countBackwardsFrom(daySet, today);
    } else if (daySet.contains(yesterday)) {
      current = _countBackwardsFrom(daySet, yesterday);
    }

    final lastCompleted = _formatDateOnly(days.last);

    return ReviewStreak(
      currentStreak: current,
      longestStreak: longest,
      lastCompletedDate: lastCompleted,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _parseDateOnly(String date) {
    final parsed = DateTime.parse(date);
    return _dateOnly(parsed);
  }

  static String _formatDateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static int _computeLongest(List<DateTime> daysSortedAsc) {
    if (daysSortedAsc.isEmpty) return 0;
    var longest = 1;
    var run = 1;

    for (var i = 1; i < daysSortedAsc.length; i++) {
      final prev = daysSortedAsc[i - 1];
      final curr = daysSortedAsc[i];
      final delta = curr.difference(prev).inDays;

      if (delta == 1) {
        run++;
        if (run > longest) longest = run;
      } else if (delta > 1) {
        run = 1;
      }
    }
    return longest;
  }

  static int _countBackwardsFrom(Set<DateTime> days, DateTime endDay) {
    var count = 0;
    var cursor = endDay;
    while (days.contains(cursor)) {
      count++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return count;
  }
}
