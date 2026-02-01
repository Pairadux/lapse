import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/review.dart';

class StudySession {
  final String deckId;
  List<Flashcard> cards; // Cards to review
  final int currentIndex; // Current position
  final List<Review> completedReviews; // Reviews this session
  final DateTime startedAt;
  int againCount; // Number of cards with the following ratings
  int hardCount;
  int goodCount;
  int easyCount;

  bool get isComplete => currentIndex >= cards.length;
  Flashcard get currentCard => cards[currentIndex];
  int get remaining => cards.length - currentIndex;

  StudySession({
    required this.deckId,
    required this.cards,
    required this.currentIndex,
    required this.completedReviews,
    required this.startedAt,
    required this.againCount,
    required this.hardCount,
    required this.goodCount,
    required this.easyCount,
  });
}
