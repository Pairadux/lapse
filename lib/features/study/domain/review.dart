class Review {
  final String cardId;
  final DateTime reviewedAt;
  final int rating;            // 1=Again, 2=Hard, 3=Good, 4=Easy
  final int scheduledDays;     // Interval assigned after this review
  final int elapsedDays;       // Days since previous review
  final CardState state;       // State at time of review

  const Review(this.cardId, DateTime.now(), this.rating, this.scheduledDays, this.elapsedDays, this.state);
}