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

### Rate Limits & Abuse Prevention

- **Row count limits (per user, server-enforced via Postgres triggers):**
  - Decks: 100 (active, non-deleted)
  - Cards: 10,000 (active, non-deleted)
  - Reviews: 10,000 (total — append-only, no soft-delete)
  - Session summaries: 5,000 (total — never deleted)
  - Soft-deleted rows don't count toward limits — deleting frees a slot immediately.
  - Limits are intentionally strict for early access. Raise via migration when needed — lowering retroactively is hard.
- **Payload size constraints (server-side CHECK):**
  - Deck name: 100 chars (client: 50)
  - Card front/back: 2,000 chars each (client: 300 — server buffer for future card types)
- **`app_config` table:** Key-value store for server-side settings (e.g., `min_app_version`). Read-only for `authenticated`, writable only by `postgres`/admin.
- **CAPTCHA:** Enable hCaptcha on sign-up in the Supabase dashboard before production. Client widget deferred to Phase 7.
- **CI secrets for releases:** `env.json` must be generated at build time from GitHub secrets — never committed. Add `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` as repository secrets and create the file in the release workflow.

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

- ~~**Repository providers throw UnimplementedError (#76):**~~ **Resolved.** Providers now return concrete repository instances.

- **Dead Deck.cards/cardCount/dueCount fields on model (#62):** Runtime-only fields that don't belong on the domain object. `cards` is always `[]` from DB, counts are computed inline by screens. Assigned to GADudley.

---

### UX Improvements (from tester feedback)

- **Keyboard submit for deck/card creation (#49):** Pressing Enter in the deck name field should submit the form. Shift+Enter to save cards (plain Enter for newline since card content may be multi-line).

- ~~**Character limit on card text fields (#50):**~~ **Resolved.** Deck names capped at 50 chars, card front/back at 300 chars with `MaxLengthEnforcement.enforced`. Study screen card text scrolls vertically. (Branch: `feat/input-validation`)

- **Right-click context menu on decks/cards (#51):** Already planned (see Multi-Select section). Should include Delete, and eventually Move, Edit, etc.

- **Full keyboard navigation (#52):** App is not fully usable with keyboard alone. Low priority but worth addressing eventually for accessibility.

- **Mobile settings UX bugs (#140):** On mobile, the settings bottom nav overlaps scrollable content (last items hidden behind nav bar). Settings sections need bottom padding to account for nav bar height. Assigned to Pairadux.

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

**Status:** Phases 1-5 complete. Phase 6 (sync engine) in progress.

**Core principle: Offline-first.** The app must work fully without network. Sync is optional — creating an account is never required. No network calls happen until the user explicitly signs in.

#### Auth approach
- **No anonymous sign-in.** Users start with `user_id = ''` (local-only). When they create an account, a one-time atomic SQLite transaction stamps all local rows with their auth `user_id` and sets `sync_status = 'pending'`.
- **Email + password** as the baseline auth method.
- **Password requirements:** Current minimum is 6 characters (Supabase default). Needs strengthening — at minimum: 8+ characters, at least one uppercase, one lowercase, one digit. Enforce client-side before calling Supabase, and configure matching requirements in Supabase dashboard.
- **Sign-in → sign-up continuity:** If a user fills out the sign-in form and clicks "Create account", the sign-up dialog should pre-fill with the email and password they already entered. Also consider: if sign-in fails because the account doesn't exist, offer to create one with the same credentials instead of just showing an error.
- **Google + Apple OAuth** alongside email auth. Apple Sign-In is required by App Store if offering any social login.
- **Email confirmation: OTP code (not link-based).** After sign-up, user enters a 6-digit code from their email. No redirect URLs, no polling, no cross-device issues. Supabase supports this via `verifyOTP(type: OtpType.signup)`. Resend via `resend(type: OtpType.signup)`. This replaces the previous polling-based approach entirely.
- **Platform-conditional auth flows:**
  - Mobile (iOS/Android): deep links for OAuth callbacks and email confirmation
  - Desktop (Linux/macOS/Windows): localhost callback for OAuth; polling for email confirmation (1s intervals for 60s, then 5s intervals for 30min, then "resend" prompt)
- **Email confirmation polling** on all platforms — avoids deep link complexity on desktop.
- **Supabase redirect URLs:** Email confirmation and password reset links both redirect to the Site URL configured in Supabase dashboard. Currently set to localhost, which fails on mobile and shows a broken page. Before production: set Site URL to a hosted page (e.g., project landing page or a simple "You're confirmed, return to the app" page). Alternatively, configure custom email templates in the Supabase dashboard to use deep links for mobile.
- **Duplicate email sign-up:** Supabase intentionally returns a fake success (user object, no session, no email sent) when signing up with an already-registered email — this prevents email enumeration attacks. Our app currently shows "check your email" even though no email was sent. The correct fix is a generic message regardless of outcome: "If an account with this email doesn't exist, we'll send a confirmation link." Do NOT detect or reveal whether the email is already registered — that would subvert Supabase's anti-enumeration protection.
- **2FA/MFA:** Not implemented. Supabase supports TOTP-based MFA. Should be added before production — consider making it optional in settings with QR code setup flow.

##### Phase 5 implementation state (DONE)

**Implemented files:**
- `lib/features/auth/application/auth_service.dart` — Wraps Supabase auth. Key methods: `signUpWithEmail()` (migration only when `response.session != null`, not just user), `signInWithEmail()` (calls `signInWithPassword`, runs migration on success), `signOut()` (saves user_id to SharedPreferences BEFORE calling Supabase signOut), `resetPassword()`, `resendConfirmation()`, `getCurrentUserId()` (priority: active session → stored SharedPreferences → empty string). Has `_requireAvailable()` guard for when Supabase isn't configured.
- `lib/features/auth/application/user_id_migration_service.dart` — One-time atomic SQLite transaction stamping `user_id = ''` rows with auth uid across all 4 tables. Reviews uses `WHERE user_id = '' OR user_id IS NULL` (nullable column from v3 migration). Returns early if authUserId is empty.
- `lib/core/routing/auth_notifier.dart` — Bridges Supabase `onAuthStateChange` stream to GoRouter's `refreshListenable`. No forced redirects (offline-first).
- `lib/features/settings/presentation/screens/settings_screen.dart` — Obsidian-inspired settings with 5 sections (Account, Sync, Study, Appearance, About). Desktop (≥720px): sidebar nav + scrollable content with `FocusTraversalGroup` isolation. Mobile: scrollable content + bottom nav. Account has 3 states via `_AuthDisplayState` enum: signInForm, confirmingEmail, accountInfo. Sign-up and forgot-password dialogs show errors inline (not snackbars — snackbars are behind the dialog modal). OAuth buttons show "not yet available" snackbar. Delete account button is subdued gray `OutlinedButton` that turns red on hover.

**Needs refactoring (before or during Phase 6):**
- Settings screen `_AuthDisplayState.confirmingEmail` and `_startConfirmationPolling()` need to be replaced with OTP code input field. Currently uses polling-based `signInWithPassword` approach. Replace with: show 6-digit code input → call `_client.auth.verifyOTP(type: OtpType.signup, token: code, email: email)` → on success, run migration and set accountInfo state. Keep "Resend code" button.
- Password validation (`_validatePassword`) is implemented client-side (8+ chars, uppercase, lowercase, digit, special char). Supabase dashboard also configured with matching requirements.
- Sign-up dialog pre-fills email and password from the sign-in form controllers.

#### Sync engine (manual, not PowerSync)
- Manual sync is correct for single-user data — no extra dependency or cost.
- **Push on every local write** (debounced ~2-5s), not just on app open.
- **Pull on app open/foreground** (catch up from offline) + **Supabase Realtime** subscription for near-real-time pull when online.
- **Manual sync button** (cloud icon tap) to force sync on demand.
- **Connectivity listener** flushes pending changes when network is restored.
- **Conflict resolution:** Last-write-wins on `updated_at` — sufficient for single-user app.
- **Initial sync** (first upload): background with auto-opening sync panel (Obsidian-style). User can close panel and keep using app — cloud icon shows progress.

##### Phase 6 implementation plan

**Architecture — four classes (all in `lib/core/sync/`):**
- `SyncService` — orchestrator, owns debounce timer, connectivity listener, pause/resume
- `SyncPushService` — push logic for all tables
- `SyncPullService` — pull logic for all tables
- `SyncRealtimeService` — Supabase Realtime subscription management
- `sync_adapter.dart` — `toSupabaseRow()` / `fromSupabaseRow()` utility functions

**Supabase API patterns (PostgREST via Flutter SDK):**
- Push (upsert): `SupabaseConfig.client.from('decks').upsert(rows, onConflict: 'deck_id')` — rows is a `List<Map<String, dynamic>>`, returns inserted/updated rows.
- Pull (select): `SupabaseConfig.client.from('decks').select().gt('updated_at', lastPull)` — RLS automatically filters to current user's rows. Returns `List<Map<String, dynamic>>`.
- Reviews pull uses `reviewed_at` not `updated_at` (reviews are immutable, no `updated_at` column).
- All Supabase calls require an active session (`SupabaseConfig.client.auth.currentSession != null`). Guard all sync operations with this check.

**Push flow (local → Supabase):**
1. Guard: return early if no active session or Supabase not configured
2. Query each table for `sync_status = 'pending'` via existing `getUnsynced()` repo methods
3. Sequential order: decks → cards → reviews → session_summaries (FK dependency — decks must exist before their cards arrive on server)
4. Convert each row: `model.toMap()` → `toSupabaseRow()` (removes `sync_status`, converts `is_deleted` 1/0 → true/false)
5. One upsert request per table — no batching. Row count limits (100 decks, 10K cards) keep payloads reasonable (max ~27 MB worst case, ~7 MB realistic)
6. Supabase upserts atomically per table — all rows land or none do
7. On success: `markSynced()` locally via existing repo methods. On failure: log error, rows stay `pending`, retry next cycle.
8. Soft-deleted rows push too (`is_deleted = true` propagates to server as tombstone).
9. If a table fails mid-sequence (e.g., network drops after decks push), already-synced tables keep their `synced` status. Next cycle resumes from the first table with pending rows. Worst case: empty decks visible briefly on other devices until cards sync.

**Pull flow (Supabase → local):**
1. Guard: return early if no active session
2. Read `last_pull_timestamp` from SharedPreferences (null on first sync)
3. Query each table from Supabase: `select().gt('updated_at', lastPull)` (or `select()` for first sync — pull everything)
4. Sequential order: decks → cards → reviews → session_summaries (FK dependency)
5. Convert each remote row: `fromSupabaseRow()` (converts `is_deleted` true/false → 1/0, adds `sync_status = 'synced'`)
6. For each remote row, look up local row by primary key:
   - No local row → insert via `db.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace)`
   - Local row exists with `sync_status = 'synced'` → overwrite (server is authoritative for already-synced data)
   - Local row exists with `sync_status = 'pending'` → compare `updated_at`: remote newer → overwrite; local newer → skip (local change wins, will push on next cycle)
7. Update `last_pull_timestamp` in SharedPreferences after ALL tables complete successfully
8. Reviews: query by `reviewed_at` instead of `updated_at`. Insert only (reviews are immutable). Skip if `review_id` already exists locally.

**Trigger points:**
- Debounced push 2-5s after any local write (repositories notify SyncService via callback/stream)
- Pull on app open/foreground + after each successful push
- Manual sync button (already in settings UI): push then pull
- Connectivity restore: flush pending pushes
- Realtime: Postgres changes trigger targeted pull

**Study session isolation:**
- `SyncService.pause()` / `resume()`
- During study: pushes queued but not sent, Realtime events buffered in memory
- On session end: flush queue, process buffered events
- Study screens call `pause()` in initState, `resume()` in dispose

**Serialization adapter (`sync_adapter.dart`):**
- `toMap()`/`fromMap()` on models are SQLite-specific (booleans as `1`/`0`, includes `sync_status`)
- Supabase needs native booleans (`true`/`false`) and no `sync_status` column
- `toSupabaseRow(Map<String, dynamic> localMap)`: shallow copy, removes `sync_status`, converts `is_deleted` `1`/`0` → `true`/`false`
- `fromSupabaseRow(Map<String, dynamic> remoteMap)`: shallow copy, converts `is_deleted` `true`/`false` → `1`/`0`, adds `sync_status: 'synced'`
- Only two fields differ between SQLite and Postgres. All timestamps, UUIDs, strings, integers are identical.
- Adapter lives at the Supabase boundary (in sync services), not on the models — avoids touching every repository and test

**Existing infrastructure (already implemented):**
- All 4 repositories have `getUnsynced()` → returns rows where `sync_status != 'synced'`
- All 4 repositories have `markSynced(List<String> ids)` → updates `sync_status` to `'synced'`
- `SyncStatus` enum: `synced`, `pending`, `conflict`
- Sync-status indexes on all tables (partial index on `sync_status != 'synced'`)
- `SupabaseConfig.client` for API access, `SupabaseConfig.isConfigured` guard
- `AuthService.getCurrentUserId()` for user context
- `SharedPreferences` already a dependency (used for stored user_id)

**Build order:**
1. `sync_adapter.dart` — serialization utilities
2. `SyncPushService` + `SyncPullService` — core push/pull logic
3. `SyncService` orchestrator — debounced push, pull on open, manual sync wiring in settings
4. `SyncRealtimeService` + connectivity listener
5. Study session isolation (pause/resume)

**Phase 7 (deferred — post-sync production hardening):**
- Wire up OAuth (Google/Apple) — buttons exist as placeholders
- Account deletion Edge Function
- Client-side tombstone purge (7-day rule: `is_deleted = 1 AND updated_at < now - 7 days AND (sync_status = 'synced' OR user_id = '')`)
- Review pruning to 10K cap (server-side scheduled job or on push)
- CAPTCHA client widget (hCaptcha — dashboard already enabled)
- `min_app_version` check before sync (table exists in `app_config`, needs client-side check)
- CI secrets injection for release builds (`env.json` from GitHub secrets)
- OTP code input replacing polling in settings screen `_AuthDisplayState.confirmingEmail`
- Duplicate email sign-up generic messaging
- 2FA/MFA (TOTP, optional in settings)
- Redirect URL fix for password reset (set Site URL in Supabase dashboard)
- Cold start frequency tracking / per-user egress monitoring

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
