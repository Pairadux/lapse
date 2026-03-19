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
