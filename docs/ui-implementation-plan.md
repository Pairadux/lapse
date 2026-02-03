# Lapse MVP UI Implementation Plan

## Team Ownership

| Role | Owner | Scope |
|------|-------|-------|
| **UI + Wiring + PM** | Austin | Screens, widgets, routing, theme, wiring to providers |
| **Models** | Team Member 2 | Domain classes (Deck, Flashcard, User, etc.) |
| **Study Algorithm** | Team Member 3 | FSRS integration, scheduling logic |
| **State Management** | Team Member 2 + 4 | Riverpod providers, in-memory data stores |

## MVP Approach

**In-memory only** - No SQLite, no Supabase, no persistence. Just a working UI that demonstrates the card study flow.

---

## 1. Architecture Assessment

**Verdict: Architecture is appropriate.** Feature-first with clean architecture layers works well for team separation.

### What's Blocking You (Austin)

| Blocker | Owner | Priority | Notes |
|---------|-------|----------|-------|
| Domain models incomplete | Models owner | HIGH | Need constructors for UI to instantiate test data |
| Providers not defined | State mgmt team | MEDIUM | Can stub with mock data initially |
| Missing `CardState` enum | Models owner | HIGH | Referenced but undefined |

### What You Can Do Independently

- Theme setup (`app_colors.dart`, `app_theme.dart`)
- Routing setup (`routes.dart`, `app_router.dart`)
- All screen layouts (using placeholder/mock data)
- All widget components
- `main.dart` Riverpod + GoRouter bootstrap

---

## 2. Your Implementation Order

### Phase 1: Foundation (No Blockers)

**Files to create:**

1. `lib/core/theme/app_colors.dart` - Color constants
2. `lib/core/theme/app_theme.dart` - ThemeData configuration
3. `lib/core/routing/routes.dart` - Route path constants
4. `lib/core/routing/app_router.dart` - GoRouter configuration
5. `lib/main.dart` - ProviderScope + MaterialApp.router

### Phase 2: Shared Widgets (No Blockers)

**Files to create in `lib/core/widgets/`:**

1. `empty_state_widget.dart` - Reusable empty state component
2. `loading_indicator.dart` - Consistent loading spinner
3. `confirm_dialog.dart` - Delete confirmation dialog

### Phase 3: Decks UI (Mock Data Until Providers Ready)

**Files to create:**

1. `lib/features/decks/presentation/widgets/deck_card.dart` - Individual deck tile
2. `lib/features/decks/presentation/widgets/empty_deck_state.dart` - "Create your first deck"
3. `lib/features/decks/presentation/screens/deck_list_screen.dart` - Home screen
4. `lib/features/decks/presentation/screens/deck_form_screen.dart` - Create/edit deck

### Phase 4: Cards UI (Mock Data Until Providers Ready)

**Files to create:**

1. `lib/features/cards/presentation/widgets/card_list_item.dart` - Card in list
2. `lib/features/cards/presentation/widgets/empty_cards_state.dart` - "Add your first card"
3. `lib/features/cards/presentation/screens/card_list_screen.dart` - Cards in deck
4. `lib/features/cards/presentation/screens/card_editor_screen.dart` - Create/edit card

### Phase 5: Study UI (Mock Data Until Providers Ready)

**Files to create:**

1. `lib/features/study/presentation/widgets/study_card.dart` - Flippable flashcard
2. `lib/features/study/presentation/widgets/rating_buttons.dart` - 4 buttons (Again/Hard/Good/Easy)
3. `lib/features/study/presentation/widgets/session_progress.dart` - Progress indicator
4. `lib/features/study/presentation/screens/study_session_screen.dart` - Main study UI
5. `lib/features/study/presentation/screens/study_complete_screen.dart` - Session summary

### Phase 6: Wiring (After State Management Ready)

- Replace mock data with actual provider calls
- Connect form submissions to provider methods
- Handle loading/error states from async providers

---

## 3. Routes Configuration

| Path | Screen | Description |
|------|--------|-------------|
| `/` | DeckListScreen | Home - list all decks |
| `/deck/new` | DeckFormScreen | Create deck |
| `/deck/:deckId` | CardListScreen | Cards in deck |
| `/deck/:deckId/edit` | DeckFormScreen | Edit deck |
| `/deck/:deckId/card/new` | CardEditorScreen | Create card |
| `/deck/:deckId/card/:cardId` | CardEditorScreen | Edit card |
| `/deck/:deckId/study` | StudySessionScreen | Study session |

---

## 4. Mock Data Strategy

Until providers are ready, create a simple mock data file:

```dart
// lib/core/utils/mock_data.dart
final mockDecks = [
  Deck(id: '1', name: 'Spanish Vocab', cardCount: 25, dueCount: 5),
  Deck(id: '2', name: 'Biology Terms', cardCount: 40, dueCount: 12),
];

final mockCards = [
  Flashcard(id: '1', front: 'Hola', back: 'Hello'),
  Flashcard(id: '2', front: 'Gracias', back: 'Thank you'),
];
```

This lets you build and test all UI without waiting on other team members.

---

## 5. Coordination Points (PM Tasks)

### Needed from Models Owner

- [ ] Complete `Deck` model with constructor
- [ ] Complete `Flashcard` model with constructor + FSRS fields
- [ ] Add `CardState` enum (new, learning, review, relearning)
- [ ] Decide: Does Flashcard need `state` field or is it calculated?

### Needed from State Management Team

- [ ] `deckListProvider` - Returns `List<Deck>`
- [ ] `cardListProvider(deckId)` - Returns `List<Flashcard>` for a deck
- [ ] `dueCardsProvider(deckId)` - Returns due cards for study
- [ ] `studySessionProvider` - Manages current study session state
- [ ] CRUD methods: `createDeck()`, `updateDeck()`, `deleteDeck()`, etc.

### Needed from Study Algorithm Owner

- [ ] What does the rating callback signature look like?
- [ ] Does study session need to pass card + rating to a service?
- [ ] What data comes back after rating (next interval, etc.)?

---

## 6. Files Summary

**You create (~20 files):**
- 2 theme files
- 2 routing files
- 1 main.dart update
- 3 core widgets
- 4 deck UI files (2 widgets, 2 screens)
- 4 card UI files (2 widgets, 2 screens)
- 5 study UI files (3 widgets, 2 screens)
- 1 mock data file (temporary)

**Others create:**
- Domain models (models owner)
- Providers (state mgmt team)
- FSRS service (study algorithm owner)

---

## 7. Verification

Test the UI flow with mock data:

1. **Home screen** - Shows list of decks, FAB to create new
2. **Create deck** - Form with name field, save button
3. **Card list** - Shows cards in deck, FAB to add card, Study button
4. **Card editor** - Front/back text fields, save button
5. **Study session** - Shows card front, tap to flip, 4 rating buttons, progress bar
6. **Study complete** - Shows stats (cards reviewed, etc.)

---

## 8. Open Questions for Team

1. **In-memory data reset:** Does data persist between app restarts or reset each time?
2. **User concept:** Do we need a User model for MVP or skip entirely?
3. **Study session flow:** When no cards are due, what happens? Show message? Disable button?
4. **Deck deletion:** Soft delete or hard delete for in-memory MVP?
