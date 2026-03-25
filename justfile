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

# Bump version: `just bump --minor`, `just bump 1.2.3`
# Add -m/--migration to also generate a Supabase min_app_version migration
bump *args:
    #!/usr/bin/env bash
    set -euo pipefail
    current=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
    build=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)
    IFS='.' read -r major minor patch <<< "$current"
    generate_migration=false
    version_action=""
    for arg in {{args}}; do
        case "$arg" in
            --major|--minor|--patch)
                if [ -n "$version_action" ]; then
                    echo "Error: cannot combine $version_action and $arg"; exit 1
                fi
                version_action="$arg"
                case "$arg" in
                    --major) major=$((major + 1)); minor=0; patch=0 ;;
                    --minor) minor=$((minor + 1)); patch=0 ;;
                    --patch) patch=$((patch + 1)) ;;
                esac
                ;;
            -m|--migration) generate_migration=true ;;
            --*|-*) echo "Unknown flag: $arg. Use --major/--minor/--patch, -m/--migration, or a version string."; exit 1 ;;
            *)
                if [ -n "$version_action" ]; then
                    echo "Error: cannot combine $version_action and a version string"; exit 1
                fi
                version_action="$arg"
                IFS='.' read -r major minor patch <<< "$arg"
                ;;
        esac
    done
    if [ -z "$version_action" ]; then
        echo "Usage: just bump <version|--major|--minor|--patch> [-m|--migration]"
        exit 1
    fi
    new_version="${major}.${minor}.${patch}"
    new_build=$((build + 1))
    sed -i '' "s/^version: .*/version: ${new_version}+${new_build}/" pubspec.yaml
    files="pubspec.yaml"
    if [ "$generate_migration" = true ]; then
        timestamp=$(date -u +"%Y%m%d%H%M%S")
        migration="supabase/migrations/${timestamp}_bump_min_app_version.sql"
        echo "UPDATE public.app_config SET value = '${new_version}' WHERE key = 'min_app_version';" > "$migration"
        files="$files $migration"
        echo "Generated migration: $migration"
    fi
    git add $files
    git commit -m "chore: bump version to ${new_version}+${new_build}"
    git tag "v${new_version}"
    git push && git push origin "v${new_version}"
    echo "Bumped to ${new_version}+${new_build} and pushed tag v${new_version}"
