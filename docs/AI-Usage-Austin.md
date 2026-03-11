## TEMPLATE
Date: YYYY-MM-DD
User: [Team member name]
Purpose: [What you're trying to accomplish]
Approach: [How you prompted the AI]
Input Summary: [2-3 sentences on what you provided]
Output Summary: [2-3 sentences on what you got back]
Modifications: [What you changed and why]
Files Referenced: [Links to influenced files]

Date: 2026-01-17
User: Austin
Purpose: Generate LLM prompt for Flutter flashcard app architecture
Approach: Requested prompt incorporating LLM best practices, focusing on offline-first sync architecture and package recommendations for spaced repetition system
Input Summary: Provided application requirements: Flutter, True SRS, offline-first syncing, flashcard management, true-cross-platform, local persistence
Output Summary: Received structured prompt template with package suggestions (GetX for state management, Hive for local storage, Firebase for sync backend, Riverpod as alternative)
Modifications: Adjusted recommended packages to Riverpod + SQLite instead of GetX + Firebase, emphasized need for local-first architecture over cloud-first, refined prompt specificity for our sync protocol
Files Referenced: N/A

Date: 2026-01-18
User: Austin
Purpose: Generate project proposal with timeline and schedule
Approach: Provided rubric criteria and example proposal structure, asked AI to generate proposal aligned with our vision using the template
Input Summary: Supplied project requirements, team size (4 people), timeline constraints, rubric evaluation criteria
Output Summary: Received initial proposal with 8-week timeline, feature phasing, resource allocation, and risk assessment based on rubric
Modifications: Regenerated 3 times - first iteration didn't account for concurrent coursework load, second lacked sufficient detail on sync implementation risks, third better aligned feature priorities with our core vision (sync reliability over UI polish). Final version incorporated our emphasis on robust offline-first design
Files Referenced: proposal.pdf, sample.pdf

Date: 2026-01-30
User: Austin
Purpose: Generate MVP implementation plan for UI development
Approach: Initially prompted for a general implementation plan without specifying my role or ownership areas
Input Summary: Asked for an MVP implementation plan, providing context about the app being a flashcard study app with FSRS algorithm, in-memory only for MVP
Output Summary: Received a broad plan covering all areas (models, state management, study algorithm, UI) without clear ownership boundaries or actionable steps for my specific work
Modifications: Plan was too general - needed to re-prompt with specific role context
Files Referenced: N/A

Date: 2026-01-30
User: Austin
Purpose: Generate role-specific MVP implementation plan for UI + PM responsibilities
Approach: Re-prompted with explicit ownership context - specified I own UI, wiring, and PM duties while other team members own models, state management, and study algorithm
Input Summary: Provided team ownership breakdown, clarified MVP is in-memory only, asked for implementation order and blockers specific to my UI work
Output Summary: Received structured plan with phased implementation order, clear blockers from other team members, mock data strategy to unblock UI work, and coordination checklist for PM duties
Modifications: None needed - plan was actionable and correctly scoped to my responsibilities
Files Referenced: docs/ui-implementation-plan.md

Date: 2026-01-30
User: Austin
Purpose: Implement Phase 1 (Foundation) of UI implementation plan - theme and routing setup
Approach: Worked iteratively with AI to create color palette, theme configuration, routing constants, and GoRouter setup. Used a color preview screen to validate palette before committing.
Input Summary: Requested help starting Phase 1, asked for dark-first color palette that feels "simple, elegant, and friendly", reviewed colors visually before proceeding.
Output Summary: AI generated app_colors.dart with soft violet/warm pink palette optimized for dark theme, app_theme.dart with full ThemeData configuration, routes.dart with path constants and helper methods, app_router.dart with GoRouter and placeholder screens, and updated main.dart with ProviderScope and MaterialApp.router.
Modifications: Initial color palette was light-theme-first with indigo/teal - requested dark-first revision with friendlier colors. AI adjusted to violet/pink palette with layered dark surfaces. Also discussed Flutter idioms (ColorScheme.fromSeed, ThemeExtension) but chose simpler approach for MVP.
Files Referenced: lib/core/theme/app_colors.dart, lib/core/theme/app_theme.dart, lib/core/routing/routes.dart, lib/core/routing/app_router.dart, lib/main.dart

Date: 2026-02-01
User: Austin
Purpose: Implement Phase 2 (Shared Widgets) - reusable UI components and dev tooling
Approach: Asked AI to assess which widgets were truly needed vs Flutter built-ins, then built only what added value. Added debug screen for visual QA during development.
Input Summary: Questioned necessity of each widget, requested dev navigation drawer for testing routes.
Output Summary: Created empty_state_widget, loading_indicator, confirm_dialog, plus a debug preview screen with navigation drawer to test all routes and widget variants.
Modifications: Fixed Flutter API deprecation (CardTheme → CardThemeData), adjusted preview card heights after overflow errors during testing.
Files Referenced: lib/core/widgets/

Date: 2026-02-01
User: Austin
Purpose: Implement Phase 3 (Decks UI) and establish Material Design spacing system
Approach: Built deck list with breadcrumb navigation for nested decks (Option 2 from plan). User requested Material Design compliance, so researched M3 guidelines and created centralized spacing constants.
Input Summary: Requested compact deck cards supporting hierarchy, settings gear with consistent padding, and adherence to Material Design 4dp baseline grid.
Output Summary: Created deck_card.dart, empty_deck_state.dart, deck_list_screen.dart with breadcrumb navigation, and spacing.dart with Material 4dp grid constants. Refactored all widgets to use Spacing constants. Created AppScaffold and DevDrawer as reusable layout components.
Modifications: Initial spacing used arbitrary values - user caught that 4 is valid in Material (4dp baseline, not 8dp). Created spacing.dart to centralize all spacing/radius values for consistency across codebase.
Files Referenced: lib/core/theme/spacing.dart, lib/features/decks/presentation/, lib/core/widgets/app_scaffold.dart, lib/core/widgets/dev_drawer.dart

Date: 2026-02-02
User: Austin
Purpose: Implement study session screen and "Study All" feature for demo-ready MVP
Approach: Focused on core demo flow (deck list → study → stats) with mock data. Iteratively fixed UX issues (layout shift, keyboard shortcuts) and added nested deck aggregation feature.
Input Summary: Requested minimal demo flow: open app, select deck, study cards, see stats. Asked for keyboard shortcuts (Space to flip, 1-4 to rate). Wanted "Study All" to aggregate cards from nested decks like Anki.
Output Summary: Created study_session_screen.dart with card flip, rating buttons, session complete stats, and keyboard support. Added "Study All" bar for folder decks that recursively collects cards from descendants. Updated deck cards to show aggregated counts for folders. Added simple README.
Modifications: Fixed card layout shift by keeping rating buttons always rendered (invisible until answer shown). Removed number labels from rating buttons (looked weird on mobile). Fixed back button crash when nothing to pop. Updated mock data to match actual card counts.
Files Referenced: lib/features/study/presentation/screens/study_session_screen.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/features/decks/presentation/widgets/deck_card.dart, README.md

Date: 2026-02-11
User: Austin
Purpose: Implement SQLite database infrastructure (Issue #34) — foundation for all repository persistence
Approach: Provided a detailed implementation plan to AI covering schema design, library choice (sqflite over drift), and commit strategy. AI implemented step-by-step, verified with tests and static analysis.
Input Summary: Gave comprehensive plan specifying 3 tables (decks, cards, reviews), column types mapped to existing Dart models, partial indexes, FK constraints with cascade deletes, and a singleton DatabaseHelper pattern. Specified sqflite to avoid codegen conflicts with existing domain models.
Output Summary: AI created database_constants.dart (all DDL/column constants), database_helper.dart (singleton with lazy init, FK pragma, batch schema creation, migration loop), and 10 integration tests using sqflite_common_ffi covering table/index existence, FK enforcement, CRUD round-trips, cascade deletes, and soft-delete filtering. All tests pass, flutter analyze clean.
Modifications: AI initially had a sync call to getDatabasesPath() (returns Future) — caught and fixed to async/await. Tests initially failed due to shared singleton state across tests — added database file deletion in tearDown for proper isolation.
Files Referenced: lib/core/database/database_constants.dart, lib/core/database/database_helper.dart, test/core/database/database_helper_test.dart, pubspec.yaml

Date: 2026-02-12
User: Austin
Purpose: Implement DeckRepository, CardRepository, model serialization, and full test suites
Approach: Provided a multi-commit implementation plan for the repository layer. AI implemented repositories with CRUD operations, added toMap/fromMap serialization to domain models, and wrote comprehensive unit tests. Each logical step was a separate commit.
Input Summary: Gave a detailed plan covering: Flashcard.newCard factory + toMap/fromMap, DeckRepository (create, getById, getAll, getChildren, update, soft-delete), CardRepository (same + getDueCards with date filtering), and test suites for both. Specified that tests should use isolated DatabaseHelper.forTesting instances.
Output Summary: AI created DeckRepository with 6 CRUD methods, CardRepository with 7 methods including getDueCards (uses composite index for performance), added toMap/fromMap serialization to both Deck and Flashcard models, and wrote 22 unit tests total. Tests cover round-trip serialization, soft-delete filtering, parent-child queries, due date cutoff logic, and update timestamp bumping.
Modifications: Initial test suite had parallel test conflicts due to shared DB state — fixed by creating unique DB file names per test group using DatabaseHelper.forTesting constructor. Also fixed a test that was checking DateTime equality too strictly (microsecond precision lost in SQLite TEXT storage).
Files Referenced: lib/features/decks/data/deck_repository.dart, lib/features/cards/data/card_repository.dart, lib/features/decks/domain/deck.dart, lib/features/cards/domain/flashcard.dart, test/features/decks/data/deck_repository_test.dart, test/features/cards/data/card_repository_test.dart

Date: 2026-02-12
User: Austin
Purpose: Build CRUD screens (DeckFormScreen, CardFormScreen), wire app router, and replace all mock data with real repository calls
Approach: AI implemented form screens for deck and card create/edit with validation, wired them into GoRouter with proper parameter passing, then systematically replaced mock data in DeckListScreen and StudySessionScreen with real repository queries.
Input Summary: Requested DeckFormScreen (create/edit with name validation, delete with confirmation), CardFormScreen (front/back fields, multi-line, create/edit/delete), router wiring with path parameters and extras, and mock-to-real data migration for existing screens.
Output Summary: AI created both form screens following existing patterns (AppScaffold, ConfirmDialog, GoRouter navigation). Wired all new routes into app_router.dart with proper type casting of extras. Replaced hardcoded mock decks/cards in DeckListScreen with DeckRepository.getAll() + CardRepository hydration. Replaced StudySessionScreen mock cards with CardRepository.getDueCards() across multiple deck IDs.
Modifications: Fixed sqflite_ffi initialization — desktop platforms (Linux/macOS/Windows) need sqfliteFfiInit() + databaseFactory assignment in main.dart before any DB access. Added slide transitions via CupertinoPageTransitionsBuilder for all platforms. Fixed pointer cursor missing on interactive elements (InkWell widgets). Updated pubspec.lock after dependency resolution issues.
Files Referenced: lib/features/decks/presentation/screens/deck_form_screen.dart, lib/features/cards/presentation/screens/card_form_screen.dart, lib/core/routing/app_router.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/features/study/presentation/screens/study_session_screen.dart, lib/main.dart

Date: 2026-02-12
User: Austin
Purpose: Implement DeckDetailScreen and fix multiple UX issues from manual testing
Approach: AI created a detailed plan addressing 6 issues discovered during manual testing: no way to add cards, empty decks going to "Session Complete", no nested deck creation, identical create/edit screens, no duplicate name prevention, and broken transition animations. Plan was reviewed and approved before implementation. Executed as 5 focused commits.
Input Summary: Provided a comprehensive plan specifying DeckDetailScreen (breadcrumb navigation, segmented tab toggle between sub-decks and cards, study button with descendant aggregation, context-dependent FAB), DeckListScreen simplification (root decks only, push to detail), parentId support for nested deck creation, duplicate name validation via nameExistsAtLevel(), and study session navigation fix (context.pop for mid-study exit).
Output Summary: AI created DeckDetailScreen with full breadcrumb navigation, segmented button toggle, aggregated study counts, edit/delete actions, and refresh-on-return pattern. Simplified DeckListScreen from ~290 lines to ~110 lines by removing in-memory navigation stack. Added parentId to DeckFormScreen, nameExistsAtLevel() to DeckRepository (case-insensitive, same-parent-level check), and fixed study exit to use context.pop(). All 22 tests pass, 0 analyzer issues.
Modifications: None needed at this stage — all changes matched the approved plan. However, subsequent manual testing revealed 9 additional UX issues that led to the next session.
Files Referenced: lib/features/decks/presentation/screens/deck_detail_screen.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/features/decks/presentation/screens/deck_form_screen.dart, lib/features/decks/data/deck_repository.dart, lib/core/routing/app_router.dart, lib/features/study/presentation/screens/study_session_screen.dart

Date: 2026-02-12
User: Austin
Purpose: Major UX overhaul of DeckDetailScreen — unified list layout, speed-dial FAB, multi-add cards, animation fixes
Approach: User reported 9 UX issues after manual testing. Entered plan mode to explore options collaboratively. Built a visual comparison page for 3 header layout designs (stats row + TabBar, all-in-one card, minimal inline). User rejected all three and proposed a unified list approach (folders-first, like a file manager) through iterative discussion. Also discussed future requirements (multi-select, card manager, advanced card types) and documented them in CLAUDE.md for future reference.
Input Summary: User provided detailed feedback on 9 issues: (1) leaf decks show empty sub-decks tab, (2) SegmentedButton toggle is ugly/bulky, (3) study button feels disconnected, (4) FAB should offer multiple actions, (5) need multi-add for cards, (6) wasted header space, (7) deep back-navigation causes cascading slide animations, (8) FAB persistence across screens, (9) FAB spin artifact during transitions. Also flagged future needs: card search/filter, bulk move operations, unified card manager, and advanced card types (cloze, image occlusion).
Output Summary: Replaced the segmented tab layout with a unified scrollable list showing sub-decks first, a "Cards" divider, then compact card items (`front → back` single-line with truncation). Consolidated 3 header bars into 2 (breadcrumb + stats/study row with tonal Study button). Created reusable SpeedDialFab widget with animated expand/collapse showing "New Card" and "New Deck" options. Fixed breadcrumb navigation to use context.go() for instant jumps instead of cascading pops. Fixed FAB spin by setting unique heroTag values. Added "Save & Add Another" to CardFormScreen with running card count and auto re-focus. Created CLAUDE.md documenting architecture, future plans for multi-select, card manager, search, and advanced card types.
Modifications: User rejected all 3 initial header designs from the comparison page — found them too heavy or with illegible text. Through discussion, converged on unified list approach (no tabs/toggles at all). User also requested keeping scope simple (no search or multi-select yet) but documenting all future plans in CLAUDE.md for continuity. Removed the temporary header comparison screen after design decision was made.
Files Referenced: lib/features/decks/presentation/screens/deck_detail_screen.dart, lib/core/widgets/speed_dial_fab.dart, lib/features/cards/presentation/screens/card_form_screen.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/core/routing/app_router.dart, CLAUDE.md

Date: 2026-02-12
User: Austin
Purpose: Fix 6 bugs from manual testing and add custom desktop window titlebar
Approach: User reported bugs found during testing. AI fixed each directly — no plan mode needed. For the custom titlebar, AI researched packages (window_manager + modern_titlebar_buttons), verified the user's GTK theme detection on Hyprland via shell queries, and implemented a frameless window with Flutter-rendered controls.
Input Summary: User reported: (1) nested deck card/due counts not aggregating, (2) bulk card creation snackbar stacking and text not clearing, (3) study session "Done" navigating to home instead of deck, (4) duplicate flashcards should warn, (5) wanted native window controls without OS titlebar on Linux. Also asked about duplicate card policy — AI recommended warn-but-allow for same deck, permit across decks.
Output Summary: Added DeckRepository.getDescendantIds() for recursive count aggregation across both screens. Fixed bulk card creation by removing snackbar (counter indicator is sufficient), moving field clearing inside setState, and adding CardRepository.frontExistsInDeck() with a duplicate warning dialog. Changed study "Done" from context.go('/') to context.pop(). Added window_manager (frameless window) + modern_titlebar_buttons (auto-themed controls with Adwaita fallback) with a WindowTitleBar widget injected via MaterialApp builder. Documented packaging dependencies (AUR/Linux runtime and build deps) in CLAUDE.md.
Modifications: Initial titlebar had the entire bar wrapped in a GestureDetector for drag, which swallowed button hover/click events — restructured so only the title area is draggable. Text had yellow-underline issue from missing Material ancestor — wrapped in Material widget. Button hover states still limited on Wayland/Hyprland (known package limitation, deferred).
Files Referenced: lib/features/decks/data/deck_repository.dart, lib/features/decks/presentation/screens/deck_detail_screen.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/features/cards/data/card_repository.dart, lib/features/cards/presentation/screens/card_form_screen.dart, lib/features/study/presentation/screens/study_session_screen.dart, lib/core/widgets/window_title_bar.dart, lib/main.dart, CLAUDE.md

Date: 2026-02-13
User: Austin
Purpose: Fix desktop page transition stutter and loading spinner flash during navigation
Approach: Entered plan mode to design platform-conditional transitions. After implementation, user noticed a "zoom from center" feel from the scale component — researched standard desktop transition patterns and simplified to a pure crossfade. Then investigated remaining jank (spinner flash) by tracing the loading state pattern across screens. AI researched Flutter best practices for loading states during transitions and recommended "optimistic initial render" pattern.
Input Summary: User reported sluggish page transitions on Linux/Wayland desktop. CupertinoPageTransitionsBuilder was animating two full widget trees at 400ms. After fixing transitions, user noticed a brief LoadingIndicator flash during the fade-in caused by screens showing a spinner while SQLite queries completed (~20-50ms).
Output Summary: Created page_transitions.dart with buildPage() helper — 150ms crossfade on desktop, MaterialPage on mobile. Converted all 8 GoRouter routes from builder to pageBuilder. Updated theme fallbacks (FadeUpwards on desktop, Cupertino on iOS, Zoom on Android). Extracted isDesktop getter to shared location. Eliminated loading spinner flash by removing _initialLoad gating — screens now render immediately with passed deck data (optimistic UI), and lists populate asynchronously without a spinner. Fixed breadcrumb navigation to pass deck objects via extra for instant render. DeckListScreen uses SizedBox.shrink() instead of LoadingIndicator during initial load.
Modifications: Initial implementation included a ScaleTransition (0.97→1.0) which gave an unwanted "zoom from center" feel — user flagged it as non-native for desktop. Removed scale, kept pure FadeTransition only. User also flagged the spinner flash as a separate issue — researched and implemented optimistic rendering pattern (standard approach used by Anki mobile and production Flutter apps).
Files Referenced: lib/core/routing/page_transitions.dart, lib/core/routing/app_router.dart, lib/core/theme/app_theme.dart, lib/main.dart, lib/features/decks/presentation/screens/deck_detail_screen.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, CLAUDE.md

Date: 2026-02-14
User: Austin
Purpose: Document tester feedback and create GitHub issues for bug tracking
Approach: Tester (Ethan) provided detailed bug reports and UX suggestions via Discord. AI parsed the conversation, categorized findings into bugs vs. enhancements vs. confirmed-working behavior, and updated project documentation.
Input Summary: Provided full Discord conversation between Austin and tester covering: "Save & Add Another" bug with detailed repro steps by deck type, cascade soft-delete failures on nested decks/cards, dev menu not refreshing UI, misleading empty deck study message, and UX suggestions (keyboard submit, char limits, context menus, keyboard nav).
Output Summary: Updated CLAUDE.md Known Bugs section with detailed repro steps (replacing vague race condition theory with tester's empty-deck-dependent findings), added new bugs (cascade soft-delete, dev menu refresh, empty deck study message), added UX Improvements section, and added Tester-Verified Behavior section documenting what passed. Created 9 GitHub issues (#44–#52) with appropriate labels (bug, enhancement, UI/UX, ORM/database, etc.) and assignees. Added issue reference numbers inline in CLAUDE.md for quick lookup.
Modifications: Replaced the original "Save & Add Another" bug description — tester's repro proved the root cause is tied to empty vs. populated decks, not input speed. Combined the two cascade soft-delete issues (nested decks + their cards) into a single issue (#46) since the fix is one recursive transaction.
Files Referenced: CLAUDE.md

Date: 2026-02-14
User: Austin
Purpose: Comprehensive performance audit of codebase — database, repositories, UI, and packages
Approach: AI explored the full codebase (every file in lib/) and performed a deep audit of database query patterns, repository methods, presentation layer data loading, widget lifecycle issues, and dependency configuration. Ranked findings by impact.
Input Summary: Requested a thorough performance review with emphasis on database usage and repositories. Asked for findings ranked by impact with difficulty ratings and brief solution descriptions.
Output Summary: Identified 14 performance issues. Top findings: N+1 query explosion from fetching full Flashcard objects just to count them (#53), recursive Dart-side tree walk for descendant IDs instead of SQL CTE (#54), client-side filtering of all decks (#55), double-fetch of cards in DeckDetailScreen (#56), FocusNode leak in study screen (#57), sequential card loading (#58), _dbName field ignored in DatabaseHelper (#59), and several lower-impact items (missing transactions, dead model fields, animation object leaks, unbatched inserts, no pagination, duplicate dep).
Modifications: None — audit only, no code changes.
Files Referenced: All files in lib/ reviewed. Findings documented in CLAUDE.md under "Performance Bottlenecks" section.

Date: 2026-02-14
User: Austin
Purpose: Create GitHub issues from audit, update project board, and trim verbose older issues
Approach: AI created 14 GitHub issues (#53–#66) from the audit findings with concise descriptions, proper labels (created new "performance" label), and assignees based on team ownership rules. Added all to project board with Priority (P0/P1/P2) and Size (XS–L). Also trimmed verbose issue bodies on #44–#52 from prior session.
Input Summary: Provided team assignment rules: Pairadux (DB, repos, UI, PM), GADudley (models), djanderson26 (study session/services). Requested issues be concise, not include full solutions.
Output Summary: Created 14 issues: 10 assigned to Pairadux, 2 to djanderson26 (#57, #58), 1 to GADudley (#62). Set project board fields — P0: #46, #53, #54; P1: #44, #45, #49, #51, #55–#59; P2: #47, #48, #50, #52, #60–#66. Trimmed #44–#52 bodies to match concise style. Updated CLAUDE.md with performance section referencing all issue numbers.
Modifications: First issue (#53) was too verbose with full code solutions — user requested concise style, subsequent issues followed that pattern. Trimmed all 9 older issues (#44–#52) to match.
Files Referenced: CLAUDE.md

Date: 2026-02-27
User: Austin
Purpose: Convenience model factories and edge case mock data (feat/mock-data-edge-cases branch, #23)
Approach: AI added `Deck.create()` and updated `Flashcard.newCard()` to auto-generate UUIDs and timestamps, eliminating boilerplate at call sites. Added programmatic edge case mock data to DevDrawer. User prompted discussion about removing dead `cards`/`cardCount`/`dueCount` fields from Deck model — decided to leave for GADudley (#62) to avoid merge conflicts.
Input Summary: User requested sensible factory defaults so callers don't manually create UUIDs/timestamps. Also requested edge case mock data for UI stress testing. User guided decision to keep model cleanup separate.
Output Summary: Created `Deck.create()` factory, removed `cardId` param from `Flashcard.newCard()`. Updated all callers (CardFormScreen, DeckFormScreen, DevDrawer) — removed uuid imports where no longer needed. Added edge case mock data: 8-level deep nesting, max-length content (50/300 chars), 200-card bulk deck, single-character minimal content. Updated CLAUDE.md with audit state and resolved issues.
Modifications: None beyond scope adjustments per user guidance.
Files Referenced: lib/features/decks/domain/deck.dart, lib/features/cards/domain/flashcard.dart, lib/core/widgets/dev_drawer.dart, lib/features/decks/presentation/screens/deck_form_screen.dart, lib/features/cards/presentation/screens/card_form_screen.dart, CLAUDE.md
Purpose: Input validation and content limits (feat/input-validation branch, #50)
Approach: AI added character limits to deck name (50) and card front/back (300) fields with MaxLengthEnforcement.enforced. Discussed limit tradeoffs with user — balanced flashcard brevity against future Supabase sync bandwidth. Added vertical scrollability to study screen card content.
Input Summary: Requested input constraints at UI layer. User guided character limit decisions — rejected 500 and 1000 as too high given sync considerations, settled on 300 for cards.
Output Summary: Added maxLength + enforced truncation to DeckFormScreen (50 chars) and CardFormScreen (300 chars with visible counter). Wrapped study screen card text in SingleChildScrollView. Verified existing empty-input validators and card preview truncation are already correct.
Modifications: Character limit adjusted from initial 500 to 300 based on user feedback about Supabase sync bandwidth.
Files Referenced: lib/features/decks/presentation/screens/deck_form_screen.dart, lib/features/cards/presentation/screens/card_form_screen.dart, lib/features/study/presentation/screens/study_session_screen.dart
Purpose: MVP audit and critical bug triage (fix/audit-bugs branch)
Approach: AI performed full codebase audit against MVP requirements (usable UI, persistent state, working FSRS). Read every source file, traced data flows end-to-end, identified blockers. Fixed self-contained bugs in scope (UI, database infra); filed GitHub issues for out-of-scope items with correct team assignments.
Input Summary: Requested comprehensive audit of state management wiring, persistence end-to-end, FSRS integration, and route completeness. Specified team ownership boundaries — Austin owns UI/repos/PM, GADudley owns models/providers, Darius owns FSRS.
Output Summary: Fixed DatabaseHelper._dbName (#59), clearAllData() transaction (#60), SpeedDialFab CurvedAnimation leak (#63), and breadcrumb overflow handling. Filed 4 new issues (#74–#77) for out-of-scope blockers. Closed 9 resolved issues (#46–#48, #53–#55, #57–#60, #63). Assigned backlog items to team members.
Modifications: None — fixes were straightforward and matched audit findings.
Files Referenced: lib/core/database/database_helper.dart, lib/core/widgets/speed_dial_fab.dart, lib/features/decks/presentation/screens/deck_detail_screen.dart

Date: 2026-03-02
User: Austin
Purpose: Fix FSRS integration — step field persistence, state mapping, and session re-queue (fix/fsrs-integration branch, #74/#75)
Approach: AI explored the FSRS library source to understand Card fields (state, step) and reviewCard() return type, then implemented fixes across the data layer, service, and UI. User guided design decisions on re-queue behavior (append to end vs. inline) and progress bar strategy (unique graduations vs. clamp vs. raw index).
Input Summary: Provided a detailed implementation plan covering 4 issues: step field never persisted, card state hardcoded by rating instead of read from FSRS output, elapsedDays/scheduledDays manually computed, and learning/relearning cards dropped from session instead of re-shown. User clarified re-queue should append to end (Anki-style), and progress bar should track unique card graduations.
Output Summary: Added nullable `step` field to Flashcard model with sentinel-based copyWith (to distinguish "not set" from "set to null"). Added DB column + v1→v2 migration. Rewrote FsrsService to pass state+step to FSRS library for non-new cards and read state+step from result (deleted hardcoded _updateCardState method). Added re-queue logic in StudySessionService — learning/relearning cards appended to session end. Updated study screen to sync cards from session, track graduated card IDs for progress bar. Added step to debug panel snapshot and diff table.
Modifications: User asked about migration necessity — kept it since it's cheap insurance for testers with existing v1 databases. User asked about queue vs. list for re-queue — kept list approach since dead entries are trivially small for session-scale data and StudySession is an immutable Equatable.
Files Referenced: lib/features/cards/domain/flashcard.dart, lib/core/database/database_constants.dart, lib/core/database/database_helper.dart, lib/features/study/application/fsrs_service.dart, lib/features/study/application/study_session_service.dart, lib/features/study/presentation/screens/study_session_screen.dart

Date: 2026-03-05
User: Austin
Purpose: Redesign study session screen with swipe-to-rate, card stack visual, flip animation, and gradient background (feat/study-swipe branch)
Approach: Discussed design goals in detail before implementation — user described a Tinder-style swipe system for mobile rating, a card stack illusion matching the Lapse logo's offset-echo aesthetic, and a radial gradient background using the app's primary/secondary colors. AI asked 6 clarifying questions (swipe direction mapping, flip-then-rate flow, desktop unchanged, shadow card count, flip direction, scope). User confirmed all choices. AI drafted a full plan, user approved, then implemented iteratively with user testing each visual tweak live.
Input Summary: User wanted mobile-friendly study sessions (current tiny buttons are unusable on phones). Specified: swipe-to-rate on touch only (right=Good, left=Hard, up=Easy, down=Again), tap-to-flip-then-swipe flow, horizontal 3D flip animation, card stack with shadow cards behind the active card, radial gradient background (violet bottom-left, pink top-right). Desktop keeps keyboard shortcuts and button row unchanged.
Output Summary: Created 3 new widgets: FlipCard (250ms horizontal 3D flip with midpoint content swap to avoid mirroring), SwipeableCard (pan gesture with free drag, rotation, scale-up "coming forward" effect, rating label overlay, 25% threshold commit, snap-back or fly-off animations), CardStack (dual radial gradient background + 1-2 foreshortened shadow cards). Refactored study_session_screen.dart to compose these widgets — FlipCard universal, SwipeableCard touch-only via isDesktop check, CardStack wrapping the card area. Desktop retains button row and keyboard shortcuts. Updated CLAUDE.md with full design documentation.
Modifications: Gradient opacity went through 3 iterations — started at ~19%/15% (invisible), bumped to 50%/44%, then to 75%/75% per user feedback. Shadow cards went through 5 iterations: (1) Positioned.fill + Transform.translate bled through on all sides due to Card border radius, (2) Positioned with inset top/left made cards appear bigger not offset, (3) ClipRect killed border radius, (4) explicit width/height from LayoutBuilder with same-size offset worked but shadow was hard to distinguish, (5) final approach: slightly smaller shadow cards (97.5% and 95%) anchored bottom-right with foreshortened depth effect — user approved. Reduced from 2 shadow cards to 1 during iteration, then brought second back once the approach was working. Added ValueKey on FlipCard keyed to currentIndex to prevent reverse-flip animation when advancing cards. Fixed Matrix4 deprecation warnings (translate → translateByDouble, scale → scaleByDouble with correct 4-arg signatures found in Flutter docs).
Files Referenced: lib/features/study/presentation/widgets/flip_card.dart, lib/features/study/presentation/widgets/swipeable_card.dart, lib/features/study/presentation/widgets/card_stack.dart, lib/features/study/presentation/screens/study_session_screen.dart, CLAUDE.md

Date: 2026-03-06
User: Austin
Purpose: Fix study session visual bugs and polish swipe-to-rate UX (feat/study-swipe branch)
Approach: User provided a prioritized list of visual bugs and UX issues from testing the swipe-to-rate implementation. AI analyzed each issue, proposed a priority order, and implemented fixes iteratively with user feedback on design decisions (shadow card content, flip axis, animation settings).
Input Summary: User reported 8 issues: (1) card shows front during dismiss animation, (2) flip animation jarring on wide screens, (3) shadow card corner radius mismatch, (4) rating buttons flash to full opacity at last frame of dismiss, (5) rating label hard to see over card text on mobile, (6) vertical swipe threshold too high, (7) "swipe to rate" hint removal verification, (8) tutorial popup needed for first launch. Also requested notes for reduced motion setting, new card daily limit, and splash screen dark mode.
Output Summary: Fixed dismiss timing by resetting `_dismissOffset` atomically inside `_rateCard`'s setState (fixes both card-shows-front and button-flash issues). Added key to SwipeableCard per card index so old state stays off-screen until parent swaps. Fixed shadow card radius from hardcoded 12 to `Spacing.radiusLg` (16) matching CardThemeData. Made flip axis adaptive — rotateY (horizontal) in portrait, rotateX (vertical) in landscape, based on aspect ratio. Added semi-opaque background to swipe rating labels for readability. Split swipe commit threshold into separate H (25%) and V (20%) values. Created GH issue #109 for tutorial popup. Updated CLAUDE.md with notes for: tutorial popup, shadow card content decision (keep blank, future crossfade), reduced motion setting, new card daily limit, and splash screen dark mode.
Modifications: User rejected maxWidth constraint on card area (would leave dead space on large screens) — switched to adaptive flip axis instead. User tested vertical-only flip and found it awful on mobile portrait — changed to aspect-ratio-based axis selection. User discussed showing next card content on shadow cards — decided against (study integrity issue on mobile where drag reveals content), documented blank shadow as preferred with future crossfade entrance animation.
Files Referenced: lib/features/study/presentation/screens/study_session_screen.dart, lib/features/study/presentation/widgets/swipeable_card.dart, lib/features/study/presentation/widgets/flip_card.dart, lib/features/study/presentation/widgets/card_stack.dart, CLAUDE.md, docs/AI-Usage-Austin.md

Date: 2026-03-08
User: Austin
Purpose: General bug fixes and UX improvements from QA feedback (fix/general-fixes branch, PR #115)
Approach: User provided QA tester feedback alongside their own bug reports and feature notes. AI triaged all issues by priority, categorized what to fix now vs. defer as GitHub issues, investigated root causes, and implemented fixes iteratively. User reviewed each fix and rejected proposals that didn't address root causes (e.g., opacity flash fix, card-shows-front fix), prompting deeper analysis.
Input Summary: User reported: (1) dev menu broken after release gating refactor, (2) nested deck deletion navigates to wrong screen, (3) card save has no feedback, (4) shadow card animations missing on mobile. QA tester reported: scrollbar not grabbable on Windows, Study button not sticky, card edit save gives no confirmation. User also provided a full audit of study session visual bugs: rating button opacity flash, card showing front during dismiss, and several already-fixed items.
Output Summary: Implemented 8 fixes across 8 commits: restored kDebugMode-gated dev drawer in AppScaffold (was removed entirely, not just gated), fixed nested deck deletion to navigate to parent via ancestors list instead of context.pop(), guarded dismiss animation listener against no-op setState calls to prevent rating button opacity flash, added ValueKey to CardStack's top card Positioned to prevent FlipCard state destruction when phantom shadow card insertion shifts Stack child indices, added snackbar feedback on card save with bulk count from "Save & Add Another", added PopScope-based snackbar when pressing back after bulk creation, piped SwipeableCard commit progress into CardStack via onDismissProgress callback for mobile shadow card animations, removed bottom spacer from mobile study screen. Created 3 GitHub issues for deferred items (#112 splash screen, #113 sticky header, #114 Windows scrollbar).
Modifications: User rejected initial opacity flash fix (removing trailing controller.reset()) — prompted deeper analysis. AI added a guard in the animation listener to prevent redundant setState when value hasn't changed, which is a more principled fix. User rejected initial card-shows-front diagnosis (FlipCard flip during fast swipe) — clarified it happens on desktop even with slow interaction. AI performed deep analysis of Flutter's Stack child reconciliation and discovered the real root cause: phantom shadow card conditional insertion shifts child indices, and without keys Flutter destroys the FlipCard state at the old index and creates a new one (controller at 0.0, showing front). Fixed by adding ValueKey to the top card's Positioned wrapper.
Files Referenced: lib/core/widgets/app_scaffold.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/features/decks/presentation/screens/deck_detail_screen.dart, lib/features/study/presentation/screens/study_session_screen.dart, lib/features/study/presentation/widgets/card_stack.dart, lib/features/study/presentation/widgets/swipeable_card.dart, lib/features/cards/presentation/screens/card_form_screen.dart

Date: 2026-03-08
User: Austin
Purpose: Remove "Swipe to rate" hint text from mobile study screen
Approach: User provided a list of UX issues from testing notes. AI triaged all items by difficulty, selected the simplest fix (removing the jarring "Swipe to rate" popup), and implemented it directly.
Input Summary: User provided 8 UX issues covering mobile and general study session bugs. The "swipe to rate" hint text was identified as unnecessary given a planned first-launch tutorial and jarring when it appeared/disappeared during study.
Output Summary: Removed the conditional "Swipe to rate" Text widget and its Padding wrapper from the mobile branch of the study session layout, replaced with a simple SizedBox spacer to maintain consistent spacing below the card area.
Modifications: None — straightforward deletion of ~15 lines.
Files Referenced: lib/features/study/presentation/screens/study_session_screen.dart

Date: 2026-03-09
User: Austin
Purpose: Visual polish and UX improvements — debug gating, haptics, splash screen, card form redesign, markdown fixes (fix/polish-and-ux branch)
Approach: User requested a triage of open polish issues from CLAUDE.md. AI explored the codebase to assess which issues were still open vs. already resolved, presented a prioritized list, and implemented fixes iteratively across 8 commits. User guided design decisions on haptic scope, card form preview toggle UX, and splash screen icon inclusion.
Input Summary: User wanted to clean up minor visual and polish issues before tackling sync features. Provided notes on 3 new issues (debug menu in release, nested deck deletion nav, card edit preview pane). AI cross-referenced CLAUDE.md issues with actual code state and identified 6 actionable items. User approved priority order and provided UX guidance: edit/preview toggle via icon in app bar, buttons pinned at bottom, tappable preview hint near markdown reference for discoverability, light haptics on save buttons, no haptics on routine navigation taps.
Output Summary: Implemented 8 changes: (1) gated study screen debug panel behind kDebugMode, (2) added haptic feedback — light impact on card flip and save buttons, medium impact on swipe commit and rating buttons, (3) dark splash screen (#0F0F14) with centered app icon on Android (pre-v21 and v21+) and iOS (replaced 1x1 pixel placeholders with real icon assets at 1x/2x/3x), (4) redesigned card form with app bar edit/preview icon toggle replacing the inline preview pane that pushed buttons off-screen on mobile — edit and preview are separate builder methods for future card type extensibility, (5) pinned action buttons at bottom with SafeArea, (6) fixed Save & Add Another not refocusing front field via post-frame callback, (7) fixed bold invisible in study screen markdown (paragraph style was w600, bold is w700 — reset to normal weight), (8) added url_launcher for clickable markdown links in study and preview screens, (9) expanded markdown hint text with tappable "Preview" shortcut link for toggle discoverability.
Modifications: User rejected haptics on deck list taps (too noisy for routine navigation). User requested the preview toggle be more discoverable — added an inline tappable "Preview" label with eye icon next to the markdown syntax hint, acting as a secondary entry point to preview mode. User caught that bold text was invisible on study cards — traced to headlineSmall's w600 weight making bold (w700) indistinguishable, fixed by resetting paragraph weight to normal. User requested links actually open in browser — added url_launcher dependency.
Files Referenced: lib/features/study/presentation/screens/study_session_screen.dart, lib/features/study/presentation/widgets/flip_card.dart, lib/features/study/presentation/widgets/swipeable_card.dart, lib/features/cards/presentation/screens/card_form_screen.dart, lib/features/decks/presentation/screens/deck_form_screen.dart, android/app/src/main/res/drawable/launch_background.xml, android/app/src/main/res/drawable-v21/launch_background.xml, ios/Runner/Base.lproj/LaunchScreen.storyboard, ios/Runner/Assets.xcassets/LaunchImage.imageset/, CLAUDE.md

Date: 2026-03-09
User: Austin
Purpose: Navigation stack overhaul — hierarchical back button, RouteAware optimization, breadcrumb/stats flicker elimination (fix/polish-and-ux branch, continued)
Approach: User reported breadcrumb navigation issues (back button going to unexpected screens after breadcrumb jumps) and requested that the nav stack always mirror the deck hierarchy. AI researched GoRouter's stack-building capabilities via web search, confirmed no native API exists for dynamic-depth stack construction, and implemented a `go()` + sequential `push()` workaround. Then added RouteAware for deferred loading, and passed ancestors/counts via extra to eliminate visual flicker. User challenged AI on whether the approach was idiomatic; AI provided honest assessment distinguishing idiomatic patterns from pragmatic workarounds.
Input Summary: User wanted back button and swipe-back to always navigate up the deck tree, not back through visit history. Reported two runtime bugs during testing: (1) `_scrollBreadcrumbToEnd` crashing with "Null check operator used on a null value" when tapping through nested decks quickly (dozens of exceptions), (2) breadcrumb and stats row visually resetting on every navigation. User also asked whether the approaches were idiomatic or "hacky", and whether state management gaps were the root cause.
Output Summary: Implemented hierarchical navigation via `go(home)` + sequential `push()` for breadcrumb taps and deck deletion. Added global RouteObserver + RouteAware mixin to DeckDetailScreen for deferred loading (intermediate screens skip _loadData until visible) and automatic reload on child route pop (replacing all manual `await push(); _loadData()` patterns). Fixed scroll crash by adding `hasContentDimensions` guard. Eliminated breadcrumb flash by passing ancestors via extra. Eliminated stats flicker by passing card/due counts via extra. Made burger menu icon always visible in release (was incorrectly gated behind kDebugMode). Bumped iOS splash icon from 128pt to 192pt. Created GH issue #119 for typed DeckRouteExtra class and eventual Riverpod cache to fix upward-navigation count flicker.
Modifications: **AI introduced a crash that required user-reported debugging.** When AI changed the navigation `extra` format from `Deck?` to `Map<String, dynamic>` (to carry ancestors and counts), the sub-route pageBuilders in `app_router.dart` still used hard casts (`state.extra as Deck?`). This caused a `_TypeError: type '_Map<String, Object>' is not a subtype of type 'Deck?'` crash at runtime because GoRouter sub-routes can inherit the parent route's extra object. The AI had not accounted for the fact that changing the extra format on the parent route would break all sub-routes that assumed the old format. User reported the crash, and AI fixed it by replacing hard `as` casts with defensive `is` type checks and null fallbacks across all sub-routes. This was a clear oversight — the AI should have audited all consumers of `state.extra` before changing its shape, not just the parent route's pageBuilder. User also flagged upward breadcrumb count flicker; AI explained this is architecturally unsolvable without shared state (child screens don't know ancestor counts) and created an issue for the Riverpod-based fix.
Files Referenced: lib/features/decks/presentation/screens/deck_detail_screen.dart, lib/core/routing/app_router.dart, lib/core/routing/route_observer.dart, lib/core/widgets/app_scaffold.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, ios/Runner/Assets.xcassets/LaunchImage.imageset/

Date: 2026-03-11
User: Austin
Purpose: Set up Supabase Flutter SDK integration, dev screen for connection testing, and plan sync schema (#94, #8)
Approach: User wanted to get sync "working" or at least progressing. AI reviewed all open GH issues, mapped the sync dependency chain, identified unblocked work, and started with #94 (Supabase SDK setup). AI proposed compile-time credentials via `--dart-define-from-file`, user approved. Iterative debugging of Realtime WebSocket issues (macOS sandbox entitlements, broadcast self-echo). User drove decisions on credential strategy, justfile setup, and schema planning. AI created a sync schema plan doc for future sessions.
Input Summary: User had a Supabase project created but nothing configured in the app. Wanted to understand the sync roadmap, start on foundational setup, and validate cross-device communication. Provided feedback during testing — Realtime channel stuck on "connecting" (traced to missing macOS network.client entitlement), broadcast messages not appearing in UI (traced to nested ListView rendering issue). User also caught that Supabase deprecated anon keys in favor of publishable keys (sb_publishable_) and requested the update.
Output Summary: Implemented: (1) added `supabase_flutter` dependency, (2) created `SupabaseConfig` class with compile-time credentials via `String.fromEnvironment`, (3) created `env.json` (gitignored) and `env.example.json` template with new publishable key format, (4) added `justfile` with common flutter commands (all builds include `--dart-define-from-file=env.json`), (5) wired `SupabaseConfig.initialize()` in `main.dart` before `runApp()`, (6) built `SupabaseDevScreen` with connection health check, auth status display, and Realtime broadcast echo for cross-device testing, (7) added macOS `com.apple.security.network.client` entitlement to both debug and release (required for WebSocket connections), (8) added channel subscription status indicator and replaced nested ListView with Column for reliable re-rendering, (9) planned v4 SQLite migration (reviews autoincrement → UUID) and full Supabase Postgres schema in `memory/sync-schema-plan.md`, (10) created GH issue #130 for splash screen text logo. Successfully tested cross-device Realtime broadcast between macOS, iOS, and a friend's laptop.
Modifications: User caught that `env.json` still used old `SUPABASE_ANON_KEY` naming — AI searched and confirmed Supabase deprecated legacy keys, updated to `SUPABASE_PUBLISHABLE_KEY`. User questioned whether exposing a `url` getter on `SupabaseConfig` was idiomatic — AI initially second-guessed, then confirmed it's the right approach (single source of truth for credential access). User identified that Realtime "connecting" status never resolved — AI traced to missing `com.apple.security.network.client` macOS entitlement (REST worked via NSURLSession exemption, but raw WebSockets were blocked by App Sandbox). User confirmed this is normal for Flutter macOS apps.
Files Referenced: lib/core/supabase/supabase_config.dart, lib/core/supabase/supabase_dev_screen.dart, lib/main.dart, lib/core/routing/app_router.dart, lib/core/routing/routes.dart, lib/core/widgets/dev_drawer.dart, macos/Runner/DebugProfile.entitlements, macos/Runner/Release.entitlements, .gitignore, env.example.json, justfile, pubspec.yaml

Date: 2026-03-11
User: Austin
Purpose: Execute Phase 1 of sync schema plan — v4 SQLite migration (reviews UUID primary key)
Approach: AI read the sync schema plan from memory, audited all four affected files (DatabaseConstants, Review model, ReviewRepository, DatabaseHelper), then implemented the migration. User challenged the `colReviewId` naming — AI explained it matches the `deck_id`/`card_id` convention. User caught that heredoc syntax in git commit was causing `.git/index.lock` issues — added global rule to never use heredoc for commits. After the migration, AI audited `updated_at` handling across all repositories — found everything already covered (creates via factory, updates via `copyWith`, deletes via raw map). User raised question about review immutability and soft-delete purge strategy — AI proposed a purge rule using `sync_status` and `user_id` to prevent offline conflicts, documented in CLAUDE.md for team review.
Input Summary: User said "lets start on the plan" referencing the sync schema plan in AI memory. During implementation, user asked about the `colReviewId` naming choice, whether removing `_ratingToInt`/`_stateToInt` helpers would break anything, whether Dart-side `updated_at` setting is idiomatic, and whether reviews should be purged when parent cards are deleted. User also identified git heredoc issues and requested a global memory rule.
Output Summary: Implemented v4 SQLite migration: (1) bumped `DatabaseConstants.databaseVersion` to 4, (2) renamed `colId` to `colReviewId` with value `'review_id'`, (3) changed reviews DDL from `INTEGER PRIMARY KEY AUTOINCREMENT` to `TEXT PRIMARY KEY`, (4) added `reviewId` field to Review model with auto-generated UUID v4, updated constructor/copyWith/toMap/fromMap/Equatable props, (5) simplified ReviewRepository.addReview to use `review.toMap()` instead of hand-built map, removed redundant helper methods, (6) added `_migrateV4` to DatabaseHelper — creates `reviews_v2` table, copies existing rows with generated UUIDs, drops old table, renames, recreates indexes, (7) updated test to provide `review_id` and assert on `colReviewId`. Full `updated_at` audit confirmed all write paths already set timestamps correctly. Proposed soft-delete purge strategy documented in CLAUDE.md.
Modifications: User caught that heredoc syntax caused repeated `.git/index.lock` failures — switched to simple `-m "message"` and added permanent rule to `~/.claude/CLAUDE.md`. User questioned whether `_ratingToInt`/`_stateToInt` removal would break things — AI verified via grep they had no other callers since `toMap()` handles the same conversion. No other modifications needed.
Files Referenced: lib/core/database/database_constants.dart, lib/core/database/database_helper.dart, lib/features/study/data/review_repository.dart, lib/features/study/domain/review.dart, test/core/database/database_helper_test.dart, CLAUDE.md
