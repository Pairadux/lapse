# Study Feature

## Metadata

| Field | Value |
|-------|-------|
| **Owner** | [TBD - assign at meeting] |
| **Status** | 🔴 Not Started |
| **Last Updated** | [DATE] |
| **Sprint** | Sprint 3 (FSRS + study session) |

## Overview

The Study feature is the core learning experience—presenting due cards, capturing user ratings, and updating review schedules using the FSRS algorithm. This is where spaced repetition actually happens.

---

## User Stories

- As a user, I can start a study session for a deck
- As a user, I see cards one at a time (question first, then reveal answer)
- As a user, I rate my recall (Again, Hard, Good, Easy)
- As a user, I see my progress during the session (X of Y cards)
- As a user, I see a summary when the session is complete
- As a user, I can end a session early if needed

---

## Quick Reference

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| `data/` | Review history storage | `review_repository.dart` |
| `domain/` | Models | `review.dart`, `study_session.dart` |
| `application/` | FSRS logic | `fsrs_service.dart`, `study_session_service.dart` |
| `presentation/` | UI | Screens, widgets, providers |

---

## Folder Structure

```
study/
├── data/
│   ├── review_repository.dart         # Stores review history
│   └── review_local_data_source.dart  # SQLite operations for reviews
│
├── domain/
│   ├── review.dart                    # Review record model
│   ├── study_session.dart             # Session state model
│   └── rating.dart                    # Rating enum (Again, Hard, Good, Easy)
│
├── application/
│   ├── fsrs_service.dart              # Wraps dart-fsrs package
│   └── study_session_service.dart     # Manages session flow logic
│
├── presentation/
│   ├── screens/
│   │   ├── study_session_screen.dart  # Main study interface
│   │   └── study_complete_screen.dart # Session summary
│   │
│   ├── widgets/
│   │   ├── study_card.dart            # Flippable flashcard display
│   │   ├── rating_buttons.dart        # Again/Hard/Good/Easy buttons
│   │   ├── session_progress.dart      # Progress indicator
│   │   └── flip_card.dart             # Card flip animation
│   │
│   └── providers/
│       ├── study_session_provider.dart    # Manages active session state
│       ├── due_cards_provider.dart        # Fetches cards due for review
│       └── session_stats_provider.dart    # Session statistics
│
└── README.md
```

---

## FSRS Integration

### The dart-fsrs Package

We use the official `dart-fsrs` package (pub.dev/packages/fsrs) for scheduling calculations.

**Installation:**
```yaml
dependencies:
  fsrs: ^2.0.0
```

**Basic usage:**
```dart
import 'package:fsrs/fsrs.dart';

// Create scheduler with default parameters
final scheduler = Scheduler();

// Create a new card (or load from database)
final card = Card(cardId: 'abc123');

// After user rates their recall:
final rating = Rating.good;  // 1=Again, 2=Hard, 3=Good, 4=Easy
final (:card updatedCard, :reviewLog) = scheduler.reviewCard(card, rating);

// updatedCard now has updated FSRS state:
// - due: when to review next
// - stability: memory strength
// - difficulty: card difficulty
// - etc.

// Save updatedCard state back to database
```

### FSRS Service Wrapper

Create a service that wraps the package and handles our data model:

```dart
class FsrsService {
  final Scheduler _scheduler = Scheduler();
  
  /// Process a review and return updated card state
  FsrsResult processReview(Flashcard card, Rating rating) {
    // Convert our Flashcard to fsrs Card
    final fsrsCard = _toFsrsCard(card);
    
    // Get scheduling result
    final (:card updatedFsrsCard, :reviewLog) = 
        _scheduler.reviewCard(fsrsCard, rating);
    
    // Convert back to our Flashcard with updated state
    final updatedCard = _fromFsrsCard(card, updatedFsrsCard);
    
    // Create review record for history
    final review = Review(
      id: uuid.v4(),
      cardId: card.id,
      reviewedAt: DateTime.now(),
      rating: rating.value,
      scheduledDays: updatedFsrsCard.scheduledDays,
      elapsedDays: updatedFsrsCard.elapsedDays,
      state: updatedFsrsCard.state,
    );
    
    return FsrsResult(updatedCard: updatedCard, review: review);
  }
}
```

---

## Data Models

### Review (history record)

```dart
class Review {
  final String id;
  final String cardId;
  final DateTime reviewedAt;
  final int rating;           // 1=Again, 2=Hard, 3=Good, 4=Easy
  final int scheduledDays;    // Interval assigned
  final int elapsedDays;      // Days since previous review
  final CardState state;      // State at time of review
}
```

### Study Session (runtime state)

```dart
class StudySession {
  final String deckId;
  final List<Flashcard> cards;      // Cards to review
  final int currentIndex;           // Current position
  final List<Review> completedReviews;  // Reviews this session
  final DateTime startedAt;
  
  bool get isComplete => currentIndex >= cards.length;
  Flashcard get currentCard => cards[currentIndex];
  int get remaining => cards.length - currentIndex;
}
```

### Rating Enum

```dart
enum Rating {
  again(1),  // Forgot completely
  hard(2),   // Remembered with difficulty
  good(3),   // Remembered after hesitation
  easy(4);   // Remembered instantly
  
  final int value;
  const Rating(this.value);
}
```

---

## Study Session Flow

```
1. User taps "Study" on a deck
          ↓
2. Fetch all cards where due <= now AND isDeleted = false
          ↓
3. If no cards due → show "All caught up!" message
          ↓
4. Create StudySession with due cards
          ↓
5. LOOP:
   a. Show current card (front side)
   b. User taps to flip → show back side
   c. User taps rating button (Again/Hard/Good/Easy)
   d. Process with FsrsService → get updated card state
   e. Save updated card to database
   f. Save review record to database
   g. Advance to next card
   h. If more cards → repeat from (a)
          ↓
6. Show completion screen with stats
```

---

## Key Implementation Notes

### Fetching Due Cards

```dart
// In CardRepository (or DueCardsProvider)
Future<List<Flashcard>> getDueCards(String deckId) async {
  final now = DateTime.now().toIso8601String();
  return db.query(
    'cards',
    where: 'deck_id = ? AND due <= ? AND is_deleted = 0',
    whereArgs: [deckId, now],
  );
}
```

### Study Session Screen

- Full-screen card display
- Tap anywhere to flip card
- Rating buttons appear after flip
- Progress bar or "3 of 15" counter
- Exit button (with "are you sure?" confirmation)

### Card Flip Animation

Use `AnimatedSwitcher` or a package like `flip_card`:
```dart
// Simple approach with AnimatedSwitcher
AnimatedSwitcher(
  duration: Duration(milliseconds: 300),
  child: isFlipped 
    ? BackOfCard(card: card, key: ValueKey('back'))
    : FrontOfCard(card: card, key: ValueKey('front')),
)
```

### Rating Buttons

Show expected next review date for each rating:
```
[Again]     [Hard]      [Good]      [Easy]
 <1 min      10 min      1 day       4 days
```

The FSRS scheduler can preview these intervals before the user rates.

### Updating Deck Due Count

After each review, the card's `due` date changes. Update the deck's `dueCount`:
```dart
// After processing review:
await deckRepository.recalculateDueCount(deckId);
```

Or recalculate when returning to deck list.

---

## Interaction with Other Features

### ← Cards Feature
- Reads cards from cards table
- Writes updated FSRS state back to cards table
- Needs `CardRepository.updateFsrsState()` method

### ← Decks Feature
- Gets deck info for header display
- Updates deck's `dueCount` after session

### → Auth Feature (Sprint 4)
- Review records will sync to Supabase
- Card FSRS state will sync

---

## Dependencies

### Internal
- `core/theme`, `core/routing`, `core/widgets`
- `features/cards` — card repository for reading/updating cards
- `features/decks` — deck info, due count updates

### External
- `flutter_riverpod`
- `fsrs: ^2.0.0` — **the FSRS algorithm package**
- `uuid`

---

## Testing Requirements

### Unit Tests (Critical)
- [ ] `FsrsService.processReview()` returns correct next interval
- [ ] New card → Good rating → ~1 day interval
- [ ] Review card → Again rating → relearning state
- [ ] Review card → Easy rating → longer interval
- [ ] Stability increases after successful reviews
- [ ] Difficulty adjusts based on ratings

### Integration Tests
- [ ] Complete study session updates all card states
- [ ] Review records are saved correctly
- [ ] Deck due count updates after session

### Widget Tests
- [ ] Card flips on tap
- [ ] Rating buttons appear after flip
- [ ] Progress updates after each card

---

## Extra Responsibility: Algorithm Documentation

The Study feature owner should write user-facing documentation explaining:
- What spaced repetition is
- What each rating means
- Why intervals get longer over time
- Tips for effective studying

This could be an in-app help screen or README content.

---

## Open Questions

- [ ] Show undo button after rating? (Anki has this)
- [ ] Audio for card flip?
- [ ] Haptic feedback on rating?
- [ ] Study across all decks vs one deck at a time?
- [ ] Daily review limit setting?

---

## Resources

- [dart-fsrs package](https://pub.dev/packages/fsrs)
- [FSRS algorithm wiki](https://github.com/open-spaced-repetition/fsrs4anki/wiki/abc-of-fsrs)
- [Spaced repetition explainer](https://ncase.me/remember/)

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| [DATE] | Initial README created | Austin |
