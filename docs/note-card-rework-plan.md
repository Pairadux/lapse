# Plan: Rework Flashcards into a Note/Card System (foundation + parity)

## Context

Today's `Flashcard` model (`lib/features/cards/domain/flashcard.dart`) conflates two distinct concepts: user-authored content (`front`, `back`) and the FSRS review unit (scheduling state, lapses, state machine). That's fine for plain front→back cards but structurally awkward for any "one edit produces multiple reviews" workflow (reverse, cloze). Issue #149 ("card templates") identified this; prior attempts are judged inadequate.

This plan supersedes them with a proper Anki-style split:

- **Note** — what the user authors. Has `note_type`, `fields` (type-specific content), no FSRS.
- **Card** — what FSRS schedules. Deterministically generated from `(Note, template_ordinal)`. Holds all scheduling state.

## Scope split

This plan is executed in two phases by two people. **Scope discipline: anything that can be deferred to a future issue is deferred.** The goal is parity, not feature creep.

**Our scope (this plan, Austin + Claude): foundation + parity.**
Rewrite domain + storage + repos + UI + sync + CSV so the app reaches functional parity with today — Basic front→back cards only — on top of the new Note/Card model with the full extensibility architecture (`NoteTypeRegistry`) in place. At the end of our work, the app looks and behaves identically to today's main branch, except the underlying data model is the new one, and `NoteTypeRegistry` is registered with exactly one `NoteTypeSpec` (Basic).

**Germaine's scope (handoff PR/branch): the new card types on top of our foundation.**
Implement `ReverseNoteType` and `ClozeNoteType`, `ClozeParser`, `ClozeEditor`, `FlipCard.oneSided` reveal mode, type selector, note-type switching UI, and cloze CSV column. See the "Handoff to @GADudley" section for entry points and decisions already made.

**Attribution — every commit on this branch:** This rework supersedes prior card-template work originated by @GADudley (issue #149). Every commit and the final PR description include a `Co-authored-by` trailer:

```
Co-authored-by: Germaine Dudley <115107626+GADudley@users.noreply.github.com>
```

Apply with `git commit -m "<subject>" -m "" -m "Co-authored-by: Germaine Dudley <115107626+GADudley@users.noreply.github.com>"`. The trailer must be preceded by a blank line to be recognized by GitHub.

---

## Strategy: gut-and-rebuild on a single long-lived branch

Solo-developer project with no external users yet → `git` is the sandbox. One long-lived feature branch (`feat/note-card-rework`), commits ordered so each checkpoint compiles, old model gets orphaned and deleted in a single commit near the end. No parallel "sandbox" world inside the codebase, no dev-drawer alternate routes, no `NoteV2`/`ReviewCard` disambiguating names.

**Name collision avoidance:** old model keeps its existing name `Flashcard`; new model is named `Card` + `Note`. They never coexist with the same name — when `Flashcard` is deleted, `Card` is already the canonical name.

**User-facing terminology:** UI text stays as "Card" for parity with today (e.g. "New Card" button, "Delete card?" dialog). The Note/Card distinction is internal. Germaine can choose to surface "Note" vs "Card" in the UI when he adds multi-card types where the distinction becomes meaningful to users.

**Local-data decision (confirmed):** wipe at cutover. No conversion migration needed. Dev/test data is disposable.

---

## Architecture

### Core abstraction (extension point) — our scope

```dart
abstract class NoteTypeSpec {
  String get key;                              // 'basic' now; 'reverse' | 'cloze' later
  String get displayName;                      // 'Basic', 'Reverse', 'Cloze' (UI label)
  List<FieldSpec> get fields;                  // ordered field schema
  String get sortFieldName;                    // which field is the "sort field" (first field by default)

  List<CardBlueprint> generateCards(Note n);   // deterministic; ordinal + kind
  CardView render(Note n, int ordinal);        // { question, answer, oneSided }
  String cardLabel(Note n, Card c);            // browser subtitle: 'Basic', 'Reverse 2/2', 'Cloze 2/3'
  String? validate(Note n);                    // editor-time validation; null = ok
  Widget editor(NoteEditController c);         // type-specific editor widget
}

class FieldSpec {
  final String name;        // stable key ('front', 'back', 'text')
  final String label;       // UI label
  final bool multiline;
  final int? maxLength;     // client-side length cap
  const FieldSpec({required this.name, required this.label, this.multiline = false, this.maxLength});
}

class CardBlueprint {
  final int ordinal;
  final String kind;        // categorical: 'forward' | 'reverse' | 'cloze'
  const CardBlueprint({required this.ordinal, required this.kind});
}

class CardView {
  final String question;    // markdown
  final String answer;      // markdown
  final bool oneSided;      // true for cloze; suppresses 3D flip, triggers reveal animation
  const CardView({required this.question, required this.answer, this.oneSided = false});
}
```

`NoteTypeRegistry` — `Map<String, NoteTypeSpec>`. Registered at app startup in `main.dart`. **We register one entry: `BasicNoteType`.** Germaine adds `ReverseNoteType` and `ClozeNoteType` by writing two more `NoteTypeSpec` implementations and adding them to the registry — no other architectural changes required.

Every UI, storage, and sync dispatch goes through this registry, so Germaine's work is purely additive.

### `cardKind` naming convention (lock this in now)

`cardKind` is categorical, not numeric — the ordinal carries the index. Canonical values:

| Type | ordinal 0 | ordinal 1 | ordinal 2… |
|---|---|---|---|
| Basic | `'forward'` | — | — |
| Reverse | `'forward'` | `'reverse'` | — |
| Cloze | `'cloze'` (ord 1) | `'cloze'` (ord 2) | `'cloze'` (ord N) |

Cloze uses the ordinal to identify which cloze index (ord N = `{{cN::...}}`), with `kind = 'cloze'` for all. This matches Anki's internal model and makes the FSRS-preservation algorithm below work correctly.

Future types pick new categorical values (`'image-occlusion'`, `'audio-q'`, etc.). Keep `cardKind` an unconstrained `TEXT` so new types don't need a schema migration.

### Domain models (new) — our scope

- **`Note`** (`lib/features/cards/domain/note.dart`): `noteId, deckId, noteType, fields: Map<String,String>, createdAt, updatedAt, isDeleted, userId, syncStatus`
- **`Card`** (`lib/features/cards/domain/card.dart`): `cardId, noteId, templateOrdinal, cardKind (String; see convention above), ...all existing FSRS fields..., createdAt, updatedAt, isDeleted, userId, syncStatus`

`fields` is `Map<String,String>` serialized as JSON (SQLite `TEXT`, Supabase `jsonb`) so new note types don't require schema migrations.

Tags are deliberately **not** part of 1.0 — filed as a future issue to avoid feature-creeping this branch. Adding them later is a single additive column migration (`notes.tags_json TEXT NOT NULL DEFAULT '[]'`).

### Pure functions — our scope

- `List<CardBlueprint> generateCards(Note)` — dispatches through registry. `BasicNoteType.generateCards` returns `[CardBlueprint(ordinal: 0, kind: 'forward')]`.
- `CardView render(Note, Card)` — dispatches through registry. `BasicNoteType.render` returns `{ question: fields['front'], answer: fields['back'], oneSided: false }`.
- `String cardLabel(Note, Card)` — for browser/list display. `BasicNoteType.cardLabel` returns `'Basic'`.
- `String sortFieldValue(Note)` — helper on NoteTypeSpec. For Basic: `note.fields['front'] ?? ''`. Used for duplicate detection and browser sorting.

**Not our scope:** `ClozeParser`, `ReverseNoteType`, `ClozeNoteType`. No skeleton files — Germaine creates them fresh.

### Service layer — `NoteService` — our scope

Single entry point for note upserts and deletes. All operations atomic.

**`upsertNote(Note note)`:**
1. Validate via `NoteTypeRegistry[note.noteType].validate(note)` — abort on error.
2. Upsert the note row.
3. `newBlueprints = generateCards(note)`.
4. Load existing non-deleted cards for this note, index by `(ordinal, kind)`.
5. For each new blueprint `(ord, kind)`:
   - If `(ord, kind)` exists in old set → **preserve the card** (FSRS intact), just re-touch `updated_at`.
   - Else → insert a new card with fresh FSRS.
6. For each old card whose `(ord, kind)` is not in the new blueprint set → soft-delete it (`is_deleted=1`, `sync_status='pending'`).
7. All in one SQLite transaction.

Why `(ordinal, kind)` pair and not just ordinal: ensures Basic→Reverse preserves FSRS for `(0, 'forward')` but Basic→Cloze doesn't (no `(0, 'forward')` in cloze's output). This is the correct Anki-like behavior.

**`deleteNote(String noteId)`:** Single transaction — soft-delete the note and all its non-deleted cards; both rows get `sync_status='pending'` so tombstones push on next sync cycle.

**`upsertNote` is type-agnostic.** When Germaine adds Reverse, `generateCards` starts returning two blueprints and the diff handles it with no service-level changes.

---

## Cloze spec (handoff reference — Germaine implements)

Decisions already made so he doesn't have to re-litigate:
- **Hint syntax**: `{{c1::answer::hint}}` — blanked-out span shows hint in greyed italic until reveal.
- **Multi-span same index**: all `{{c1::...}}` spans in a note reveal together as one card.
- **Note-type switching**: allowed post-creation. The `NoteService.upsertNote` diff preserves FSRS where `(ordinal, kind)` pairs overlap and resets it where they don't — so e.g., Basic→Reverse preserves the forward card's FSRS and only ord 1 (reverse) starts fresh. Confirmation dialog warns "This will reset FSRS progress for N cards" where N is the count that's actually losing progress (not all cards).
- **Cloze text passes through markdown AFTER cloze parsing** (cloze first, then render each resulting segment as markdown).

---

## Storage — our scope

No real users exist, so instead of "bump the schema version and add another migration on top," we **reset the baseline**: the new schema becomes v1 on both sides. Leaves the codebase reading as "here's the schema, period" — no migration archaeology.

### SQLite — reset to v1

Change in `lib/core/database/database_helper.dart`:
- `databaseVersion = 1` (was 5).
- `openDatabase` config gains `onDowngrade: onDatabaseDowngradeDelete` — sqflite built-in that automatically wipes and recreates any existing dev DB whose on-disk version (e.g. 5) exceeds the code's declared version (1). Contributors checking out the branch get an auto-reset DB with no manual step.
- Delete `_migrateV2`, `_migrateV3`, `_migrateV4`, `_migrateV5` methods (~100 lines gone).
- `_onUpgrade` stub remains for future migrations.
- `createStatements` in `DatabaseConstants` replaced with the new v1 baseline below.
- `purgeTombstones` (currently at `database_helper.dart:210-251`) extended to also purge notes where `is_deleted=1 AND updated_at < 7d ago AND (sync_status='synced' OR user_id='')`, with the same "don't purge a note whose cards have pending tombstones" guard.

New schema (as v1 `createStatements`):

```sql
CREATE TABLE decks (
  -- unchanged from current v1/v5
);

CREATE TABLE notes (
  note_id     TEXT PRIMARY KEY,
  deck_id     TEXT NOT NULL REFERENCES decks(deck_id) ON DELETE CASCADE,
  note_type   TEXT NOT NULL,
  fields_json TEXT NOT NULL,
  created_at  TEXT NOT NULL,
  updated_at  TEXT NOT NULL,
  is_deleted  INTEGER NOT NULL DEFAULT 0,
  user_id     TEXT NOT NULL,
  sync_status TEXT NOT NULL DEFAULT 'synced'
);

CREATE TABLE cards (
  card_id           TEXT PRIMARY KEY,
  note_id           TEXT NOT NULL REFERENCES notes(note_id) ON DELETE CASCADE,
  template_ordinal  INTEGER NOT NULL,
  card_kind         TEXT NOT NULL,
  -- all existing FSRS fields preserved (due_date, stability, difficulty,
  -- elapsed_days, scheduled_days, reps, lapses, last_review,
  -- card_state, step, created_at, updated_at, is_deleted,
  -- user_id, sync_status)
);

CREATE TABLE reviews (
  -- unchanged from current v5 (UUID PK, FK to cards)
);

CREATE TABLE review_session_summary (
  -- unchanged from current v5
);

CREATE UNIQUE INDEX idx_cards_note_ordinal_kind
  ON cards(note_id, template_ordinal, card_kind)
  WHERE is_deleted = 0;
-- plus: idx_notes_deck_id, idx_notes_user_updated, idx_notes_sync_status,
--       idx_cards_note_id, idx_cards_due_date, all sync_status partial
--       indexes, session-summary indexes (all as they exist today)
```

`idx_cards_note_ordinal_kind` includes `card_kind` so the uniqueness constraint maps to the diff algorithm's pairing. Remove `idx_cards_deck_due` — cards no longer have `deck_id` directly; deck queries route through `notes` via join. Add `idx_notes_deck_type` on `(deck_id, note_type)` for duplicate-detection lookups.

### Supabase — rewrite the initial migration in place

Single-source-of-truth approach: **rewrite `supabase/migrations/20260314160644_create_schema.sql`** to contain the full new schema and everything currently patched on top of it. Then `npx supabase db reset` locally to apply the rewritten baseline; push to prod (one-time hard reset, confirmed OK).

Fold the following existing patch migrations *into* the rewritten init file:
- `20260320000000_rate_limits_and_config.sql` — rewrite `enforce_row_limit` triggers to reference `notes` (new) and the new `cards` shape. Include `app_config` table.
- `20260320100000_fix_function_search_path.sql` — define all functions with `SET search_path = public, pg_temp` from the start.
- `20260320110000_fix_decks_rls_recursion.sql` — apply the correct decks RLS from the start.
- `20260323000000_realtime_sync_broadcast.sql` + `20260323010000_realtime_channel_authorization.sql` — realtime setup applied from the start.
- **Delete** all five patch files after folding.

Keep as separate migrations (values that legitimately change):
- `20260324204228_bump_min_app_version.sql` — standalone. Bumped in commit 8.

Rewritten init migration contents:
- `CREATE TABLE public.decks` (unchanged from today).
- `CREATE TABLE public.notes` — RLS `TO authenticated`, `(select auth.uid())` subquery pattern (per `CLAUDE.md`). `fields_json` stored as `jsonb`.
- `CREATE TABLE public.cards` — new shape, FK to `notes`, RLS via `EXISTS` check on `notes.user_id`.
- `CREATE TABLE public.reviews` — unchanged shape, FK to new cards.
- `CREATE TABLE public.review_session_summary` (unchanged).
- `CREATE TABLE public.app_config` (folded from rate_limits migration).
- `updated_at` triggers on `decks`, `notes`, `cards`, `review_session_summary` (not reviews — immutable).
- Row-count limit triggers: decks 100, notes **2,000/user**, cards 10K, reviews 10K (total), session_summaries 5K (total).
- Payload CHECK on notes: `octet_length(fields_json::text) <= 8192`. Drop front/back size checks (columns gone).
- `REVOKE ALL` → explicit `GRANT SELECT, INSERT, UPDATE` on all tables.
- All RLS-required indexes (`idx_cards_user_id`, `idx_notes_user_id`, `idx_notes_deck_type`, etc.).
- Realtime publication + channel authorization setup.
- All functions use `SET search_path = public, pg_temp`.

**Filename stays the same** (`20260314160644_create_schema.sql`). This preserves the `supabase_migrations` tracking-table slot for the initial migration — `db reset` logs the freshly-applied file under its original timestamp.

---

## UI changes — our scope

### `CardFormScreen` becomes `NoteFormScreen`

Same route (`/decks/:deckId/cards/new`, `/cards/:cardId`), file renamed from `card_form_screen.dart` → `note_form_screen.dart`. Rewritten:

- **Hardcodes `noteType = 'basic'`** on create. No type selector in our scope.
- Editor is the existing front/back TextFields UX, lifted into `BasicEditor` widget (`lib/features/cards/presentation/widgets/basic_editor.dart`). Dispatch goes through `NoteTypeRegistry[note.noteType].editor(controller)` — the screen itself is type-agnostic.
- Preview pane unchanged conceptually (renders markdown). Uses `NoteTypeSpec.render` so it's generic.
- Save path calls `NoteService.upsertNote(note)` instead of `CardRepository.create/update`.
- **Duplicate detection**: replaces today's `frontExistsInDeck` (`card_repository.dart:123-148`) with `NoteRepository.sortFieldExistsInDeck(deckId, value, noteType, excludeNoteId)` — uses `NoteTypeSpec.sortFieldValue(note)` as the check key. For Basic this is the `front` field (identical behavior to today). Confirmation dialog unchanged.
- Delete path calls `NoteService.deleteNote(noteId)` (handles cascade).
- User-facing text stays "New Card" / "Edit Card" / "Delete card?".
- Keep existing keyboard shortcuts (Alt+Enter, Shift+Enter) and preview toggle.

**Germaine adds later:** type selector dropdown, `ReverseEditor` and `ClozeEditor` widgets, note-type-change confirmation dialog.

### `StudySessionScreen` rewritten

- Unit of iteration becomes `(Card, Note)` pair instead of `Flashcard`.
- `StudySession` and `StudySessionService` (`lib/features/study/application/study_session_service.dart:7-116`) signatures updated accordingly.
- Card rendering uses existing `FlipCard` 3D flip + `SwipeableCard` — **no behavioral change** for Basic cards. `FlipCard` receives a `CardView` (obtained via `NoteTypeSpec.render(note, card)`) and uses its `question`/`answer`. For Basic, `oneSided=false` and behavior is identical to today.
- Rating logic, haptics, keyboard shortcuts identical to today.

**Germaine adds later:** `FlipCard.oneSided` mode + reveal animation for cloze (when `CardView.oneSided == true`).

### Card browser rewritten

- Reads from `NoteRepository` + `CardRepository` jointly. Each row represents a `Card`. Consider a `CardWithNote` combined value object for cleaner provider types.
- Row display: rendered question via `NoteTypeSpec.render` (for Basic: `front`) + deck breadcrumb. For Basic this is visually identical to today.
- Subtitle: `NoteTypeSpec.cardLabel(note, card)` — for Basic returns `'Basic'`. Leaves room for Germaine's "Reverse 2/2" / "Cloze 2/3".
- Tap → opens parent note in `NoteFormScreen`.
- Search hits `notes.fields_json` via `LIKE '%…%'`; swap-in for today's front/back search. Uses `json_extract` for sort-field-specific queries when needed.

### Deck Detail

No structural change — counts stay card-level. "+ Card" FAB routes to `NoteFormScreen` (which creates a Basic note).

---

## Repositories + providers — our scope

- `NoteRepository` (new, `lib/features/cards/data/note_repository.dart`) — CRUD over `notes`. Mirrors `card_repository.dart:15-209` patterns (userId stamping, `sync_status='pending'` on writes, soft-delete, `markSynced` TOCTOU guard). Adds `sortFieldExistsInDeck(deckId, value, noteType, excludeNoteId)` for duplicate detection.
- `CardRepository` (rewritten) — CRUD over `cards` new-shape table. Old one renamed to `FlashcardRepository` at the start of the storage commit to free the name; deleted at the orphan step.
- `NoteService` (new, `lib/features/cards/data/note_service.dart`) — atomic `upsertNote` / `deleteNote` (described above). Called by `NoteFormScreen`.
- Riverpod providers in `lib/features/cards/presentation/providers/` — `card_list_provider.dart` rewritten to return `CardWithNote` instead of `Flashcard`.

---

## Sync — our scope

Because the app must reach parity, sync is part of our work. Changes:
- `lib/core/sync/sync_adapter.dart:14-52` — add `toSupabaseRow` / `fromSupabaseRow` for `Note` (serializes `fields_json`, `tags_json` as `jsonb`). Update `Card` adapter: include `note_id`, `template_ordinal`, `card_kind`; drop `front`/`back`/`deck_id`.
- `lib/core/sync/sync_push_service.dart:65-195` — push order: decks → **notes → cards** → reviews → session_summaries.
- `lib/core/sync/sync_pull_service.dart:54-288` — pull order same. Notes table joins the `last_pull_timestamp` cursor dance.
- `lib/core/sync/sync_realtime_service.dart` — subscribe to `notes` Postgres changes alongside existing tables.
- `SyncService.pause()`/`resume()` unaffected.

---

## CSV import/export — our scope

Today's export format (`deck_path,front,back`) is basic-only. Parity requires CSV to work; we stay minimal:
- Export columns: `deck_path,note_type,front,back`.
- Import: constructs a Basic `Note` from each row (`note_type='basic'`); then `NoteService.upsertNote` handles card generation.
- Works end-to-end for Basic — Germaine adds `cloze_text` column for cloze support.

---

## Testing — our scope

- **Unit (`NoteService.upsertNote` diff)**: preserves card when `(ordinal, kind)` pair matches existing; creates new card for new pairs; soft-deletes stale pairs. Currently only one ordinal per note type, but the logic is tested in isolation.
- **Unit (`NoteService.deleteNote`)**: cascades soft-delete to all cards atomically; both marked `sync_status='pending'`.
- **Unit (`NoteTypeSpec`) for Basic**: `generateCards` returns `[(0, 'forward')]`; `render` returns `{ question, answer, oneSided: false }`; `cardLabel` returns `'Basic'`; `sortFieldValue` returns `front`; `validate` rejects empty front/back.
- **Repo tests**: note CRUD, card FK integrity, `sortFieldExistsInDeck` with and without `excludeNoteId`.
- **Tombstone purge tests**: notes with pending cards NOT purged; synced-and-stale notes purged; cascade purge when parent deck purged.
- **Integration**: sync round-trip of notes + derived cards; no card orphans after edit-then-sync.

---

## Commit sequence (single branch, each commit compiles)

Branch: `feat/note-card-rework`. Every commit carries the `Co-authored-by: Germaine Dudley <...>` trailer.

1. **Add new domain models** — `Note`, `Card` (new shape), `CardBlueprint`, `CardView`, `FieldSpec`, `NoteTypeSpec` interface, empty `NoteTypeRegistry`. Existing `Flashcard` untouched. Nothing references the new models yet. ✅ compiles.
2. **Register `BasicNoteType` + pure-function plumbing** — `BasicNoteType` class (all methods implemented), registry wiring in `main.dart`. Unit tests for `BasicNoteType.generateCards`/`render`/`cardLabel`/`sortFieldValue`/`validate`. ✅ compiles + tests pass.
3. **SQLite v1 reset + new repos** — `NoteRepository` (including `sortFieldExistsInDeck`), new-shape `CardRepository`. Rename existing `CardRepository` → `FlashcardRepository` (all call sites updated). Overwrite `DatabaseConstants.createStatements` with the new v1 baseline; set `databaseVersion = 1`; add `onDowngrade: onDatabaseDowngradeDelete`; delete `_migrateV2`..`_migrateV5`; extend `purgeTombstones` to include notes. `NoteService` with `upsertNote` + `deleteNote` transactions. Zombie `Flashcard` + `FlashcardRepository` compile but have no backing tables. ✅ compiles, study/form/browser broken at runtime (expected).
4. **Rewrite `NoteFormScreen`** backed by `NoteService`; extract `BasicEditor` widget; wire `sortFieldExistsInDeck` for duplicate detection. Route wiring updated. Card form works again for Basic. ✅ compiles + form testable end-to-end.
5. **Rewrite `StudySessionScreen`** to iterate `(Card, Note)` pairs using `CardView`; update `StudySessionService`. No `FlipCard` behavior change. Study works again for Basic. ✅ compiles + full study flow runnable.
6. **Rewrite card browser** — queries via `NoteRepository` + `CardRepository`; subtitle uses `NoteTypeSpec.cardLabel`. Browser works again. ✅ compiles + full app functional again (parity).
7. **Delete orphans** — remove `Flashcard`, `FlashcardRepository`, now-unused helpers. ✅ compiles, clean codebase.
8. **Sync rewrite** — Rewrite `20260314160644_create_schema.sql` in place; delete five folded-in patch migration files; `npx supabase db reset`; adapter/push/pull/realtime updates for notes+cards new shape. Bump `min_app_version` as its own separate migration. ✅ parity with today's sync.
9. **CSV rewrite** — import/export for Basic (`deck_path,note_type,front,back`). ✅ parity with today's CSV.

Commits 1–9 are a single PR merged to main when green.

---

## Schema extensibility notes

What the design supports natively (no schema changes needed):
- **Any new note type** — implement `NoteTypeSpec`, register in `main.dart`. Generate zero, one, or many cards per note; custom editor; custom validation; custom rendering.
- **Multi-card notes** with arbitrary cardinality — `generateCards` returns a list.
- **One-sided cards** (cloze-style reveal) via `CardView.oneSided`.
- **Arbitrary `fields`** — stored as JSON; no schema columns per field.
- **FSRS preservation across type changes** — `(ordinal, kind)` diff algorithm handles it.

What's deliberately **not** supported (deferred until someone needs it):

| Feature | Why deferred | How to add later |
|---|---|---|
| **Tags on notes** (Anki-style, for organization beyond deck hierarchy) | Not needed for 1.0 parity; file as its own feature issue | Single additive column migration (`notes.tags_json TEXT NOT NULL DEFAULT '[]'`) + UI |
| User-editable templates (Anki-style `qfmt`/`afmt`) | Niche; requires a template engine | Add a `user_note_types` table; special `NoteTypeSpec` impl that loads templates from DB |
| Per-note-type CSS | We use Flutter theme, not per-card styling | Add `style_json` to note type registry |
| Separate media table (images/audio as blobs) | No current card type needs it; markdown references can embed URLs | Add `media` table with `note_id` FK; no change to notes |
| Note `guid` for cross-collection sync | Our UUIDs are already globally unique and stable | N/A — not needed |
| Rich-text HTML content | Markdown is sufficient for all planned types | Change `MarkdownBody` → rich-text widget |
| Conditional template rendering (`{{#Field}}…{{/Field}}`) | Only needed for data-driven templates | Would come with user-editable templates |
| Per-field config (sticky/RTL/font/size) | YAGNI; Flutter form UX suffices | Extend `FieldSpec` |
| Note-type schema versioning (migrate old notes when fields change) | We control all types in code; changing a type is a one-shot migration | Add `note_type_version INTEGER` column + per-type migrator |
| `data_json` blob on cards for pluggable schedulers | We only use FSRS | Add `scheduler_data_json TEXT` column |
| Siblings-bury (don't show sibling cards same day) | Basic has no siblings; only matters for Reverse/Cloze | Study-flow logic in Germaine's scope |
| Filtered decks (Anki dynamic decks) | Not a current Lapse feature | Orthogonal — doesn't touch notes/cards |

None of these deferrals create a corner we'd have to back out of — every one is additive.

---

## Critical files

**Read-only references (existing patterns to mirror):**
- `lib/features/cards/domain/flashcard.dart:1-201` — domain shape, sync metadata, FSRS fields
- `lib/features/cards/data/card_repository.dart:15-209` — repository pattern, userId stamping, `markSynced` TOCTOU guard, `frontExistsInDeck`
- `lib/core/database/database_helper.dart:76-251` — migration pattern, `purgeTombstones` routine
- `lib/core/database/database_constants.dart:2-227` — constants-only pattern
- `lib/features/study/application/fsrs_service.dart:14-115` — stateless FSRS integration (unchanged by us)
- `lib/features/study/application/study_session_service.dart:7-116` — session orchestration
- `lib/features/study/presentation/widgets/flip_card.dart:15-103` — 3D flip animation (unchanged by us; Germaine extends)
- `lib/features/study/presentation/widgets/swipeable_card.dart:15-100` — swipe gating on `enabled`
- `lib/features/cards/presentation/screens/card_form_screen.dart:1-489` — editor UX, preview, shortcuts, duplicate dialog
- `lib/core/sync/sync_adapter.dart:14-52` — serialization pattern
- `lib/core/sync/sync_push_service.dart:65-195` — push ordering
- `lib/core/sync/sync_pull_service.dart:54-288` — timestamp-delta pull
- `supabase/migrations/20260314160644_create_schema.sql` — RLS/privilege patterns (rewritten in commit 8)
- `supabase/migrations/20260320000000_rate_limits_and_config.sql:12-71` — `enforce_row_limit` trigger (folded into init in commit 8)

**New files created during commits 1–3:**
- `lib/features/cards/domain/note.dart`, `card.dart` (new), `note_type.dart` (interface + registry), `basic_note_type.dart`, `card_blueprint.dart`, `card_view.dart`, `field_spec.dart`
- `lib/features/cards/data/note_repository.dart`, `card_repository.dart` (new, after old renamed to `flashcard_repository.dart`), `note_service.dart` + provider files
- Test files under `test/features/cards/`

**Files rewritten in commits 4–6:**
- `lib/features/cards/presentation/screens/card_form_screen.dart` → `note_form_screen.dart`
- `lib/features/cards/presentation/widgets/basic_editor.dart` (new)
- `lib/features/study/presentation/screens/study_session_screen.dart`
- `lib/features/cards/presentation/providers/card_list_provider.dart`
- Card browser screen + provider files

**Files deleted at commit 7:**
- `lib/features/cards/domain/flashcard.dart`
- `lib/features/cards/data/flashcard_repository.dart` (the renamed old one)
- Any now-unused helpers

**Files modified across commits 3 & 8–9:**
- `lib/core/database/database_constants.dart` — `databaseVersion = 1`, new `createStatements`, remove old card column constants, add note column constants (commit 3)
- `lib/core/database/database_helper.dart` — add `onDowngrade: onDatabaseDowngradeDelete`, delete `_migrateV2`..`_migrateV5`, extend `purgeTombstones` to include notes (commit 3)
- `lib/core/sync/*` (commit 8)
- `supabase/migrations/20260314160644_create_schema.sql` — rewritten in place (commit 8)
- **Deleted in commit 8**: `supabase/migrations/20260320000000_rate_limits_and_config.sql`, `20260320100000_fix_function_search_path.sql`, `20260320110000_fix_decks_rls_recursion.sql`, `20260323000000_realtime_sync_broadcast.sql`, `20260323010000_realtime_channel_authorization.sql` — all folded into the init file
- `supabase/migrations/20260324204228_bump_min_app_version.sql` — kept; bumped in commit 8
- CSV import/export files (commit 9)

---

## Verification — parity, not new features

**Per-commit sanity (commits 1–7):**
- `flutter analyze` clean after each commit.
- `flutter test` — new unit tests pass from commit 2 onward; tests tied to `Flashcard` are updated or removed within the commit that makes them stale.
- Manual: after commit 4 the form is testable end-to-end; after commit 5 full study flow works; after commit 6 the app is fully functional again on the new model.

**End-to-branch (before merge):**
- Fresh install: launch app, create Basic cards, study them, confirm FSRS advances.
- Upgrade path (your own dev environment): install current main build with data, install the branch build, confirm `onDatabaseDowngradeDelete` transparently wipes the v5 on-disk DB and recreates it fresh at v1 (everything gone — matches wipe decision).
- Duplicate detection: try to create a second note with the same front text in the same deck → confirmation dialog appears just as today.
- Smoke-test every production route (deck list, deck detail, note form, study, card browser) — behavior indistinguishable from today for Basic cards.
- Sync round-trip: sign in, create a card, confirm push succeeds; on second device, pull, confirm it appears.
- CSV round-trip: export deck, wipe local data, import, confirm cards return with correct content.

The bar is **parity**: a user who didn't know about the refactor should see no behavioral difference.

---

## Handoff to @GADudley

At this point main is on the new Note/Card model, with Basic as the only registered note type. Full parity with pre-refactor behavior. Everything below is yours to build on top of that foundation.

### What you're adding

1. **`ReverseNoteType`** (`lib/features/cards/domain/reverse_note_type.dart`)
   - `fields`: `front`, `back` (same as Basic).
   - `generateCards`: returns two blueprints — `CardBlueprint(0, 'forward')` and `CardBlueprint(1, 'reverse')`.
   - `render`: `ordinal 0` returns `{ question: front, answer: back }`; `ordinal 1` returns `{ question: back, answer: front }`. Both `oneSided: false`.
   - `cardLabel`: `'Reverse (1/2)'` for ord 0, `'Reverse (2/2)'` for ord 1.
   - `sortFieldValue`: same as Basic — returns `front`.
   - Editor widget: same as `BasicEditor` with a subtitle "Generates 2 cards".
   - Register in `NoteTypeRegistry` (one-liner in `main.dart`).
   - **Basic → Reverse preserves the forward card's FSRS** — `(0, 'forward')` overlaps. Only ord 1 starts fresh.

2. **`ClozeParser`** (`lib/features/cards/domain/cloze_parser.dart`)
   - Parses `{{cN::answer}}` and `{{cN::answer::hint}}` syntax.
   - Returns `List<ClozeSpan(index, answer, hint?, startOffset, endOffset)>`.
   - Multi-span same index: `{{c1::a}}{{c1::b}}` → two spans both at index 1, rendered together in one card.
   - Rejects nested cloze `{{c1::{{c2::...}}}}` — validation error.
   - Heavy unit tests: all valid syntax permutations, malformed input, edge cases.

3. **`ClozeNoteType`** (`lib/features/cards/domain/cloze_note_type.dart`)
   - `fields`: single `text` multiline field.
   - `generateCards`: parse `text`, return one blueprint per distinct cloze index. `kind: 'cloze'`, ordinal = the cloze index (c1 → ord 1, c2 → ord 2).
   - `render(note, card)`: for `card.templateOrdinal = N`, return `{ question: textWithClozeN_blanked, answer: textWithClozeN_filled, oneSided: true }`. Cloze parsing happens first; markdown rendering wraps the resulting segments.
   - `cardLabel`: `'Cloze (N/total)'`.
   - `sortFieldValue`: first 80 chars of `text` (stripped of cloze delimiters).
   - `validate`: rejects notes with no cloze indices.
   - Register in `NoteTypeRegistry`.

4. **`ClozeEditor` widget** (`lib/features/cards/presentation/widgets/cloze_editor.dart`)
   - Single multiline TextField.
   - Toolbar button "Add cloze" that wraps the current text selection in `{{cN::...}}` with auto-incremented `N`.
   - Info chip row showing detected indices ("c1, c2, c3").
   - Preview (via `render`) shows the blanked-out version of each card.

5. **`NoteFormScreen` extensions**:
   - Add note-type selector dropdown on create (Basic / Reverse / Cloze).
   - Add note-type-change confirmation dialog for edits: count cards whose FSRS will *actually* reset (using the `(ordinal, kind)` diff) and warn "This will reset FSRS progress for N cards." On confirm, `NoteService.upsertNote` handles the diff transparently.
   - Editor dispatch already goes through `NoteTypeRegistry[note.noteType].editor(...)`, so no form screen surgery beyond the selector.

6. **`FlipCard.oneSided` mode** (`lib/features/study/presentation/widgets/flip_card.dart`)
   - When `CardView.oneSided == true`, skip the 3D flip. Render the question (cloze-blanked text) immediately.
   - Tap / Space triggers a crossfade reveal animation (~250ms, accent-colored glow on the revealing span).
   - Post-reveal, re-use the existing `SwipeableCard` gating so swipe-to-rate enables just as it does after a flip.
   - `StudySessionScreen` already passes `CardView` down; no screen-level change required.

7. **CSV extensions** — add a `cloze_text` column so cloze notes survive export/import.

### Decisions already made (don't re-litigate)

- Hint syntax is `{{c1::answer::hint}}`.
- Multi-span same index = one card.
- Note-type switching is allowed. FSRS is preserved where `(ordinal, kind)` pairs overlap between old and new type; reset only for non-overlapping pairs. `NoteService` handles this automatically.
- Cloze text is parsed **before** markdown rendering.
- Cloze is one-sided (no 3D flip) — reveal animation instead.
- `cardKind` is categorical (`'cloze'`, not `'cloze:1'`); ordinal carries the index.
- Notes row limit is 2,000/user on Supabase (raise via migration later if needed).

### Things we specifically did NOT do so you have room to decide

- Exact cloze blank rendering style (underlined span? colored chip? `[…]`?) — left to your UX judgment.
- Reveal animation easing/glow exact values — left to your polish.
- Whether to support `{{c1::answer::hint}}` with multiple hints — defer until someone asks for it.

### Considerations for later (not blocking, but worth thinking about)

- **Siblings-bury**: when a user sees a Reverse or Cloze card, its siblings from the same note shouldn't appear in the same session. Study-flow logic in `StudySessionService` needs a "seen-siblings this session" set. Not blocking — the worst case without it is "both sides of a Reverse card in one session," which is mildly annoying but not broken.
- **Anki `.apkg` import**: our model is conceptually compatible (Anki's `notes.flds` → our `fields_json`, Anki's `cards.ord` → our `template_ordinal`, Anki's cloze model maps cleanly). A future importer is viable.
- **`sortFieldValue` caching**: for large note collections, `sortFieldExistsInDeck` scans JSON on every check. If this gets slow, add a `sort_field TEXT` generated column + index.

### Entry points

- Architecture: `lib/features/cards/domain/note_type.dart` (interface), `basic_note_type.dart` (reference impl), registry wiring in `main.dart`.
- Form surgery: `lib/features/cards/presentation/screens/note_form_screen.dart`.
- Study surgery: `lib/features/study/presentation/widgets/flip_card.dart`.
- Issue: close #149 in your final PR.
