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
