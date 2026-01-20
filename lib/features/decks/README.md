# Decks Feature

## Metadata

| Field | Value |
|-------|-------|
| **Owner** | [TBD - assign at meeting] |
| **Status** | 🔴 Not Started |
| **Last Updated** | [DATE] |
| **Sprint** | Sprint 2-3 (implementation) |

## Overview

The Decks feature handles all deck management functionality—creating, editing, deleting, and listing flashcard decks. This is essentially the "home" of the app.

---

## User Stories

- As a user, I can see all my decks on the home screen
- As a user, I can create a new deck with a name and optional description
- As a user, I can edit a deck's name and description
- As a user, I can delete a deck (with confirmation)
- As a user, I can see how many cards are in each deck
- As a user, I can see how many cards are due for review in each deck

---

## Quick Reference

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| `data/` | Database operations | `deck_repository.dart`, `deck_local_data_source.dart` |
| `domain/` | Data models | `deck.dart` |
| `presentation/` | UI components | Screens, widgets, providers |

---

## Folder Structure

```
decks/
├── data/
│   ├── deck_repository.dart           # Abstract interface + implementation
│   ├── deck_local_data_source.dart    # SQLite operations
│   └── deck_remote_data_source.dart   # Supabase operations (Sprint 4)
│
├── domain/
│   └── deck.dart                      # Deck model class
│
├── presentation/
│   ├── screens/
│   │   ├── deck_list_screen.dart      # Home screen showing all decks
│   │   └── deck_form_screen.dart      # Create/edit deck form
│   │
│   ├── widgets/
│   │   ├── deck_card.dart             # Individual deck display card
│   │   ├── deck_list.dart             # List/grid of deck cards
│   │   ├── empty_deck_state.dart      # Shown when no decks exist
│   │   └── deck_stats_row.dart        # Card count, due count display
│   │
│   └── providers/
│       ├── deck_list_provider.dart    # Provides list of all decks
│       └── deck_form_provider.dart    # Manages form state for create/edit
│
└── README.md
```

---

## Data Model

```dart
class Deck {
  final String id;           // UUID, generated on creation
  final String userId;       // Owner of the deck
  final String name;         // Deck title (required)
  final String? description; // Optional description
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;      // Soft delete for sync
  
  // Denormalized counts (updated when cards change)
  final int cardCount;       // Total cards in deck
  final int dueCount;        // Cards due for review
}
```

### SQLite Table

```sql
CREATE TABLE decks (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  is_deleted INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE INDEX idx_decks_user_id ON decks(user_id);
```

---

## Key Implementation Notes

### Deck List Screen
- This is the app's home screen
- Use lazy loading if user has many decks (unlikely but good practice)
- Pull-to-refresh to reload from database
- FAB (floating action button) to create new deck
- Tap deck → navigate to card list (`/deck/:deckId`)
- Long press or swipe → delete option

### Card Counts
- `cardCount` and `dueCount` are denormalized for performance
- Don't query cards table every time you display a deck
- Update these counts when cards are added/deleted/reviewed
- Consider a database trigger or manual update in card repository

### Soft Delete
- When user deletes a deck, set `isDeleted = true`
- Filter queries with `WHERE is_deleted = 0`
- Cascade: also soft-delete all cards in the deck

---

## Dependencies

### Internal (within app)
- `core/theme` — for styling
- `core/routing` — for navigation
- `core/widgets` — for shared components

### External (packages)
- `flutter_riverpod` — state management
- `uuid` — generating deck IDs
- `drift` or `sqflite` — database operations

---

## Testing Requirements

### Unit Tests
- [ ] `DeckRepository.getAllDecks()` returns correct data
- [ ] `DeckRepository.createDeck()` inserts correctly
- [ ] `DeckRepository.updateDeck()` modifies correctly
- [ ] `DeckRepository.deleteDeck()` soft-deletes correctly
- [ ] Deck model serialization/deserialization

### Widget Tests
- [ ] DeckCard displays name and counts correctly
- [ ] DeckListScreen shows empty state when no decks
- [ ] DeckFormScreen validates required fields

---

## Open Questions

- [ ] Should decks have colors/icons for visual distinction?
- [ ] Maximum deck name length?
- [ ] Can decks be reordered manually, or always alphabetical/by date?

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| [DATE] | Initial README created | Austin |
