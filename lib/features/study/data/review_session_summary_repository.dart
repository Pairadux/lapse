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
    final asOfDay = _dateOnly(asOf ?? DateTime.now());
    final today = _formatDateOnly(asOfDay);
    final yesterday = _formatDateOnly(
      asOfDay.subtract(const Duration(days: 1)),
    );

    final summaryRows = await db.rawQuery(
      '''
      WITH completed_days AS (
        SELECT DISTINCT ${DatabaseConstants.colDate} AS day
        FROM ${DatabaseConstants.tableReviewSessionSummary}
        WHERE ${DatabaseConstants.colTotalReviews} > 0
      )
      SELECT
        MAX(day) AS last_completed_date,
        COALESCE(MAX(CASE WHEN day = ? THEN 1 ELSE 0 END), 0) AS has_today,
        COALESCE(MAX(CASE WHEN day = ? THEN 1 ELSE 0 END), 0) AS has_yesterday
      FROM completed_days
      ''',
      [today, yesterday],
    );

    final summary = summaryRows.first;
    final lastCompleted = summary['last_completed_date'] as String?;
    if (lastCompleted == null) return const ReviewStreak.empty();

    final hasToday = (summary['has_today'] as int) == 1;
    final hasYesterday = (summary['has_yesterday'] as int) == 1;
    final anchorDay = hasToday
        ? today
        : hasYesterday
        ? yesterday
        : null;

    final longestRows = await db.rawQuery('''
      WITH completed_days AS (
        SELECT DISTINCT ${DatabaseConstants.colDate} AS day
        FROM ${DatabaseConstants.tableReviewSessionSummary}
        WHERE ${DatabaseConstants.colTotalReviews} > 0
      ),
      ranked AS (
        SELECT
          day,
          ROW_NUMBER() OVER (ORDER BY day) AS rn
        FROM completed_days
      ),
      runs AS (
        SELECT
          (JULIANDAY(day) - rn) AS grp,
          COUNT(*) AS streak_len
        FROM ranked
        GROUP BY grp
      )
      SELECT COALESCE(MAX(streak_len), 0) AS longest_streak
      FROM runs
      ''');
    final longest = longestRows.first['longest_streak'] as int;

    var current = 0;
    if (anchorDay != null) {
      final currentRows = await db.rawQuery(
        '''
        WITH RECURSIVE streak(day) AS (
          SELECT ?
          UNION ALL
          SELECT DATE(day, '-1 day')
          FROM streak
          WHERE EXISTS (
            SELECT 1
            FROM ${DatabaseConstants.tableReviewSessionSummary}
            WHERE ${DatabaseConstants.colDate} = DATE(day, '-1 day')
              AND ${DatabaseConstants.colTotalReviews} > 0
          )
        )
        SELECT COUNT(*) AS current_streak
        FROM streak
        ''',
        [anchorDay],
      );
      current = currentRows.first['current_streak'] as int;
    }

    return ReviewStreak(
      currentStreak: current,
      longestStreak: longest,
      lastCompletedDate: lastCompleted,
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _formatDateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
