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
