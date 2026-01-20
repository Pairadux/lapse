# Core Module

## Metadata

| Field | Value |
|-------|-------|
| **Owner** | Austin |
| **Status** | 🟡 In Progress |
| **Last Updated** | [DATE] |

## Overview

The `core/` module contains shared utilities, configuration, and foundational code used across all features. **Do not add feature-specific code here.**

> ⚠️ **Before modifying anything in this folder, consult with Austin.** Changes here affect the entire app.

---

## Quick Reference

| Folder | Purpose | Example Contents |
|--------|---------|------------------|
| `constants/` | App-wide constant values | API URLs, storage keys, magic numbers |
| `theme/` | Visual styling | Colors, typography, spacing, ThemeData |
| `routing/` | Navigation setup | GoRouter config, route definitions |
| `widgets/` | Shared UI components | Custom buttons, cards, dialogs |
| `utils/` | Helper functions | Extensions, formatters, validators |
| `exceptions/` | Custom error types | AppException, NetworkException |

---

## Folder Structure

```
core/
├── constants/
│   ├── app_constants.dart      # General constants (app name, version)
│   ├── storage_keys.dart       # SQLite/SharedPrefs keys
│   └── api_constants.dart      # Supabase URLs, endpoints
│
├── theme/
│   ├── app_theme.dart          # ThemeData configuration
│   ├── app_colors.dart         # Color palette
│   ├── app_typography.dart     # Text styles
│   └── app_spacing.dart        # Padding/margin constants
│
├── routing/
│   ├── app_router.dart         # GoRouter setup
│   ├── routes.dart             # Route path constants
│   └── route_guards.dart       # Auth guards (if needed)
│
├── widgets/
│   ├── app_button.dart         # Styled button variants
│   ├── app_card.dart           # Styled card component
│   ├── loading_indicator.dart  # Consistent loading spinner
│   └── error_view.dart         # Consistent error display
│
├── utils/
│   ├── extensions/
│   │   ├── string_extensions.dart
│   │   ├── datetime_extensions.dart
│   │   └── context_extensions.dart
│   ├── validators.dart         # Input validation helpers
│   └── formatters.dart         # Date/number formatting
│
└── exceptions/
    ├── app_exception.dart      # Base exception class
    ├── network_exception.dart  # Network-related errors
    └── storage_exception.dart  # Database errors
```

---

## Guidelines

### What belongs in `core/`

✅ Code used by **3+ features**  
✅ App configuration (theme, routing)  
✅ Truly generic utilities  
✅ Base classes that features extend  

### What does NOT belong in `core/`

❌ Feature-specific widgets (put in feature's `presentation/widgets/`)  
❌ Feature-specific models (put in feature's `domain/`)  
❌ Business logic (put in feature's `application/`)  
❌ Code used by only 1-2 features (keep it in those features)  

### Adding shared code

If you need to add something to `core/`:
1. Ask yourself: "Is this truly shared, or am I being lazy?"
2. If truly shared, message Austin with what you want to add
3. Austin will either add it or approve your PR

---

## Dependencies

This module should have minimal dependencies:
- `flutter` (SDK)
- `go_router` (for routing)

Avoid importing feature modules from core—dependencies should flow **from features to core**, not the other way.

---

## Notes

- Keep files small and focused
- Prefer composition over inheritance
- Document non-obvious code with comments
- Write tests for utility functions
