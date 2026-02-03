import 'package:lapse/features/cards/domain/flashcard.dart';

List<Flashcard> buildSeedCards() {
  final now = DateTime.now();
  return [
    // History 101 (deckID: 3) - 3 cards
    Flashcard(
      cardID: '3-1',
      deckId: '3',
      front: 'Who wrote the Declaration of Independence?',
      back: 'Thomas Jefferson',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      dueDate: now,
      stability: 1.0,
      difficulty: 5.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      lastReview: null,
      cardState: CardState.newCard,
    ),
    Flashcard(
      cardID: '3-2',
      deckId: '3',
      front: 'What year did WW2 end?',
      back: '1945',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      dueDate: now,
      stability: 1.0,
      difficulty: 5.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      lastReview: null,
      cardState: CardState.newCard,
    ),
    Flashcard(
      cardID: '3-3',
      deckId: '3',
      front: 'What was the first empire to use gunpowder weapons?',
      back: 'The Ottoman Empire',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      dueDate: now,
      stability: 1.0,
      difficulty: 5.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      lastReview: null,
      cardState: CardState.newCard,
    ),
    // Spanish (deckID: 1-1) - 5 cards
    ..._languageCards(deckId: '1-1', baseId: '1-1'),
    // Japanese (deckID: 1-2) - 5 cards
    ..._languageCards(deckId: '1-2', baseId: '1-2'),
    // Biology (deckID: 2-1) - 3 cards
    ..._scienceCards(deckId: '2-1', baseId: '2-1'),
    // Chemistry (deckID: 2-2) - 3 cards
    ..._scienceCards(deckId: '2-2', baseId: '2-2'),
  ];
}

List<Flashcard> _languageCards({
  required String deckId,
  required String baseId,
}) {
  final now = DateTime.now();
  final fronts = [
    'Hello',
    'Thank you',
    'Please',
    'Goodbye',
    'Yes',
  ];
  final backs = [
    'Hola / Konnichiwa',
    'Gracias / Arigato',
    'Por favor / Onegaishimasu',
    'Adios / Sayonara',
    'Si / Hai',
  ];

  return List<Flashcard>.generate(fronts.length, (index) {
    return Flashcard(
      cardID: '$baseId-${index + 1}',
      deckId: deckId,
      front: fronts[index],
      back: backs[index],
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      dueDate: now,
      stability: 1.0,
      difficulty: 5.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      lastReview: null,
      cardState: CardState.newCard,
    );
  });
}

List<Flashcard> _scienceCards({
  required String deckId,
  required String baseId,
}) {
  final now = DateTime.now();
  final fronts = [
    'What is the powerhouse of the cell?',
    'What is the chemical symbol for water?',
    'What is the speed of light (approx)?',
  ];
  final backs = [
    'Mitochondria',
    'H2O',
    '3.0 x 10^8 m/s',
  ];

  return List<Flashcard>.generate(fronts.length, (index) {
    return Flashcard(
      cardID: '$baseId-${index + 1}',
      deckId: deckId,
      front: fronts[index],
      back: backs[index],
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      dueDate: now,
      stability: 1.0,
      difficulty: 5.0,
      elapsedDays: 0,
      scheduledDays: 0,
      reps: 0,
      lapses: 0,
      lastReview: null,
      cardState: CardState.newCard,
    );
  });
}
