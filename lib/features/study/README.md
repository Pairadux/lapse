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

## Architecture Decisions

### Why `Rating` Lives Here (Not in Cards)

`Rating` is a **study-time action**, not a card property. The flow:

```
Card (data)          Study (process)           Card (updated)
    │                      │                        │
    └───► User sees card   │                        │
          User rates ◄──── Rating (INPUT)           │
          FSRS calculates                           │
          Card.due ◄────── (OUTPUT) ────────────────┘
```

Cards store the **outcome** (`due`, `stability`). Rating is a **transient input** to the study process. This keeps the cards feature as dumb data containers.

### Review History: Skip for MVP

A `Review` record logs every rating event (cardId, rating, timestamp). This enables:
- Analytics ("85% retention this week")
- FSRS parameter optimization
- Undo functionality

**The cost:** 100 cards/day × 365 days = 36,500 rows/year per user.

**For MVP:** Skip review persistence entirely. Update card scheduling state directly. Add review history later if you need stats or FSRS optimization.

### Flat Domain Structure

Don't create `domain/models/` subfolder—just put files directly in `domain/`. Only add subfolders if you have 5+ files and it feels cluttered.

---

## User Stories

- As a user, I can start a study session for a deck
- As a user, I see cards one at a time (question first, then reveal answer)
- As a user, I rate my recall (Again, Good — or full Again/Hard/Good/Easy)
- As a user, I see my progress during the session (X of Y cards)
- As a user, I see a summary when the session is complete
- As a user, I can end a session early if needed

---

## Quick Reference

### MVP (Minimal)

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| `domain/` | Models | `rating.dart`, `study_session.dart` |
| `application/` | Session logic | `study_session_service.dart` |
| `presentation/` | UI + state | `providers/study_session_provider.dart` |

### Full Implementation (Later)

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| `domain/` | Models | `rating.dart`, `study_session.dart` |
| `application/` | FSRS + session logic | `fsrs_service.dart`, `study_session_service.dart` |
| `data/` | Review persistence | `review_repository.dart` (if tracking history) |
| `presentation/` | UI | Screens, widgets, providers |

---

## Folder Structure

```
study/
├── data/
│   ├── review_repository.dart         # Stores review history (optional, for stats)
│   └── review_local_data_source.dart  # SQLite operations for reviews
│
├── domain/
│   ├── rating.dart                    # Rating enum (Again, Hard, Good, Easy)
│   ├── study_session.dart             # Session state model
│   └── review.dart                    # Review record model (optional, for stats)
│
├── application/
│   ├── study_session_service.dart     # Manages session flow logic
│   └── fsrs_service.dart              # Wraps dart-fsrs package
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

## MVP Implementation Guide

Build in this order for fastest path to working study flow:

### Step 1: Domain Models (~15 min)

**`domain/rating.dart`**
```dart
enum Rating {
  again,  // Forgot — show again soon
  good,   // Remembered — schedule next review
}
```

**`domain/study_session.dart`**
```dart
class StudySession {
  final String deckId;
  final List<Flashcard> cards;
  final Set<String> studiedIds;
  final int againCount;
  final int goodCount;
  final DateTime startedAt;

  Flashcard? get currentCard {
    return cards.cast<Flashcard?>().firstWhere(
      (c) => !studiedIds.contains(c!.id),
      orElse: () => null,
    );
  }

  bool get isComplete => studiedIds.length >= cards.length;
  int get remaining => cards.length - studiedIds.length;
  int get total => cards.length;
}
```

### Step 2: Session Service (~30 min)

**`application/study_session_service.dart`**
```dart
class StudySessionService {
  StudySession startSession(String deckId, List<Flashcard> cards) {
    return StudySession(
      deckId: deckId,
      cards: cards,
      studiedIds: {},
      againCount: 0,
      goodCount: 0,
      startedAt: DateTime.now(),
    );
  }

  StudySession rateCard(StudySession session, Flashcard card, Rating rating) {
    // Mark as studied
    final newStudiedIds = {...session.studiedIds, card.id};

    // Update counts
    return session.copyWith(
      studiedIds: newStudiedIds,
      againCount: rating == Rating.again
          ? session.againCount + 1
          : session.againCount,
      goodCount: rating == Rating.good
          ? session.goodCount + 1
          : session.goodCount,
    );
  }
}
```

### Step 3: Riverpod Provider (~30 min)

**`presentation/providers/study_session_provider.dart`**
```dart
@riverpod
class StudySessionNotifier extends _$StudySessionNotifier {
  late final StudySessionService _service;

  @override
  StudySession? build() {
    _service = StudySessionService();
    return null;
  }

  void startSession(String deckId, List<Flashcard> cards) {
    state = _service.startSession(deckId, cards);
  }

  void rateCard(Rating rating) {
    if (state == null) return;
    final card = state!.currentCard;
    if (card == null) return;

    state = _service.rateCard(state!, card, rating);

    // TODO: Update card.due in database (add FSRS later)
  }

  void endSession() {
    state = null;
  }
}
```

### Step 4: Wire to UI

UI calls provider → provider updates state → UI rebuilds.

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

**`application/fsrs_service.dart`**
```dart
class FsrsService {
  final Scheduler _scheduler = Scheduler();

  /// Process a review and return updated card state
  FsrsResult processReview(Flashcard card, Rating rating) {
    // Convert our Flashcard to fsrs Card
    final fsrsCard = _toFsrsCard(card);

    // Get scheduling result
    final (:card updatedFsrsCard, :reviewLog) =
        _scheduler.reviewCard(fsrsCard, _toFsrsRating(rating));

    // Convert back to our Flashcard with updated state
    final updatedCard = _fromFsrsCard(card, updatedFsrsCard);

    // Optionally create review record for history
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

  Card _toFsrsCard(Flashcard card) {
    return Card(
      cardId: card.id,
      due: card.due,
      stability: card.stability,
      difficulty: card.difficulty,
      elapsedDays: card.elapsedDays,
      scheduledDays: card.scheduledDays,
      reps: card.reps,
      lapses: card.lapses,
      state: card.state,
      lastReview: card.lastReview,
    );
  }

  Flashcard _fromFsrsCard(Flashcard original, Card fsrsCard) {
    return original.copyWith(
      due: fsrsCard.due,
      stability: fsrsCard.stability,
      difficulty: fsrsCard.difficulty,
      elapsedDays: fsrsCard.elapsedDays,
      scheduledDays: fsrsCard.scheduledDays,
      reps: fsrsCard.reps,
      lapses: fsrsCard.lapses,
      state: fsrsCard.state,
      lastReview: fsrsCard.lastReview,
    );
  }
}
```

Then call `FsrsService.processReview()` from `StudySessionService.rateCard()` and persist the updated card.

---

## Data Models

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

For MVP, you can simplify to just `again` and `good` without values.

### Study Session (Runtime State)

```dart
class StudySession {
  final String deckId;
  final List<Flashcard> cards;      // Cards to review
  final int currentIndex;           // Current position
  final List<Review> completedReviews;  // Reviews this session (optional)
  final DateTime startedAt;

  bool get isComplete => currentIndex >= cards.length;
  Flashcard get currentCard => cards[currentIndex];
  int get remaining => cards.length - currentIndex;
}
```

Or for MVP with simpler tracking:

```dart
class StudySession {
  final String deckId;
  final List<Flashcard> cards;
  final Set<String> studiedIds;
  final int againCount;
  final int goodCount;
  final DateTime startedAt;

  bool get isComplete => studiedIds.length >= cards.length;
  Flashcard? get currentCard => /* first unstudied */;
  int get remaining => cards.length - studiedIds.length;
}
```

### Review Record (Optional)

Persisting reviews enables analytics and FSRS optimization but adds storage cost. **Skip for MVP.**

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

### SQLite Table (If Persisting Reviews)

```sql
CREATE TABLE reviews (
  id TEXT PRIMARY KEY,
  card_id TEXT NOT NULL,
  reviewed_at TEXT NOT NULL,
  rating INTEGER NOT NULL,
  scheduled_days INTEGER NOT NULL,
  elapsed_days INTEGER NOT NULL,
  state INTEGER NOT NULL,

  FOREIGN KEY (card_id) REFERENCES cards(id)
);

CREATE INDEX idx_reviews_card_id ON reviews(card_id);
CREATE INDEX idx_reviews_reviewed_at ON reviews(reviewed_at);
```

---

## Study Session Flow

### MVP Flow

```
1. User taps "Study" on a deck
          ↓
2. Fetch cards (MVP: all cards in deck, or filter by due <= now)
          ↓
3. If no cards → show "No cards to study" message
          ↓
4. Create StudySession with cards
          ↓
5. LOOP:
   a. Show current card (front side)
   b. User taps to flip → show back side
   c. User taps rating button (Again/Good)
   d. Mark card as studied, update session stats
   e. Advance to next card
   f. If more cards → repeat from (a)
          ↓
6. Show completion screen with stats (X reviewed, Y% good)
```

### Full Flow (With FSRS)

```
5. LOOP:
   ...
   c. User taps rating button (Again/Hard/Good/Easy)
   d. Process with FsrsService → get updated card scheduling
   e. Save updated card.due to database
   f. (Optional) Save review record to database
   ...
```

---

## Key Implementation Notes

### Fetching Cards

**MVP:** Just get all cards in deck.

```dart
Future<List<Flashcard>> getCardsForDeck(String deckId) async {
  return db.query('cards', where: 'deck_id = ? AND is_deleted = 0', whereArgs: [deckId]);
}
```

**With FSRS:** Filter by due date.

```dart
Future<List<Flashcard>> getDueCards(String deckId) async {
  final now = DateTime.now().toIso8601String();
  return db.query('cards', where: 'deck_id = ? AND due <= ? AND is_deleted = 0', whereArgs: [deckId, now]);
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

**MVP:** Just Again/Good.

```
[Again]     [Good]
```

**With FSRS:** Show expected intervals (FSRS can preview these before rating).

```
[Again]     [Hard]      [Good]      [Easy]
 <1 min      10 min      1 day       4 days
```

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

### External (MVP)
- `flutter_riverpod`

### External (Full)
- `flutter_riverpod`
- `fsrs: ^2.0.0` — **the FSRS algorithm package**
- `uuid`

---

## Testing Requirements

### Unit Tests — MVP
- [ ] `StudySessionService.startSession()` creates valid session
- [ ] `StudySessionService.rateCard()` marks card as studied
- [ ] `StudySession.currentCard` returns first unstudied card
- [ ] `StudySession.isComplete` returns true when all studied

### Unit Tests — FSRS (Critical)
- [ ] `FsrsService.processReview()` returns correct next interval
- [ ] New card → Good rating → ~1 day interval
- [ ] Review card → Again rating → relearning state
- [ ] Review card → Easy rating → longer interval
- [ ] Stability increases after successful reviews
- [ ] Difficulty adjusts based on ratings

### Integration Tests
- [ ] Complete study session updates all card states
- [ ] Review records are saved correctly (if persisting)
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

- [ ] Again/Good only, or full Again/Hard/Good/Easy?
- [ ] Persist review history for stats? (Cost vs benefit)
- [ ] Study across all decks vs one deck at a time?
- [ ] Show undo button after rating? (Anki has this)
- [ ] Audio for card flip?
- [ ] Haptic feedback on rating?
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
