import 'package:equatable/equatable.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/rating.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:uuid/uuid.dart';

class Review extends Equatable {
  final String reviewId; // UUID primary key
  final String cardId;
  final DateTime reviewedAt;
  final Rating rating; // 1=Again, 2=Hard, 3=Good, 4=Easy
  final int scheduledDays; // Interval assigned after this review
  final int elapsedDays; // Days since previous review
  final CardState state; // State at time of review
  final String? userId; // For multi-user support (optional)
  final SyncStatus syncStatus; // Synced, pending, conflict

  static const _uuid = Uuid();

  Review({
    String? reviewId,
    required this.cardId,
    required this.reviewedAt,
    required this.rating,
    required this.scheduledDays,
    required this.elapsedDays,
    required this.state,
    this.userId,
    this.syncStatus = SyncStatus.synced,
  }) : reviewId = reviewId ?? _uuid.v4();

  Review copyWith({
    DateTime? reviewedAt,
    Rating? rating,
    int? scheduledDays,
    int? elapsedDays,
    CardState? state,
    SyncStatus? syncStatus,
  }) {
    return Review(
      reviewId: reviewId, // immutable — set at creation
      cardId: cardId,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rating: rating ?? this.rating,
      scheduledDays: scheduledDays ?? this.scheduledDays,
      elapsedDays: elapsedDays ?? this.elapsedDays,
      state: state ?? this.state,
      userId: userId, // immutable — set at creation
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Converts Review object into a Map for SQLite.
  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colReviewId: reviewId,
      DatabaseConstants.colCardId: cardId,
      DatabaseConstants.colReviewedAt: reviewedAt.toIso8601String(),
      DatabaseConstants.colRating: rating.index,
      DatabaseConstants.colScheduledDays: scheduledDays,
      DatabaseConstants.colElapsedDays: elapsedDays,
      DatabaseConstants.colState: state.index,
      DatabaseConstants.colUserId: userId,
      DatabaseConstants.colSyncStatus: syncStatus.name,
    };
  }

  /// Creates a Review object from a Map retrieved from SQLite.
  factory Review.fromMap(Map<String, dynamic> map) {
    return Review(
      reviewId: map[DatabaseConstants.colReviewId] as String,
      cardId: map[DatabaseConstants.colCardId] as String,
      reviewedAt: DateTime.parse(
        map[DatabaseConstants.colReviewedAt] as String,
      ),
      rating: Rating.values[map[DatabaseConstants.colRating] as int],
      scheduledDays: map[DatabaseConstants.colScheduledDays] as int,
      elapsedDays: map[DatabaseConstants.colElapsedDays] as int,
      state: CardState.values[map[DatabaseConstants.colState] as int],
      userId: map[DatabaseConstants.colUserId] as String?,
      syncStatus: SyncStatus.values.byName(
        map[DatabaseConstants.colSyncStatus] as String,
      ),
    );
  }

  @override
  List<Object?> get props => [
    reviewId,
    cardId,
    reviewedAt,
    rating,
    scheduledDays,
    elapsedDays,
    state,
    userId,
    syncStatus,
  ];
}
