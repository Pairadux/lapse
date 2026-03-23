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

- **Wrap migrations in `BEGIN; ... COMMIT;`** — Supabase CLI does NOT auto-wrap migrations in transactions.
- **RLS policies: always use `(select auth.uid())`** — wrap in a subquery, never bare `auth.uid()`. The subquery lets Postgres cache the result per-statement instead of calling it per-row.
- **RLS policies: always specify `TO authenticated`** — without it, the policy evaluates for all roles including `anon`.
- **Privilege pattern: REVOKE ALL → explicit GRANT** — never rely on Supabase's default broad grants. Revoke everything from both `anon` and `authenticated`, then grant back only the exact operations needed.
- **Index columns used in RLS policies** — any column referenced in a `USING` or `WITH CHECK` clause must be indexed.
- **Use custom PL/pgSQL for `updated_at` triggers** — don't use the `moddatetime` extension (docs 404, potential deprecation risk).
- **Install extensions in `extensions` schema** — never in `public`.
- **Views bypass RLS by default** — use `security_invoker = true` (Postgres 15+) if adding views.
- **`config.toml` is for local dev only** — production auth settings managed via Supabase dashboard or `supabase config push`.

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
- **CI secrets for releases:** `env.json` must be generated at build time from GitHub secrets — never committed.

---

## Future Work & Design Decisions

### Card Management — Multi-Select & Bulk Operations

**Status:** Planned. Long-press enters selection mode with checkboxes and a bottom action bar (Move, Delete, Select All). Needed because moving/deleting cards one at a time is unacceptable UX. Data layer: `CardRepository.moveCards()`, `CardRepository.bulkDelete()`, deck tree picker widget.

### Unified Card Manager (Anki-style Card Browser)

**Status:** Planned. Top-level screen showing ALL cards across ALL decks in a flat, searchable, sortable list. Search/filter by text, deck, card state. Sort by due date, difficulty, etc. Tap to edit, long-press for multi-select with bulk operations. Route: `/cards` or `/card-browser`.

### Search & Filter on DeckDetailScreen

**Status:** Planned. Search icon in AppBar expanding a text field. Filters cards by front/back text (case-insensitive). Later: advanced filters (state, due date range).

### Advanced Card Types

**Status:** Planning phase. Currently only basic front/back cards exist.

**Future types:** Cloze deletion, image cards, image occlusion, audio cards, rich text (markdown/HTML).

**Key design constraints:**
- `Flashcard` model needs a `cardType` enum field
- Front/back fields may need structured content (JSON/markdown) instead of plain text
- Study screen rendering dispatches to type-specific widgets
- Card list previews must not assume text-only content (thumbnails for images, "[...]" for cloze, etc.)

### Custom Window Title Bar (Desktop)

**Status:** Implemented. Uses `window_manager` + `modern_titlebar_buttons`.

**GTK note:** If native GTK header bar still appears (double titlebar), edit `linux/runner/my_application.cc` — replace the header bar block with just `gtk_window_set_title(window, "lapse");`. This file is NOT regenerated by `flutter build`.

### Future Settings (Planned)

- **Tooltips:** Currently globally suppressed. Future toggle in settings for accessibility.
- **Reduced Motion:** Respect `MediaQuery.disableAnimations` as default. When enabled: crossfade instead of 3D flip, instant dismiss, snap instead of animate.
- **New Cards Daily Limit:** Cap unseen cards per day (Anki-style ~20/day default). Reviews of seen cards unlimited.
- **AppBar Scroll-Under Tint:** M3 elevation tint on scroll — left as-is, revisit if user feedback leans negative. Disable via `scrolledUnderElevation: 0` in `AppBarTheme`.

---

## Known Bugs

- **Database not ready on first launch (#131):** `DatabaseHelper` lazily initialized — no eager `await` in `main()`. Migration chain runs during first screen data load. Fix: eagerly await `DatabaseHelper.instance.database` in `main()` before `runApp()`.
- **Card count aggregation sometimes off (#44):** Stale/incorrect aggregated counts on parent decks. Likely timing issue with parallel queries or stale state after mutations.
- **study_session_service.dart won't compile (#74):** Duplicate class, unreachable code, return type mismatch. Blocks FSRS integration. Assigned to Darius.
- **Study session does not persist reviews (#75):** `_rateCard()` only updates local counters. Blocked by #74. Assigned to Darius.
- **Dead Deck.cards/cardCount/dueCount fields (#62):** Runtime-only fields that don't belong on the domain object. Assigned to GADudley.

### Open Performance Issues

- **Double card fetch in DeckDetailScreen (#56):** `_loadData()` fetches cards, then `_getAggregatedCounts()` also queries descendants.
- **Redundant getDescendantIds() in _study() (#61):** Already computed during `_loadData()`, not cached.
- **Mock data insertion not batched (#64):** Sequential individual inserts. Assigned to Devam.
- **No pagination on card queries (#65):** All lists loaded fully into memory. Low impact now, high at scale.

### Open UX Improvements

- **Keyboard submit for deck/card creation (#49):** Enter submits deck name. Shift+Enter saves cards (plain Enter for newline).
- **Right-click context menu (#51):** Delete, Move, Edit on decks/cards.
- **Full keyboard navigation (#52):** Low priority, needed for accessibility.
- **Mobile settings UX bugs (#140):** Bottom nav overlaps scrollable content. Assigned to Pairadux.

---

## State Management Status

Riverpod providers exist but are dead code. All screens use direct `DeckRepository()` / `CardRepository()` instantiation. Functional but not wired through state management (#77).

---

## Study Session — Swipe-to-Rate & Card Stack Visual

**Status:** In progress (`feat/study-swipe` branch).

**Visual design (all platforms):**
- Radial gradient background: `AppColors.primary` (violet) bottom-left, `AppColors.secondary` (pink) top-right — matching logo palette
- Card stack illusion: 1-2 offset shadow cards behind active card (logo's letter-echo effect)
- Horizontal 3D flip animation (~250ms) for answer reveal
- Shadow cards are blank (no spoilers). Future: crossfade content in after shadow promotes to top.

**Touch (iOS/Android) — swipe-to-rate:**
- Tap to flip, then swipe to rate (cannot swipe before flip)
- Swipe directions: Right=Good (green), Left=Hard (amber), Up=Easy (blue), Down=Again (red)
- Card follows finger with slight rotation/scale-up. 25% screen threshold to commit.
- Rating label fades in at card edge during drag with colored border
- Haptic feedback: light on flip, medium on swipe commit/button press

**Desktop:** Keyboard shortcuts (Space flip, 1-4 rate) and button row — unchanged.

**Planned additions:**
- First-launch tutorial popup (#109) — one-time overlay explaining swipe directions on mobile
- Undo button (#132) — reverses last review, reverts FSRS state, fly-back animation. Single undo only, not a stack.

---

## Soft-Delete Purge Strategy

**Server:** Never hard-delete. Tombstones (`is_deleted = true`) kept forever so any device — no matter how long offline — always pulls the deletion marker.

**Client local purge rule (on app launch):**
- `is_deleted = 1 AND updated_at < (now - 7 days) AND (sync_status = 'synced' OR user_id = '')`
- `sync_status = 'pending'` rows with a `user_id` are **never purged** — they need to sync first
- 7-day grace period prevents race conditions between pull and local purge

**Reviews:** Not soft-deleted. Pruned to 10K per user (server + client). `ON DELETE CASCADE` from cards handles cleanup.

---

## Review Data & Sync Strategy

**Problem:** Reviews are append-only, highest-volume table (~100K reviews/year for power users). Two tables serve different purposes:

### `reviews` — capped at 10K most recent per user
- Synced normally, pruned after each session (delete oldest beyond 10K)
- Purpose: per-card review history and FSRS optimizer fuel (needs 1K-10K reviews)

### `review_session_summary` — never pruned, synced
- One row per study session (not per day — we don't know when the user's last session of the day is)
- Volume: ~1-3 rows/day, negligible
- Purpose: powers all historical stats (heatmaps, streaks, rating trends, time-studied)

### FSRS optimizer (not MVP)
- Runs **locally** against the 10K review window. ML-based, replays full log to fit 19 weight parameters.
- Only the 19 floats are synced as user settings, not the review data.

---

## Sync & Auth

**Status:** Phases 1-5 complete. Phase 6 (sync engine) in progress.

**Core principle: Offline-first.** The app works fully without network. Sync is optional — account never required. No network calls until the user explicitly signs in.

### Auth Design

- **No anonymous sign-in.** Users start with `user_id = ''` (local-only). Account creation stamps all local rows via atomic SQLite transaction.
- **Email + password** baseline. **Google + Apple OAuth** planned (Phase 7). Apple Sign-In required by App Store if offering social login.
- **Email confirmation: OTP code (not link-based).** 6-digit code via `verifyOTP(type: OtpType.signup)`. No redirect URLs or polling.
- **Password requirements:** 8+ chars, uppercase, lowercase, digit, special char. Enforced client-side and in Supabase dashboard.
- **Duplicate email sign-up:** Supabase returns fake success to prevent email enumeration. Show generic message regardless: "If an account with this email doesn't exist, we'll send a confirmation link." Do NOT reveal whether the email is registered.
- **Supabase redirect URLs:** Currently localhost — breaks on mobile. Before production: set Site URL to a hosted page or configure deep links.
- **2FA/MFA:** Not implemented. Planned before production (TOTP, optional in settings).

**Phase 5 refactoring needed:**
- Replace `_AuthDisplayState.confirmingEmail` polling with OTP code input field
- Sign-up dialog pre-fills from sign-in form (implemented)

### Sync Engine (Phase 6)

**Architecture — four classes in `lib/core/sync/`:**
- `SyncService` — orchestrator, debounce timer, connectivity listener, pause/resume
- `SyncPushService` — push logic for all tables
- `SyncPullService` — pull logic for all tables
- `SyncRealtimeService` — Supabase Realtime subscription management
- `sync_adapter.dart` — `toSupabaseRow()` / `fromSupabaseRow()` (converts SQLite booleans 1/0 ↔ native true/false, strips/adds `sync_status`)

**Push flow:** Guard (active session?) → query `sync_status = 'pending'` → sequential order: decks → cards → reviews → session_summaries (FK dependency) → upsert to Supabase → `markSynced()` locally. Soft-deleted rows push too (tombstones). If a table fails mid-sequence, already-synced tables keep status; next cycle resumes.

**Pull flow:** Guard → read `last_pull_timestamp` from SharedPreferences → `select().gt('updated_at', lastPull)` per table (sequential, FK order) → for each remote row: no local → insert; local `synced` → overwrite; local `pending` → compare `updated_at` (newer wins). Reviews use `reviewed_at` (immutable, no `updated_at`), insert-only, skip if exists.

**Conflict resolution:** Last-write-wins on `updated_at` — sufficient for single-user app.

**Trigger points:**
- Debounced push 2-5s after any local write
- Pull on app open/foreground + after each successful push
- Manual sync button: push then pull
- Connectivity restore: flush pending pushes
- Realtime: Postgres changes trigger targeted pull

**Study session isolation:** `SyncService.pause()` / `resume()`. During study: pushes queued, Realtime buffered. On session end: flush all.

### Sign-out / Session Handling

- On sign-out: store `user_id` in SharedPreferences. New data still stamped with that `user_id`. Show banner: "You're signed out. Sign in to sync."
- On sign-back-in (same account): sync resumes seamlessly.
- On sign-in (different account): prompt to remove or keep other account's data. Kept data filtered by `user_id`, removable from settings.
- Desktop session expiry: sync pauses, attempt token refresh on next interaction.

### Account Deletion

- **Server:** `ON DELETE CASCADE` wipes all Postgres data.
- **Local:** Prompt — keep study data locally or delete everything? Default: keep. `user_id` reverts to `''`, app returns to offline-only. New account later re-uploads cleanly (PKs are globally unique UUIDs).

### Local Data Management

- **"Delete all data" in settings** — essential on desktop where uninstall doesn't clean up.
- **Per-account deletion** with confirmation. Uninstall varies: iOS/Android auto-clean; macOS/Linux/Windows may leave data.

### Phase 7 (Deferred — Post-Sync Production Hardening)

- OAuth (Google/Apple) — buttons exist as placeholders
- Account deletion Edge Function
- Client-side tombstone purge (7-day rule)
- Review pruning to 10K cap (server-side)
- CAPTCHA client widget (hCaptcha)
- `min_app_version` check before sync
- CI secrets injection for release builds
- OTP code input replacing polling in settings
- Duplicate email sign-up generic messaging
- 2FA/MFA (TOTP)
- Redirect URL fix for password reset
- Cold start frequency tracking / per-user egress monitoring

---

## DeckDetailScreen Layout

Unified list (folders-first), no tabs or toggles. Sub-decks at top with folder styling, section divider with "Cards" label, leaf decks show cards directly. Header: breadcrumb + stats/study row. Mirrors the file-manager pattern.

---

## Packaging & Distribution Dependencies

### Linux (AUR / generic)
- **Runtime:** `gtk3`, `glib2` (GSettings/titlebar theme), `dbus` (theme auto-detection), `sqlite`
- **Build:** `flutter`, `cmake`, `ninja`, `clang`, `pkg-config`, `gtk3` (headers)

### macOS
- **Runtime:** None (bundled in .app) | **Build:** Xcode, CocoaPods

### Windows
- **Runtime:** Visual C++ Redistributable | **Build:** Visual Studio 2022 with C++ desktop workload

### Android / iOS
Standard Flutter mobile toolchains.
