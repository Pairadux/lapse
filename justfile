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

# Bump version: `just bump 1.2.3` or `just bump --major/--minor/--patch`
bump *args:
    #!/usr/bin/env bash
    set -euo pipefail
    current=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    build=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
    IFS='.' read -r major minor patch <<< "$current"
    arg="${1:-}"
    case "$arg" in
        --major) major=$((major + 1)); minor=0; patch=0 ;;
        --minor) minor=$((minor + 1)); patch=0 ;;
        --patch) patch=$((patch + 1)) ;;
        --*) echo "Unknown flag: $arg. Use --major, --minor, --patch, or a version string."; exit 1 ;;
        "") echo "Usage: just bump <version|--major|--minor|--patch>"; exit 1 ;;
        *) IFS='.' read -r major minor patch <<< "$arg" ;;
    esac
    new_version="${major}.${minor}.${patch}"
    new_build=$((build + 1))
    sed -i'' -e "s/^version: .*/version: ${new_version}+${new_build}/" pubspec.yaml
    git add pubspec.yaml
    git commit -m "chore: bump version to ${new_version}+${new_build}"
    git tag "v${new_version}"
    git push && git push origin "v${new_version}"
    echo "Bumped to ${new_version}+${new_build} and pushed tag v${new_version}"
