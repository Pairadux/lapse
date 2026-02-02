# Lapse

A cross-platform flashcard app with spaced repetition, built with Flutter.

## Features

- **Spaced Repetition**: Uses the FSRS algorithm for optimal review scheduling
- **Nested Decks**: Organize cards into hierarchical deck structures
- **Offline-First**: Study anywhere, sync when connected
- **Cross-Platform**: Runs on iOS, Android, macOS, Windows, Linux, and web

## Tech Stack

- **Framework**: Flutter 3.10+
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Local Storage**: SQLite (planned)

## Getting Started

### Prerequisites

- Flutter SDK ^3.10.7
- Dart SDK

### Installation

```bash
# Clone the repository
git clone https://github.com/Pairadux/lapse.git
cd lapse

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── routing/      # GoRouter configuration
│   ├── theme/        # Colors, spacing, theme data
│   └── widgets/      # Shared UI components
├── features/
│   └── decks/        # Deck management feature
│       ├── domain/   # Models
│       └── presentation/
└── main.dart
```

## Development

This project is currently in active MVP development.

### Running in Debug Mode

```bash
flutter run
```

The app includes a dev drawer (swipe from left) for navigating between screens during development.

## Team

Built as a collaborative project with AI-assisted development. See `docs/AI-Usage-*.md` for usage logs.

## License

TBD
