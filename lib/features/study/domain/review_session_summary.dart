import 'package:equatable/equatable.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:uuid/uuid.dart';

/// A persisted summary of a single study session.
///
/// One row per session (not per day). Aggregated when the session ends.
/// Powers historical stats UI: heatmaps, streaks, rating trends, time-studied.
class ReviewSessionSummary extends Equatable {
  final String id;
  final String userId;
  final String date; // YYYY-MM-DD for fast daily grouping
  final DateTime startedAt;
  final DateTime endedAt;
  final int totalReviews;
  final int againCount;
  final int hardCount;
  final int goodCount;
  final int easyCount;
  final int newCount; // cards in new state when reviewed
  final int learningCount; // cards in learning/relearning state
  final int reviewCount; // cards in review state
  final int durationMs;
  final SyncStatus syncStatus;
  final DateTime updatedAt;

  static const _uuid = Uuid();

  ReviewSessionSummary({
    String? id,
    this.userId = '',
    required this.date,
    required this.startedAt,
    required this.endedAt,
    this.totalReviews = 0,
    this.againCount = 0,
    this.hardCount = 0,
    this.goodCount = 0,
    this.easyCount = 0,
    this.newCount = 0,
    this.learningCount = 0,
    this.reviewCount = 0,
    this.durationMs = 0,
    this.syncStatus = SyncStatus.synced,
    DateTime? updatedAt,
  }) : id = id ?? _uuid.v4(),
       updatedAt = updatedAt ?? DateTime.now();

  /// Creates a summary from a completed study session.
  factory ReviewSessionSummary.fromSession({
    required DateTime startedAt,
    required DateTime endedAt,
    required int againCount,
    required int hardCount,
    required int goodCount,
    required int easyCount,
    required int newCount,
    required int learningCount,
    required int reviewCount,
    String userId = '',
  }) {
    // Streaks are completion-based: count the day the session finishes.
    final date =
        '${endedAt.year}-${endedAt.month.toString().padLeft(2, '0')}-${endedAt.day.toString().padLeft(2, '0')}';
    return ReviewSessionSummary(
      userId: userId,
      date: date,
      startedAt: startedAt,
      endedAt: endedAt,
      totalReviews: againCount + hardCount + goodCount + easyCount,
      againCount: againCount,
      hardCount: hardCount,
      goodCount: goodCount,
      easyCount: easyCount,
      newCount: newCount,
      learningCount: learningCount,
      reviewCount: reviewCount,
      durationMs: endedAt.difference(startedAt).inMilliseconds,
    );
  }

  ReviewSessionSummary copyWith({
    String? userId,
    String? date,
    DateTime? startedAt,
    DateTime? endedAt,
    int? totalReviews,
    int? againCount,
    int? hardCount,
    int? goodCount,
    int? easyCount,
    int? newCount,
    int? learningCount,
    int? reviewCount,
    int? durationMs,
    SyncStatus? syncStatus,
    DateTime? updatedAt,
  }) {
    return ReviewSessionSummary(
      id: id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      totalReviews: totalReviews ?? this.totalReviews,
      againCount: againCount ?? this.againCount,
      hardCount: hardCount ?? this.hardCount,
      goodCount: goodCount ?? this.goodCount,
      easyCount: easyCount ?? this.easyCount,
      newCount: newCount ?? this.newCount,
      learningCount: learningCount ?? this.learningCount,
      reviewCount: reviewCount ?? this.reviewCount,
      durationMs: durationMs ?? this.durationMs,
      syncStatus: syncStatus ?? this.syncStatus,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colSessionId: id,
      DatabaseConstants.colUserId: userId,
      DatabaseConstants.colDate: date,
      DatabaseConstants.colStartedAt: startedAt.toIso8601String(),
      DatabaseConstants.colEndedAt: endedAt.toIso8601String(),
      DatabaseConstants.colTotalReviews: totalReviews,
      DatabaseConstants.colAgainCount: againCount,
      DatabaseConstants.colHardCount: hardCount,
      DatabaseConstants.colGoodCount: goodCount,
      DatabaseConstants.colEasyCount: easyCount,
      DatabaseConstants.colNewCount: newCount,
      DatabaseConstants.colLearningCount: learningCount,
      DatabaseConstants.colReviewCount: reviewCount,
      DatabaseConstants.colDurationMs: durationMs,
      DatabaseConstants.colSyncStatus: syncStatus.name,
      DatabaseConstants.colUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  factory ReviewSessionSummary.fromMap(Map<String, dynamic> map) {
    return ReviewSessionSummary(
      id: map[DatabaseConstants.colSessionId] as String,
      userId: map[DatabaseConstants.colUserId] as String? ?? '',
      date: map[DatabaseConstants.colDate] as String,
      startedAt: DateTime.parse(map[DatabaseConstants.colStartedAt] as String),
      endedAt: DateTime.parse(map[DatabaseConstants.colEndedAt] as String),
      totalReviews: map[DatabaseConstants.colTotalReviews] as int,
      againCount: map[DatabaseConstants.colAgainCount] as int,
      hardCount: map[DatabaseConstants.colHardCount] as int,
      goodCount: map[DatabaseConstants.colGoodCount] as int,
      easyCount: map[DatabaseConstants.colEasyCount] as int,
      newCount: map[DatabaseConstants.colNewCount] as int,
      learningCount: map[DatabaseConstants.colLearningCount] as int,
      reviewCount: map[DatabaseConstants.colReviewCount] as int,
      durationMs: map[DatabaseConstants.colDurationMs] as int,
      syncStatus: SyncStatus.values.byName(
        map[DatabaseConstants.colSyncStatus] as String,
      ),
      updatedAt: DateTime.parse(map[DatabaseConstants.colUpdatedAt] as String),
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    date,
    startedAt,
    endedAt,
    totalReviews,
    againCount,
    hardCount,
    goodCount,
    easyCount,
    newCount,
    learningCount,
    reviewCount,
    durationMs,
    syncStatus,
    updatedAt,
  ];
}
