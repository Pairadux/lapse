import 'package:lapse/features/decks/domain/deck.dart';

List<Deck> buildSeedDecks() {
  final now = DateTime.now();
  return [
    // Root-level decks (parentID: '')
    // Languages is a folder - no direct cards, children have 10 total
    Deck(
      deckID: '1',
      parentID: '',
      deckName: 'Languages',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 0,
      dueCount: 0,
    ),
    // Science is a folder - no direct cards, children have 6 total
    Deck(
      deckID: '2',
      parentID: '',
      deckName: 'Science',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 0,
      dueCount: 0,
    ),
    // History 101 is a leaf deck with 3 cards
    Deck(
      deckID: '3',
      parentID: '',
      deckName: 'History 101',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 3,
      dueCount: 3,
    ),
    // Nested under Languages (parentID: '1')
    Deck(
      deckID: '1-1',
      parentID: '1',
      deckName: 'Spanish',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 5,
      dueCount: 5,
    ),
    Deck(
      deckID: '1-2',
      parentID: '1',
      deckName: 'Japanese',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 5,
      dueCount: 5,
    ),
    // Nested under Science (parentID: '2')
    Deck(
      deckID: '2-1',
      parentID: '2',
      deckName: 'Biology',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 3,
      dueCount: 3,
    ),
    Deck(
      deckID: '2-2',
      parentID: '2',
      deckName: 'Chemistry',
      createdAt: now,
      updatedAt: now,
      isDeleted: false,
      cards: const [],
      cardCount: 3,
      dueCount: 3,
    ),
  ];
}
