# Cards Feature

## Metadata

| Field | Value |
|-------|-------|
| **Owner** | [TBD - assign at meeting] |
| **Status** | 🔴 Not Started |
| **Last Updated** | [DATE] |
| **Sprint** | Sprint 2-3 (implementation) |

## Overview

The Cards feature handles flashcard management within a deck—viewing, creating, editing, and deleting individual flashcards. Each card has a front (question) and back (answer).

---

## Architecture Note: Separation from Study

This feature is a **dumb data container**. It handles CRUD operations for cards but does NOT contain study logic.

| Belongs Here | Belongs in Study |
|--------------|------------------|
| `Flashcard` model | `Rating` enum |
| `CardState` enum | `StudySession` model |
| FSRS fields on card (storage) | FSRS scheduling logic |
| `CardRepository` CRUD | Session flow orchestration |

The card stores scheduling **state** (`due`, `stability`, `reps`). The study feature handles the scheduling **process** (rating, calculating next due date).

---

## User Stories

- As a user, I can see all cards in a specific deck
- As a user, I can create a new card with front and back content
- As a user, I can edit an existing card
- As a user, I can delete a card (with confirmation)
- As a user, I can search/filter cards within a deck
- As a user, I can preview a card (flip to see answer)

---

## Quick Reference

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| `data/` | Database operations | `card_repository.dart` |
| `domain/` | Data models | `flashcard.dart`, `card_state.dart` |
| `presentation/` | UI components | Screens, widgets, providers |

---

## Folder Structure

Keep `domain/` flat—no `models/` subfolder unless you have 5+ files.

```
cards/
├── data/
│   ├── card_repository.dart           # Abstract interface + implementation
│   ├── card_local_data_source.dart    # SQLite operations
│   └── card_remote_data_source.dart   # Supabase operations (Sprint 4)
│
├── domain/
│   ├── flashcard.dart                 # Card model (named to avoid Flutter's Card widget)
│   └── card_state.dart                # CardState enum (new, learning, review, relearning)
│
├── presentation/
│   ├── screens/
│   │   ├── card_list_screen.dart      # Shows all cards in a deck
│   │   └── card_editor_screen.dart    # Create/edit card form
│   │
│   ├── widgets/
│   │   ├── card_list_item.dart        # Individual card in list view
│   │   ├── card_preview.dart          # Flippable preview widget
│   │   ├── empty_cards_state.dart     # Shown when deck has no cards
│   │   └── card_search_bar.dart       # Search/filter input
│   │
│   └── providers/
│       ├── card_list_provider.dart    # Provides cards for a deck
│       ├── card_editor_provider.dart  # Manages form state
│       └── card_search_provider.dart  # Handles search/filter state
│
└── README.md
```

---

## Data Model

```dart
class Flashcard {
  final String id;           // UUID
  final String deckId;       // Parent deck
  final String front;        // Question/prompt side
  final String back;         // Answer side
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;      // Soft delete for sync
  
  // FSRS scheduling state (managed by Study feature)
  final DateTime due;        // When next review is due
  final double stability;    // Memory stability (higher = longer intervals)
  final double difficulty;   // Card difficulty (1-10)
  final int elapsedDays;     // Days since last review
  final int scheduledDays;   // Interval from last review
  final int reps;            // Total review count
  final int lapses;          // Times forgotten (rated "Again")
  final CardState state;     // New, Learning, Review, Relearning
  final DateTime? lastReview;
}

enum CardState { newCard, learning, review, relearning }
```

### SQLite Table

```sql
CREATE TABLE cards (
  id TEXT PRIMARY KEY,
  deck_id TEXT NOT NULL,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  
  -- FSRS fields (initialized with defaults for new cards)
  due TEXT NOT NULL,
  stability REAL NOT NULL DEFAULT 0,
  difficulty REAL NOT NULL DEFAULT 0,
  elapsed_days INTEGER NOT NULL DEFAULT 0,
  scheduled_days INTEGER NOT NULL DEFAULT 0,
  reps INTEGER NOT NULL DEFAULT 0,
  lapses INTEGER NOT NULL DEFAULT 0,
  state INTEGER NOT NULL DEFAULT 0,  -- 0=New, 1=Learning, 2=Review, 3=Relearning
  last_review TEXT,
  
  FOREIGN KEY (deck_id) REFERENCES decks(id)
);

CREATE INDEX idx_cards_deck_id ON cards(deck_id);
CREATE INDEX idx_cards_due ON cards(due) WHERE is_deleted = 0;
```

---

## Key Implementation Notes

### Card List Screen
- Receives `deckId` from route parameters
- Shows deck name in app bar
- List of cards with front text preview
- Tap card → edit (or preview with flip)
- FAB to create new card
- Search bar at top (optional, can collapse)

### Card Editor Screen
- Two text fields: front and back
- Both required, validate before save
- Save button in app bar
- Consider: character limit? Rich text? Images?

### FSRS Fields
- **This feature initializes FSRS fields, but doesn't calculate them**
- New cards get default values (due = now, stability = 0, etc.)
- The Study feature updates these fields after reviews
- Card repository needs `updateFsrsState()` method for Study to call

### Creating Cards
When creating a new card:
```dart
final newCard = Flashcard(
  id: uuid.v4(),
  deckId: deckId,
  front: frontText,
  back: backText,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  isDeleted: false,
  due: DateTime.now(),  // Due immediately (new card)
  stability: 0,
  difficulty: 0,
  elapsedDays: 0,
  scheduledDays: 0,
  reps: 0,
  lapses: 0,
  state: CardState.newCard,
  lastReview: null,
);
```

### Search/Filter
- Search front and back text
- Consider: filter by state (new, learning, due)
- Debounce search input (don't query on every keystroke)

### Updating Deck Counts
When cards are added/deleted, update parent deck's `cardCount`:
```dart
// After creating card:
deckRepository.incrementCardCount(deckId);

// After deleting card:
deckRepository.decrementCardCount(deckId);
```

---

## Interaction with Other Features

### → Decks Feature
- Cards belong to a deck (foreign key)
- Deleting a deck should cascade-delete its cards
- Card operations update deck's `cardCount`

### ← Study Feature
- Study reads cards via `CardRepository`
- Study writes updated FSRS state (`due`, `stability`, etc.) after reviews
- Card repository exposes `updateFsrsState(cardId, fsrsFields)` method
- **Rating enum lives in Study, not here** — it's a study-time action

### ← Auth Feature (Sprint 4)
- Cards sync via Auth's sync service
- `isDeleted` flag enables soft delete for sync

---

## Dependencies

### Internal
- `core/theme`, `core/routing`, `core/widgets`
- Reads from: `features/decks` (deck info for header)

### External
- `flutter_riverpod`
- `uuid`
- `drift` or `sqflite`

---

## Testing Requirements

### Unit Tests
- [ ] `CardRepository.getCardsForDeck()` returns correct cards
- [ ] `CardRepository.createCard()` inserts with correct defaults
- [ ] `CardRepository.updateCard()` modifies content fields
- [ ] `CardRepository.updateFsrsState()` modifies only FSRS fields
- [ ] `CardRepository.deleteCard()` soft-deletes
- [ ] Search filters cards correctly

### Widget Tests
- [ ] CardListItem shows front text
- [ ] CardEditorScreen validates required fields
- [ ] CardPreview flips between front/back

---

## Open Questions

- [ ] Rich text support (bold, italic)? Or plain text only for MVP?
- [ ] Image support on cards? (Stretch goal)
- [ ] Maximum card content length?
- [ ] Bulk card creation (import)?

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| [DATE] | Initial README created | Austin |
