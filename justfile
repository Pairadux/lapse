# Default recipe: list available commands
default:
    @just --list

# Run the app with Supabase credentials
run *args:
    flutter run --dart-define-from-file=env.json {{args}}

# Run on a specific device (e.g., just device chrome)
device target:
    flutter run --dart-define-from-file=env.json -d {{target}}

# Build release APK
build-apk:
    flutter build apk --dart-define-from-file=env.json

# Build release iOS
build-ios:
    flutter build ios --dart-define-from-file=env.json

# Build macOS
build-macos:
    flutter build macos --dart-define-from-file=env.json

# Build Linux
build-linux:
    flutter build linux --dart-define-from-file=env.json

# Run all tests
test *args:
    flutter test {{args}}

# Run tests with coverage
test-coverage:
    flutter test --coverage

# Analyze code
analyze:
    flutter analyze

# Format code
format:
    dart format lib/ test/

# Clean build artifacts
clean:
    flutter clean && flutter pub get

# Get dependencies
pub-get:
    flutter pub get

# Check outdated packages
outdated:
    flutter pub outdated

# Generate launcher icons
icons:
    dart run flutter_launcher_icons
