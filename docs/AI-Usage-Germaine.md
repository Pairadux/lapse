## TEMPLATE

Date: YYYY-MM-DD
User: [Team member name]
Purpose: [What you're trying to accomplish]
Approach: [How you prompted the AI]
Input Summary: [2-3 sentences on what you provided]
Output Summary: [2-3 sentences on what you got back]
Modifications: [What you changed and why]
Files Referenced: [Links to influenced files]

Date: 2026-02-02
User: Germaine
Purpose: Method for comparisons between objects
Approach: Explained that I need to compare objects
Input summary: How can I compare two objects of the same type similar to .equals()
Output Summary: Equatable import and the get props getter
Files Referenced: lib/features/auth/domain/user.dart, lib/features/cards/domain/flashcard.dart, lib/features/decks/domain/deck.dart, lib/features/study/domain/review.dart, lib/features/study/domain/studysession.dart, pubspec.yaml

Date: 2026-02-02
User: Germaine
Purpose: Create a dart factory
Approach: Explained that I need to make factory with predefined parameters and asked how factories work.
Input Summary: Asked it to assist me in creating a factory for the user and anonmymous user
Output Summary: Recieved a factory template for user and anonymous user and insights. on how factories work in dart.
Files Referenced: lib/features/auth/domain/user.dart

Date: 2026-02-10
User: Germaine
Purpose: Optional class
Approach: Asked about explicitly declaring a value as null as well as asking about the Optional class.
Input Summary: asked how a variable could be set to null using copyWith()
Output Summary: recieved information on the Optional class
Files Refrenced: lib/features/decks/domain/deck.dart


Date: 2026-04-03
User: Germaine
Purpose: Export Flashcards
Input Summary: How can I connect my backend logic for card exporting to the front end
Output Summary: Recieved a template for _exportDeck
Files Refrenced: lib/core/widgets/dev_drawer.dart, lib/features/import_export/data/export_service.dart

Date: 2026-04-03
User: Germaine
Purpose: Convert exported cards to downloadable file
Input Summary: How can I create a savable file for my exported decks
Output Summary: code and imports to add to _exportDeck() creates a temporary file that can be downloaded for mobile and desktop.