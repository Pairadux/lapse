class Review {
  final String cardId;
  DateTime reviewedAt;
  int rating;            // 1=Again, 2=Hard, 3=Good, 4=Easy
  int scheduledDays;     // Interval assigned after this review
  int elapsedDays;       // Days since previous review
  CardState state;       // State at time of review

  Review(this.cardId, DateTime.now(), this.rating, this.scheduledDays, this.elapsedDays, this.state);
}