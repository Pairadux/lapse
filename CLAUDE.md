# Lapse — Project Instructions

## Architecture

- Flutter app using GoRouter (flat routes), Material 3 dark theme, SQLite (sqflite)
- Repository pattern for data access, Riverpod for state management (migration in progress)
- Platform-aware page transitions: 150ms crossfade on desktop (via `buildPage` in GoRouter), Cupertino on iOS, Zoom on Android
- Features: decks (nested), flashcards, study sessions with FSRS scheduling

## Code Style

- Follow existing patterns: `AppScaffold`, `DeckCard`, `EmptyStateWidget`, `LoadingIndicator`, `ConfirmDialog`
- Theme constants in `core/theme/` — use `AppColors`, `Spacing` everywhere
- Database constants in `DatabaseConstants` — never use raw column name strings
- Repositories accept optional `DatabaseHelper` for testability
- Use snackbars/toasts to surface errors to the user — never fail silently

## Supabase & Security Rules

- **RLS is critical.** Never assume RLS policies are correct — always verify against Supabase docs before writing or modifying any policy. Confirm details before making any change that involves or affects RLS.
- **Never store auth tokens, passwords, or PII** outside of what the Supabase SDK manages internally. We only persist non-sensitive metadata (user_id UUID, sync flags) via SharedPreferences.
- **Never log or print tokens** — no `print(session.accessToken)` or similar in debug output.
- **Never read or commit `env.json`** — contains Supabase secrets. Reference `env.example.json` for the expected shape.
- **Supabase project config is our responsibility** — email confirmation, OTP expiry, CAPTCHA, custom SMTP. These are dashboard settings but must be enabled before production.
- **The anon key ships in the app binary** (publicly visible). RLS + privilege revocation are the real security layer, not key secrecy.

### Supabase Migration & Schema Guidelines

- **Wrap migrations in `BEGIN; ... COMMIT;`** — Supabase CLI does NOT auto-wrap migrations in transactions. A partial failure leaves the schema in a broken state without explicit transaction wrapping.
- **RLS policies: always use `(select auth.uid())`** — wrap in a subquery, never bare `auth.uid()`. The subquery lets Postgres cache the result per-statement instead of calling it per-row (benchmarked 94-99% improvement).
- **RLS policies: always specify `TO authenticated`** — without it, the policy evaluates for all roles including `anon`, wasting cycles (benchmarked 99.78% improvement).
- **Privilege pattern: REVOKE ALL → explicit GRANT** — never rely on Supabase's default broad grants. Revoke everything from both `anon` and `authenticated`, then grant back only the exact operations needed. This future-proofs against default changes.
- **Index columns used in RLS policies** — any column referenced in a `USING` or `WITH CHECK` clause (e.g., `user_id`) must be indexed, or every policy check triggers a sequential scan.
- **Use custom PL/pgSQL for `updated_at` triggers** — don't use the `moddatetime` extension (docs 404, potential deprecation risk). A simple `set_updated_at()` function has zero dependency.
- **Install extensions in `extensions` schema** — never in `public`. Supabase's `extra_search_path` includes `extensions` by default.
- **Views bypass RLS by default** — they run as the `postgres` owner. If we add views, use `security_invoker = true` (Postgres 15+).
- **`config.toml` is for local dev only** — production auth settings (SMTP, CAPTCHA, password requirements) are managed via the Supabase dashboard or `supabase config push`.

---

## Future Work & Design Decisions

### Card Management — Multi-Select & Bulk Operations

**Status:** Planned, not yet implemented.

**Design:** Long-press a card to enter selection mode. Checkboxes appear on all items. A bottom action bar slides up with actions:
- **Move** — pick a destination deck from a tree picker dialog
- **Delete** — bulk soft-delete with confirmation
- **Select All / Deselect** — in the action bar

**Why:** Users need to consolidate sub-decks, reorganize cards, and batch-edit. Moving cards one at a time is unacceptable UX.

**Data layer needed:**
- `CardRepository.moveCards(List<String> cardIds, String targetDeckId)` — bulk update deckId
- `CardRepository.bulkDelete(List<String> cardIds)` — bulk soft-delete
- A deck tree picker widget for selecting the destination

### Unified Card Manager (Anki-style Card Browser)

**Status:** Planned, not yet implemented.

**Design:** A top-level screen (accessible from home or settings) showing ALL cards across ALL decks in a flat, searchable, sortable list. Think Anki's card browser.

**Features to include:**
- Search/filter by front text, back text, deck name, card state (new, learning, review)
- Sort by due date, created date, difficulty, deck
- Inline deck label on each row showing which deck the card belongs to
- Tap to edit, long-press for multi-select (same pattern as deck detail)
- Bulk move, delete, reschedule

**Route:** `/cards` or `/card-browser`

### Search & Filter on DeckDetailScreen

**Status:** Planned, not yet implemented.

**Design:** A search icon in the header/AppBar that expands a text field. Filters the visible card list by matching front or back text (case-insensitive contains). Could later support advanced filters (state, due date range).

### Advanced Card Types

**Status:** Planning phase. Currently only basic front/back cards exist.

**Future card types to support:**
- **Cloze deletion** — text with blanked-out portions (e.g., "The capital of France is {{c1::Paris}}")
- **Image cards** — front or back can be an image (stored locally or by reference)
- **Image occlusion** — an image with masked regions that are revealed on flip
- **Audio cards** — pronunciation/listening practice
- **Rich text** — markdown or HTML formatting on front/back

**Implementation considerations:**
- The `Flashcard` model will need a `cardType` enum field (basic, cloze, imageOcclusion, etc.)
- Front/back fields may need to support structured content (JSON or markdown) rather than plain text
- The study screen's card rendering must dispatch to type-specific widgets
- The card form screen needs type-specific editors
- The compact card list item in DeckDetailScreen must render a sensible preview regardless of type:
  - Basic: `front → back` (truncated)
  - Cloze: show the full text with blanks indicated (e.g., "The capital of France is [...]")
  - Image: show a thumbnail or "Image card" label
  - The list item design should not assume text-only content

**Truncation strategy for card previews:**
- Use `maxLines: 1` with `overflow: TextOverflow.ellipsis` for text content
- For very long cards, the single-line preview shows the beginning — users tap to see full content
- Future: could show a 2-line preview for cards with long content (user preference)

### Custom Window Title Bar (Desktop)

**Status:** Implemented for Linux. Works on macOS/Windows too.

**Packages:** `window_manager` (frameless window, drag, minimize/maximize/close API) + `modern_titlebar_buttons` (native-themed button SVGs with auto-detection and Adwaita fallback).

**How it works:** `main.dart` hides the native titlebar via `TitleBarStyle.hidden`, then `MaterialApp.router`'s `builder` injects a `WindowTitleBar` widget above all routes on desktop platforms. The titlebar is a 36px drag area with app title + minimize/maximize/close buttons.

**Note:** If the native GTK header bar still appears (double titlebar), the fix is to edit `linux/runner/my_application.cc` — replace the header bar block with just `gtk_window_set_title(window, "lapse");`. This file is NOT regenerated by `flutter build`.

---

## Packaging & Distribution Dependencies

### Linux (AUR / generic)

**Runtime dependencies (`depends`):**
- `gtk3` — Flutter Linux embedding
- `glib2` — GSettings backend (for titlebar button theme detection)
- `dbus` — D-Bus communication (titlebar theme auto-detection)
- `sqlite` — SQLite database (via sqflite_common_ffi)

**Build dependencies (`makedepends`):**
- `flutter` — Flutter SDK
- `cmake` — Linux build system
- `ninja` — Build tool
- `clang` — C/C++ compiler
- `pkg-config` — Library discovery
- `gtk3` (headers) — Flutter Linux embedding

### macOS

**Runtime:** No extra dependencies (all bundled in .app)
**Build:** Xcode, CocoaPods

### Windows

**Runtime:** Visual C++ Redistributable (usually pre-installed)
**Build:** Visual Studio 2022 with C++ desktop workload

### Android / iOS

No desktop-specific dependencies. Standard Flutter mobile toolchains.

---

### AppBar Scroll-Under Tint

**Status:** Design decision open.

Material 3 tints the AppBar when content scrolls beneath it (elevation effect). Some testers like it; the product owner is unsure. Left as-is for now — revisit if user feedback leans negative. To disable: set `scrolledUnderElevation: 0` in `AppBarTheme` in `app_theme.dart`.

---

### Tooltips (Future Setting)

**Status:** Globally suppressed via `TooltipThemeData(waitDuration: Duration(days: 365))` in `app_theme.dart`.

**Future plan:** Add a user setting to toggle tooltips on/off. When enabled, remove the `waitDuration` override so Flutter's default tooltip behavior applies. Useful for accessibility but distracting for experienced users.

---

### Reduced Motion (Future Setting)

**Status:** Planned, not yet implemented.

**Future plan:** Add a user setting to reduce or disable animations app-wide. When enabled, flip animations would crossfade instead of 3D rotate, dismiss animations would be instant or very fast, and swipe gestures would snap rather than animate. Respects platform accessibility preferences (`MediaQuery.disableAnimations`) as a default.

---

### New Cards Daily Limit (Future Setting)

**Status:** Planned, not yet implemented.

**Future plan:** Cap how many new (unseen) cards a user studies per day, similar to Anki's default of ~20 new cards/day. Reviews of previously-seen cards are unlimited. Needs a setting for the limit value and tracking of how many new cards were introduced today.

---

### ~~Splash / Launch Screen~~

**Status:** Resolved. Dark background (#0F0F14) with centered app icon on Android (both pre-v21 and v21+) and iOS.

---

### Known Bugs

- **Database not ready on first launch (#131):** Tester reported the app doesn't work on first open after fresh install, but works after relaunch. Root cause: `DatabaseHelper` is lazily initialized — no eager `await` in `main()`. The migration chain (v1→v4) runs during the first screen's data load, which may cause the UI to render an error/empty state before the DB is ready. Fix: eagerly await `DatabaseHelper.instance.database` in `main()` before `runApp()`, or add retry/loading logic at the app shell level.

- **Card count aggregation sometimes off (#44):** Aggregated card/due counts on parent decks occasionally show stale or incorrect numbers. Likely a timing issue with parallel Future.wait queries or stale state after mutations. Needs investigation.

- ~~**"Save & Add Another" not clearing fields (#45):**~~ **Resolved.** Fields clear and focus returns to front field via post-frame callback.

- ~~**Cascade soft-delete (#46):**~~ **Resolved.** `DeckRepository.delete()` uses recursive CTE + transactional cascade.

- ~~**Dev menu buttons don't refresh UI (#47):**~~ **Resolved.** `DevDrawer` now accepts `onDataChanged` callback.

- ~~**Empty deck study shows misleading message (#48):**~~ **Resolved.** `DeckDetailScreen._study()` checks total card count.

- **study_session_service.dart won't compile (#74):** Duplicate `StudySessionResult` class, unreachable code, return type mismatch. Assigned to Darius.

- **Study session does not persist reviews (#75):** `_rateCard()` only updates local counters — FSRS not called, card not updated in DB, no Review record saved. Blocked by #74. Assigned to Darius.

- **Repository providers throw UnimplementedError (#76):** `deckRepositoryProvider` and `cardRepositoryProvider` never overridden in ProviderScope. Assigned to GADudley.

- **Dead Deck.cards/cardCount/dueCount fields on model (#62):** Runtime-only fields that don't belong on the domain object. `cards` is always `[]` from DB, counts are computed inline by screens. Assigned to GADudley.

---

### UX Improvements (from tester feedback)

- **Keyboard submit for deck/card creation (#49):** Pressing Enter in the deck name field should submit the form. Shift+Enter to save cards (plain Enter for newline since card content may be multi-line).

- ~~**Character limit on card text fields (#50):**~~ **Resolved.** Deck names capped at 50 chars, card front/back at 300 chars with `MaxLengthEnforcement.enforced`. Study screen card text scrolls vertically. (Branch: `feat/input-validation`)

- **Right-click context menu on decks/cards (#51):** Already planned (see Multi-Select section). Should include Delete, and eventually Move, Edit, etc.

- **Full keyboard navigation (#52):** App is not fully usable with keyboard alone. Low priority but worth addressing eventually for accessibility.

---

### Performance Bottlenecks (from audit 2026-02-14)

**Resolved:**
- ~~#53 N+1 COUNT~~ — `countByDeckId()` / `countDueByDeckId()` use COUNT(*) queries
- ~~#54 Recursive Dart-side tree walk~~ — `getDescendantIds()` uses `WITH RECURSIVE` CTE
- ~~#55 getAll() filtered client-side~~ — `getRootDecks()` added
- ~~#57 FocusNode leak~~ — stored in `initState()`, disposed properly
- ~~#58 Sequential card loading~~ — `Future.wait()` for parallel loading
- ~~#59 `_dbName` ignored~~ — fixed in `fix/audit-bugs` branch
- ~~#60 clearAllData() not transactional~~ — wrapped in transaction in `fix/audit-bugs` branch
- ~~#63 CurvedAnimation leak~~ — pre-created in `initState()` in `fix/audit-bugs` branch

**Still open:**
- **Double card fetch in DeckDetailScreen (#56):** `_loadData()` fetches cards, then `_getAggregatedCounts()` also queries descendants. — `deck_detail_screen.dart`
- **Redundant getDescendantIds() in _study() (#61):** Already computed during `_loadData()`, not cached. — `deck_detail_screen.dart`
- **Dead Deck.cards field in Equatable props (#62):** See Known Bugs above. Assigned to GADudley.
- **Mock data insertion not batched (#64):** Sequential individual inserts. Assigned to Devam.
- **No pagination on card queries (#65):** All lists loaded fully into memory. Low impact now, high at scale.
- ~~**Duplicate sqflite_common_ffi in pubspec (#66):**~~ **Resolved.** No longer duplicated.

---

### Page Transition Performance on Desktop

**Status:** Resolved.

**Solution:** Platform-conditional transitions. All GoRouter routes use `buildPage()` from `lib/core/routing/page_transitions.dart`:
- **Desktop** (Linux/macOS/Windows): `CustomTransitionPage` with 150ms crossfade, `Curves.easeOut`
- **Mobile** (iOS/Android): default `MaterialPage` (inherits theme transitions)

Theme-level fallbacks in `app_theme.dart`: `FadeUpwardsPageTransitionsBuilder` on desktop, `CupertinoPageTransitionsBuilder` on iOS, `ZoomPageTransitionsBuilder` on Android.

The `isDesktop` getter lives in `page_transitions.dart` and is also imported by `main.dart`.

---

### Study Session — Swipe-to-Rate & Card Stack Visual

**Status:** In progress (`feat/study-swipe` branch).

**Visual changes (all platforms):**
- Radial gradient background behind card area: `AppColors.primary` (violet) bottom-left, `AppColors.secondary` (pink) top-right, low opacity — matching the logo palette
- Card stack illusion: 1-2 offset "shadow" cards behind the active card (down-right offset, decreasing opacity) mimicking the logo's letter-echo effect
- Subtle horizontal 3D flip animation (~250ms) when revealing the answer — front rotates to edge, back rotates in un-mirrored
- Card has margin exposing gradient edges

**Touch-only changes (iOS/Android):**
- Swipe-to-rate replaces the button row. Tap to flip, then swipe to rate (cannot swipe before flip)
- Direction → rating mapping (Tinder-style):
  - **Right** → Good (green) — most common positive action
  - **Left** → Hard (amber) — most common negative action
  - **Up** → Easy (blue) — ascending = instant recall
  - **Down** → Again (red) — banishing = forgot
- Card follows finger freely with slight rotation and scale-up ("coming forward" from the stack)
- Rating label fades in at card edge during drag, colored border shows intent
- 25% screen dimension threshold to commit; below that, card snaps back

**Desktop unchanged:** Keyboard shortcuts (Space to flip, 1-4 to rate) and button row remain.

**Widgets:**
- `lib/features/study/presentation/widgets/flip_card.dart` — 3D flip animation
- `lib/features/study/presentation/widgets/swipeable_card.dart` — pan gesture + swipe-to-rate
- `lib/features/study/presentation/widgets/card_stack.dart` — gradient background + shadow cards

**Planned: First-launch tutorial popup (#109).** One-time overlay explaining swipe directions on mobile. Resettable from settings. Separate branch/PR.

~~**Haptic feedback on touch devices.**~~ **Implemented.** Light impact on card flip, medium impact on swipe commit and rating button press. Uses `HapticFeedback` from `flutter/services.dart`.

**Planned: Undo button (#132).** Reverses the user's last review — deletes the review record, reverts card FSRS state, smooth fly-back animation pushing the shadow stack back down. Only the single most recent review, not a full undo stack.

**Shadow card content decision:** Keep shadow cards blank (Option B). Future improvement: crossfade new card content in over ~150ms after the shadow promotes to top position, so the blank→content transition feels intentional rather than jarring. No spoilers during drag.

~~**Known UX issue (resolved):** Card creation preview pane pushed save button off-screen on mobile.~~ Replaced with app bar edit/preview toggle; buttons pinned at bottom.

---

### Tester-Verified Behavior (2026-02-13)

The following were confirmed working correctly by an external tester:
- Deck creation with normal names, leading/trailing spaces, emoji, non-Latin/accented characters (é, ñ), Unicode
- Duplicate deck names: warns but allows (intentional — uniqueness is by UUID)
- Card creation with emoji/Unicode in front/back fields
- Empty front/back validation (blocks creation correctly, including whitespace-only)
- Nested deck study pulls cards from all descendant decks (intentional behavior, confirmed noticed by tester)
- Individual card soft-delete sets `is_deleted=true` correctly
- Clear database fully removes all records

---

### MVP Audit (2026-02-27)

**Branches created:**
- `fix/audit-bugs` — DatabaseHelper `_dbName` fix (#59), `clearAllData()` transaction (#60), SpeedDialFab CurvedAnimation leak (#63), breadcrumb overflow handling
- `feat/input-validation` — Deck name 50 char cap, card text 300 char cap, paste enforcement, study screen card scrollability (#50)
- `feat/mock-data-edge-cases` — Convenience factories `Deck.create()` and `Flashcard.newCard()` (#23), edge case mock data (deep nesting, max-length, bulk 200 cards, minimal content)

**MVP blockers remaining:**
- `study_session_service.dart` won't compile (#74) — blocks all FSRS integration
- Study session does not persist reviews (#75) — blocked by #74
- Repository providers throw UnimplementedError (#76) — blocks Riverpod migration
- Screens bypass Riverpod providers entirely (#77) — all screens use direct repo calls

**State management status:** Riverpod providers exist but are dead code. All screens use direct `DeckRepository()` / `CardRepository()` instantiation. Functional for MVP but not wired through state management.

---

### Soft-Delete Purge Strategy

**Status:** Design finalized, not yet implemented.

**Server:** Never hard-delete decks, cards, or session summaries. Tombstones (`is_deleted = true`) are tiny and kept forever. This ensures any device — no matter how long offline — always pulls the deletion marker and never resurrects deleted data.

**Client local purge rule (on app launch):**
```
is_deleted = 1
AND updated_at < (now - 7 days)
AND (sync_status = 'synced' OR user_id = '')
```

- `sync_status = 'synced'` — server has the tombstone, safe to purge locally
- `user_id = ''` — local-only data, server never knew, safe to purge
- Items with `sync_status = 'pending'` and a `user_id` are **never purged** — they need to sync first
- The 7-day grace period prevents race conditions between pull and local purge

**Reviews:** Not soft-deleted. Pruned independently — server to 10K, client to 11K per user. `ON DELETE CASCADE` from cards handles cleanup when cards are purged.

**Account states:**
- **Not logged in (local-only):** `user_id = ''`, purge freely after 7 days
- **Logged in, online:** deletions sync, then purge locally after 7 days
- **Logged in, offline:** `sync_status` stays `'pending'`, purge skips them until they sync
- **Signs out with unsynced deletes:** pending items stay until user signs back in and syncs (data safety over minor bloat)

---

### Review Data & Sync Strategy

**Status:** Design finalized, not yet implemented.

**Problem:** Reviews are append-only and the highest-volume table. A power user studying 200-300 cards/day generates ~100K reviews/year. Syncing the full log is wasteful — most of it is never read, and uncapped growth bloats device storage unnecessarily.

**Decision:** Two tables, both synced, serving different purposes.

#### `reviews` table — capped at 10K most recent per user
- Exists in both local SQLite and server-side Postgres, synced normally.
- After each study session, prune local rows exceeding 10K by deleting the oldest.
- Server-side does the same via scheduled job or on push.
- 10K rows at ~300 bytes each = ~3MB max. Negligible storage impact.
- **Purpose:** Per-card review history and FSRS optimizer fuel (needs 1K-10K reviews to fit parameters).
- **Pruning query:**
  ```sql
  DELETE FROM reviews
  WHERE review_id NOT IN (
    SELECT review_id FROM reviews
    ORDER BY reviewed_at DESC
    LIMIT 10000
  )
  ```

#### `review_session_summary` table — never pruned, synced
- One row per study session (not per day). Aggregated when the session ends — this is a clear, deterministic event. We cannot aggregate per-day because we don't know when the user's last session of the day is.
- Multiple sessions in a day produce multiple rows. Daily rollups are derived via `GROUP BY date` at query time.
- Volume is negligible: ~1-3 rows/day, ~365-1000 rows/year.
- **Purpose:** Powers all historical stats UI across devices — heatmaps, streaks, rating trends, time-studied graphs.
- **Schema:**
  - `id` (UUID PK)
  - `user_id` (TEXT)
  - `date` (TEXT, YYYY-MM-DD) — for fast daily grouping without timestamp parsing
  - `started_at` (TEXT, ISO 8601)
  - `ended_at` (TEXT, ISO 8601)
  - `total_reviews` (INTEGER)
  - `again_count`, `hard_count`, `good_count`, `easy_count` (INTEGER — rating breakdown)
  - `new_count`, `learning_count`, `review_count` (INTEGER — card state breakdown)
  - `duration_ms` (INTEGER)
  - `sync_status` (TEXT)
  - `updated_at` (TEXT)

#### FSRS optimizer
- Not MVP scope. When implemented, runs **locally** against the 10K review window.
- The optimizer is ML-based — it replays the full review log to fit 19 weight parameters. It needs the full history (1K+ reviews, ideally 10K), so it cannot run incrementally on a single day's data.
- Only the resulting 19 floats (parameters) are synced as user settings, not the review data that produced them.

---

### Sync & Auth — Design Decisions

**Status:** Schema phase in progress. Auth and sync engine are future phases.

**Core principle: Offline-first.** The app must work fully without network. Sync is optional — creating an account is never required. No network calls happen until the user explicitly signs in.

#### Auth approach
- **No anonymous sign-in.** Users start with `user_id = ''` (local-only). When they create an account, a one-time atomic SQLite transaction stamps all local rows with their auth `user_id` and sets `sync_status = 'pending'`.
- **Email + password** as the baseline auth method.
- **Password requirements:** Current minimum is 6 characters (Supabase default). Needs strengthening — at minimum: 8+ characters, at least one uppercase, one lowercase, one digit. Enforce client-side before calling Supabase, and configure matching requirements in Supabase dashboard.
- **Sign-in → sign-up continuity:** If a user fills out the sign-in form and clicks "Create account", the sign-up dialog should pre-fill with the email and password they already entered. Also consider: if sign-in fails because the account doesn't exist, offer to create one with the same credentials instead of just showing an error.
- **Google + Apple OAuth** alongside email auth. Apple Sign-In is required by App Store if offering any social login.
- **Platform-conditional auth flows:**
  - Mobile (iOS/Android): deep links for OAuth callbacks and email confirmation
  - Desktop (Linux/macOS/Windows): localhost callback for OAuth; polling for email confirmation (1s intervals for 60s, then 5s intervals for 30min, then "resend" prompt)
- **Email confirmation polling** on all platforms — avoids deep link complexity on desktop.
- **Supabase redirect URLs:** Email confirmation and password reset links both redirect to the Site URL configured in Supabase dashboard. Currently set to localhost, which fails on mobile and shows a broken page. Before production: set Site URL to a hosted page (e.g., project landing page or a simple "You're confirmed, return to the app" page). Alternatively, configure custom email templates in the Supabase dashboard to use deep links for mobile.
- **Duplicate email sign-up:** Supabase intentionally returns a fake success (user object, no session, no email sent) when signing up with an already-registered email — this prevents email enumeration attacks. Our app currently shows "check your email" even though no email was sent. The correct fix is a generic message regardless of outcome: "If an account with this email doesn't exist, we'll send a confirmation link." Do NOT detect or reveal whether the email is already registered — that would subvert Supabase's anti-enumeration protection.
- **2FA/MFA:** Not implemented. Supabase supports TOTP-based MFA. Should be added before production — consider making it optional in settings with QR code setup flow.

#### Sync engine (manual, not PowerSync)
- Manual sync is correct for single-user data — no extra dependency or cost.
- **Push on every local write** (debounced ~2-5s), not just on app open.
- **Pull on app open/foreground** (catch up from offline) + **Supabase Realtime** subscription for near-real-time pull when online.
- **Manual sync button** (cloud icon tap) to force sync on demand.
- **Connectivity listener** flushes pending changes when network is restored.
- **Conflict resolution:** Last-write-wins on `updated_at` — sufficient for single-user app.
- **Initial sync** (first upload): background with auto-opening sync panel (Obsidian-style). User can close panel and keep using app — cloud icon shows progress.

#### Sign-out / session handling
- On sign-out: store `user_id` in SharedPreferences. New data still stamped with that `user_id`. Show non-blocking banner: "You're signed out. Sign in to sync."
- On sign-back-in (same account): sync resumes seamlessly.
- On sign-in (different account): prompt — "This device has data from another account. Remove it or keep it?" Kept data is invisible (filtered by `user_id`), removable later from settings.
- **Desktop session expiry:** Sync pauses silently. On next user interaction, attempt token refresh. If truly expired, show banner: "Session expired. Sign in to resume sync."

#### Account deletion
- **Server:** `ON DELETE CASCADE` wipes all Postgres data automatically.
- **Local:** Prompt with confirmation — "Your account has been deleted. Keep your study data locally or delete everything?" Default to keeping (users may have months of study progress). If kept, `user_id` reverts to `''`, app returns to offline-only mode. If they make a new account later, data re-uploads cleanly (no UUID conflicts — PKs are globally unique).

#### Settings structure (Obsidian-style, not a dedicated account page)
```
Settings
├── Account
│   ├── Sign in / Sign up (or email + sign out if logged in)
│   └── Delete account
├── Sync
│   ├── Sync status (cloud icon + last synced time)
│   ├── Sync now (manual trigger)
│   ├── Sync activity log (scrollable history of push/pull/conflict events)
│   └── Local data management (per-account deletion with confirmation)
├── Study
│   └── (FSRS settings, daily limits, etc.)
└── About
```

#### Local data management
- **"Delete all data" in settings** — essential on desktop where uninstall doesn't clean up app data.
- **Per-account deletion**: settings shows accounts that have data on this device (by email or UUID) with individual delete options. Requires confirmation prompt + reminder they can clear later from settings.
- **Uninstall behavior varies by platform:** iOS/Android auto-clean; macOS/Linux/Windows may leave data in Application Support / .local/share / AppData.

#### Error UX
- Use **snackbars/toasts** for sync errors, auth failures, and any user-facing errors — never fail silently.
- Sync log in settings provides detailed history for debugging.

#### Testing considerations
- Multiple test accounts needed (email accounts) to test multi-user scenarios.
- Test edge cases: sign out mid-sync, kill app during initial upload, different account sign-in on same device, account deletion from another device.

---

### DeckDetailScreen Layout Decision

**Chosen approach:** Unified list (folders-first), no tabs or toggles.
- Sub-decks appear at the top of the list with folder styling
- A section divider with "Cards" label separates sub-decks from cards
- Leaf decks (no children) show cards directly with no divider
- Header: breadcrumb line + stats/study row (Option C style with readable text size)
- This mirrors the universal file-manager pattern (folders then files)
