import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/study/domain/review.dart';
import 'package:equatable/equatable.dart';

class StudySession extends Equatable {
  final String deckId;
  final List<Flashcard> cards; // Cards to review
  final int currentIndex; // Current position
  final List<Review> completedReviews; // Reviews this session
  final DateTime startedAt;
  final int againCount; // Number of cards with the following ratings
  final int hardCount;
  final int goodCount;
  final int easyCount;

  bool get isComplete => currentIndex >= cards.length;
  Flashcard? get currentCard => isComplete ? null : cards[currentIndex];
  int get remaining => cards.length - currentIndex;

  const StudySession({
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

  StudySession copyWith({
    String? deckId,
    List<Flashcard>? cards,
    int? currentIndex,
    List<Review>? completedReviews,
    DateTime? startedAt,
    int? againCount,
    int? hardCount,
    int? goodCount,
    int? easyCount,
  }) {
    return StudySession(
      deckId: deckId ?? this.deckId,
      cards: cards ?? this.cards,
      currentIndex: currentIndex ?? this.currentIndex,
      completedReviews: completedReviews ?? this.completedReviews,
      startedAt: startedAt ?? this.startedAt,
      againCount: againCount ?? this.againCount,
      hardCount: hardCount ?? this.hardCount,
      goodCount: goodCount ?? this.goodCount,
      easyCount: easyCount ?? this.easyCount,
    );
  }

  @override
  List<Object?> get props => [
    deckId,
    cards,
    currentIndex,
    completedReviews,
    startedAt,
    againCount,
    hardCount,
    goodCount,
    easyCount,
  ];
}
