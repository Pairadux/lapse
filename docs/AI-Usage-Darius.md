## TEMPLATE

Date: YYYY-MM-DD
User: [Team member name]
Purpose: [What you're trying to accomplish]
Approach: [How you prompted the AI]
Input Summary: [2-3 sentences on what you provided]
Output Summary: [2-3 sentences on what you got back]
Modifications: [What you changed and why]
Files Referenced: [Links to influenced files]

Date: 2026-01-27
User: Darius Anderson
Purpose: Make the FSRS algorithm understandable for the group. Provide a implementation plan for the algorithm
Approach: Requested an explanation on how the algorithm works, what data it needs, how to implement it. Asked for both and in depth explanation and a simple explanation.
Input Summary: Supplied the fsrs.dart file
Output Summary: Recieved markdown files of a deeper dive into the algorithm, such as the math behind it and such, as well as an implementation guide, both containing various implementation tactics and information.
Modifications: N/A
Files Referenced: fsrs_deep_dive.md, fsrs_implementation_guide

Date: 2026-02-01
User: Darius Anderson
Purpose: Creating a guideline for what the FSRS wrapper should do in fsrs_service and study_session_service
Approach: Requested a guideline on how to create a wrapper for each flashcard and how to use that wrapper for study sessions.
Input Summary: Provided the file dependencies (fsrs_service relying on flashcard and study_session_service relying on fsrs_service)
Output Summary: Received a guideline on what the wrapper should do and why to base it on the cards themselves and not the deck. Received the relationships between fsrs_service and study_session_service.
Modifications: N/A
Files Referenced: fsrs_service.dart, study_session_service.dart, README.md

Date: 2026-02-01
User: Darius Anderson
Purpose: Error correction in fsrs_service and study_session_service
Approach: Provided the error types and asked how I would go about fixing them
Input Summary: Provided the prompt and error message types.
Output Summary: Recieved a simplified response on what the errors were and what was the problem in the code.
Modifications: Fixed some small things, such as what types were being returned and what fields were needed to match the ones the cards had and what scheduling data was needed.
Files Referenced: fsrs_service.dart, study_session_service.dart

Date: 2026-02-08
User: Darius Anderson
Purpose: Task completion planning and requirement scoping
Approach: Provided the project manager's Sprint 2 instructions and asked for guidelines and a dependency analysis
Input Summary: Provided the list of requirements and asked which parts can be built before the UI or state management were completed
Output Summary: Recieved information that the repository and models could be built and tested using SQLite instance using a bottom-up approach, where the Database, Repository, and Service are tackled sequentially.
Modifications: I decided to fix focus on the Review models and Repository first
Files Referenced: review.dart, review_repository.dart, study_session_service.dart, review_repository_test.dart

Date: 2026-02-10
User: Darius Anderson
Purpose: Architecture scaffolding and database integration
Approach: Requested skeletons to ensure things aligned with DatabaseHelper
Input Summary: I asked for a ReviewRepository skeleton without the logic (so that I could complete it) and an explanation on the DatabaseHelper pattern. Also asked for TODOs to ensure FSRS persistence
Output Summary: Recieved a class skeleton with empty Future methods for CRUD, an explanation on how DatabaseHelper manages the connection, and logic flow for saving cards after FSRS processing
Modifications: Added helper methods for Enum to Int conversion
Files Referenced: review_repository.dart, database_helper.dart

Date: 2026-02-13
User: Darius Anderson
Purpose: Unit test implementation and debugging
Approach: Provided failing test logs and requested boilerplate for a comprehensive test suite
Input Summary: I asked for a skeleton for the ReviewRepository test and shared console errors when "Actual" row count exceeded "Expected" row count
Output Summary: Recieved a test suite containing sqflite_common_ffi, and an explanation on why the test file showed a "State Pollution" error where test data was being stored for each run instead of being wiped. Suggested solving it using a setUp or :memory: database
Modifications: Implemented the db.delete(table) and turned foreign keys off to allow the tests to run without needing valid Card Ids
Files Referenced: review_repository_test.dart

Date: 2026-02-14
User: Darius Anderson
Purpose: UI Performance Optimization and Memory Leak Fix
Approach: Provided StudySessionScreen and requested fixes for FocusNode fixes
Input Summary: Provided the widget code creating FocusNode in build() and fetching data in a for loop
Output Summary: Recieved init/disposed managed FocusNode and refactoed data fetching logic to use Future.wait for parallel execution
Modifications: Added a call to ensure the focus request does not interfere with build phase
Files Referenced: study_session_screen.dart

Date: 2026-02-26
User: Darius Anderson
Purpose: Error correction in study_session_service
Approach: Provided error messages and asked for help fixing them in the service logic.
Input Summary: Supplied error logs and described the issues encountered in study_session_service.
Output Summary: Received targeted advice and code corrections for fixing parameter and logic errors in study_session_service.
Modifications: Fixed parameter mismatches and logic errors in study_session_service.
Files Referenced: study_session_service.dart

Date: 2026-02-27
User: Darius Anderson
Purpose: Wire up FSRS persistence and add input validation
Approach: Asked the AI for step-by-step guidance on connecting FSRS review logic to database persistence and implementing input validation in ReviewRepository.
Input Summary: Provided code context for StudySessionScreen and ReviewRepository, described desired behaviors for persistence and validation.
Output Summary: Received detailed instructions and code snippets for wiring up FSRS persistence in the UI and adding validation logic to ReviewRepository.
Modifications: Implemented FSRS persistence in StudySessionScreen and added input validation to ReviewRepository.
Files Referenced: study_session_screen.dart, review_repository.dart

Date: 2026-03-01
User: Darius Anderson
Purpose: Add and validate edge-case and unit tests for FSRS and review persistence
Approach: Asked the AI for robust test skeletons and validation strategies for StudySessionService and ReviewRepository, including edge cases.
Input Summary: Provided test file context and described the edge cases and behaviors to cover.
Output Summary: Received comprehensive test skeletons and validation logic for both normal and edge-case scenarios, and guidance on interpreting test failures.
Modifications: Created/expanded test files for StudySessionService and ReviewRepository, and implemented validation logic to pass the new tests.
Files Referenced: review_repository_test.dart, study_session_service_test.dart, review_repository.dart

Date: 2026-03-02
User: Darius Anderson
Purpose: Fix FSRS bugs and expand test coverage
Approach: Used AI to identify and help fix bugs, add error handling, and improve tests
Input Summary: Listed bugs and test gaps, provided code context
Output Summary: Guideline to implement bug fixes, error handling added, tests expanded and passing
Modifications: Updated study session logic, fixed FSRS for new cards, improved validation, expanded tests
Files Referenced: study_session_screen.dart, fsrs_service.dart, review_repository.dart, study_session_service_test.dart, review_repository_test.dart

Date: 2026-03-13
User: Darius Anderson
Purpose: Finalize and validate FSRS and repository unit tests for Sprint 3
Approach: Provided the AI with a list of Sprint 3 testing issues, requested completion guidelines, and iteratively debugged and fixed failing tests with AI assistance.
Input Summary: Supplied the full list of required FSRS and repository test cases, shared failing test outputs, and provided code context for test files.
Output Summary: Received detailed test plans, code snippets for missing/incorrect tests, and targeted advice for fixing test logic to match FSRS and repository behaviors. All test files were updated and passing after applying the AI’s recommendations.
Modifications: Expanded and corrected test suites for FSRS service, CardRepository, and DeckRepository. Adjusted test logic for FSRS state transitions, interval calculations, and edge cases to match actual implementation.
Files Referenced: test/features/study/fsrs_service_test.dart, test/features/cards/data/card_repository_test.dart, test/features/decks/data/deck_repository_test.dart

Date: 2026-03-22
User: Darius Anderson
Purpose: Implement offline indicator widget (#106) — real-time connectivity monitoring with smart notifications
Approach: Explored codebase patterns, provided complete implementation with integration points in main.dart, form screens, and study session screen. Iteratively refined UX (persistent banner → temporary snack bars) and added cooldown/pause-resume mechanisms.
Input Summary: Provided project scope and requested full top-to-bottom implementation guide with connectivity_plus integration.
Output Summary: Delivered ConnectivityService singleton with real-time monitoring, GlobalKey pattern for context-free snack bars, 5-second cooldown for flaky networks, pause/resume for study sessions, and configurable toggle.
Modifications: Fixed deprecated API (withOpacity → withValues), corrected connectivity_plus version (v1.5.0 → v7.0.0), refactored to temporary snack bars, implemented GlobalKey setup, added lifecycle pause/resume, integrated post-save checks, removed unnecessary comments.
Files Referenced: lib/core/services/connectivity_service.dart, lib/main.dart, lib/features/cards/presentation/screens/card_form_screen.dart, lib/features/decks/presentation/screens/deck_form_screen.dart, lib/features/study/presentation/screens/study_session_screen.dart, pubspec.yaml

Date: 2026-04-03
User: Darius Anderson
Purpose: Implement card browser screen — Anki-style flat list of all cards across all decks with search, filters, and sorting
Approach: Explored existing codebase patterns (providers, widgets, routing), provided comprehensive implementation guide with exact line numbers, iteratively fixed issues (routing, imports, state management), and validated all functionality via manual testing.
Input Summary: Feature requirements (#154): search/filter by text/deck/state, sort by due date/difficulty/created/reviewed/stability, tap to edit, long-press for multi-select (future). Explored DeckDetailScreen, StudySessionScreen, and provider patterns to ensure consistency.
Output Summary: Delivered comprehensive implementation guide for complete, working card browser with 5 files: filter model (with copyWith generation), providers (FutureProvider.family with CardBrowserFilters parameter), main screen (manages filter state with setState), filter panel widget (collapsible UI), and card list item widget (with due badge). All features tested and working: search, sorting, filtering, card editing, empty states.
Modifications: Fixed GoRouter trailing slash error (/cards/ → /cards), corrected route navigation to pass card as extra data for editing, renamed CardSortBy.ease to CardSortBy.stability for clarity, removed unused imports/constants, initialized compare variable in sort switch, changed from StateNotifier pattern to simple filter state management, added copy_with_extension to pubspec.yaml dependencies.
Files Referenced: lib/core/routing/routes.dart, lib/core/routing/app_router.dart, lib/features/decks/presentation/screens/deck_list_screen.dart, lib/features/cards/data/card_repository.dart, lib/features/cards/presentation/models/card_browser_filters.dart, lib/features/cards/presentation/providers/card_browser_provider.dart, lib/features/cards/presentation/screens/card_browser_screen.dart, lib/features/cards/presentation/widgets/card_browser_filter_panel.dart, lib/features/cards/presentation/widgets/card_list_item.dart, pubspec.yaml

Date: 2026-04-04
User: Darius Anderson
Purpose: Enhance card browser with team feedback — improved UI/UX, separate deck filtering, responsive filters, filter summary display, layout fixes
Approach: Gathered team suggestions for improving card browser usability and clarity. Implemented incrementally: added deck selector dropdown, converted sort order to buttons, made layouts responsive, added filter summary to card count, fixed layout overflow issues, improved navigation button clarity.
Input Summary: Team suggestions included: (1) separate "Sort By (Deck)" dropdown at top to filter by parent deck + nested descendants, (2) Sort By/Order as buttons on desktop/dropdowns on mobile, (3) display active filters next to card count (e.g. "15 cards (All Decks, difficulty, ascending)"), (4) clarify navigation button with better icon/label, (5) "Sort/Filter" label next to expand arrow.
Output Summary: Implemented 6 major enhancements: deck dropdown with nested filtering, responsive layouts (mobile/desktop 600px breakpoint), filter summary display, Sort Order as button chips, SingleChildScrollView layout fix, and clearer `Icons.view_list` navigation icon.
Modifications: Added `selectedDeckId` field and `CardSortBy.deck` enum, created `getByDeckIdWithNested()` recursive query, converted filter panel to ConsumerWidget, added responsive breakpoints and filter summary display, replaced Sort Order toggle with FilterChip buttons, fixed overflow with SingleChildScrollView, updated icon and added "Sort/Filter" label.
Files Referenced: card_browser_filters.dart (added selectedDeckId, CardSortBy.deck), card_repository.dart (added getByDeckIdWithNested), card_browser_provider.dart (updated selectedDeckId references, added deck sort case), card_browser_screen.dart (added filter summary display, Sort/Filter label, SingleChildScrollView layout, filter summary builder), card_browser_filter_panel.dart (ConsumerWidget conversion, deck dropdown, responsive layouts, left-alignment chips, Order buttons), deck_list_screen.dart (icon/tooltip change to Icons.view_list)

Date: 2026-04-18
User: Darius Anderson
Purpose: Implement review data rework — cap reviews at 10K per user and record session summaries (#133)
Approach: Explored existing repository patterns and session screen structure, then requested implementation for 10K review pruning and session summary integration.
Input Summary: The review_session_summary table was already implemented (v5 migration). Needed client-side 10K review cap enforcement by pruning oldest reviews after each study session, plus integration with StudySessionScreen to record summaries on completion.
Output Summary: Received implementation plan for pruneOldReviews(userId) method for ReviewRepository that deletes oldest reviews exceeding 10K threshold, _finalizeSession() method for StudySessionScreen that creates/saves session summaries and triggers pruning, and comprehensive unit tests covering normal/edge cases.
Modifications: Added pruneOldReviews() to ReviewRepository with transaction-safe deletion logic, added card state tracking (_newCount, _learningCount, _reviewCount) to StudySessionScreen, integrated _finalizeSession() on session completion (both normal exit and early termination), created 6 test cases for pruning logic (all passing).
Files Referenced: review_repository.dart, study_session_screen.dart, review_session_summary_repository.dart, review_repository_test.dart

Date: 2026-04-18
User: Darius Anderson
Purpose: Allow bidirectional card flipping and rating from either face (#128)
Approach: Described the issue requirements and asked for implementation of tap-to-toggle, always-enabled swipe-to-rate, and keyboard shortcuts that work from both faces.
Input Summary: Provided issue description showing current behavior (card locked to back after flip) and desired behavior (freely flippable and ratable from either face).
Output Summary: Received implementation plan for changes to FlipCard (remove tap prevention), _flipCard() (toggle instead of set true), SwipeableCard (always enabled), keyboard handling (rate from either face), and rating buttons (always visible).
Modifications: Updated FlipCard to accept taps when flipped, changed _flipCard() to toggle state, enabled SwipeableCard always on mobile, allowed rating shortcuts from either face, made buttons visible on desktop from both faces.
Files Referenced: flip_card.dart, study_session_screen.dart