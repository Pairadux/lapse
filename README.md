# Lapse

A cross-platform flashcard app with spaced repetition, built with Flutter.

> **This is a school project and is not accepting outside contributions.**
> Pull requests, issues, and comments from non-team members will be closed without review.

## Features

- **Spaced Repetition** — FSRS algorithm for optimal review scheduling
- **Nested Decks** — Organize cards into hierarchical deck structures
- **Offline-First** — Local SQLite storage, study anywhere
- **Cross-Platform** — Linux, macOS, Windows, Android, iOS
- **Custom Desktop UI** — Frameless window with native-themed titlebar buttons

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Framework | Flutter |
| State Management | Riverpod |
| Routing | GoRouter (flat routes, platform-aware transitions) |
| Database | SQLite via sqflite |
| Scheduling | FSRS (Free Spaced Repetition Scheduler) |
| Desktop Titlebar | window_manager + modern_titlebar_buttons |

## Project Structure

```
lib/
├── core/
│   ├── database/       # DatabaseHelper, constants
│   ├── routing/        # GoRouter config, page transitions
│   ├── theme/          # Material 3 dark theme, colors, spacing
│   └── widgets/        # Shared components (AppScaffold, dialogs, etc.)
├── features/
│   ├── cards/          # Flashcard CRUD
│   ├── decks/          # Deck management (nested hierarchy)
│   └── study/          # Study sessions, FSRS scheduling
└── main.dart
```

## Getting Started

### Prerequisites

- Flutter SDK
- Dart SDK

### Build & Run

```bash
git clone https://github.com/Pairadux/lapse.git
cd lapse
flutter pub get
flutter run
```

A dev drawer (swipe from left edge) is available in debug builds for navigating screens and loading mock data.

## Status

This project is in active development as a school project. See `docs/` for AI usage logs and design documentation.

## License

All rights reserved. This source code is provided for viewing purposes only. No permission is granted to use, copy, modify, or distribute this software.
