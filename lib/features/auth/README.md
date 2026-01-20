# Auth Feature

## Metadata

| Field | Value |
|-------|-------|
| **Owner** | Austin |
| **Status** | 🔴 Not Started |
| **Last Updated** | [DATE] |
| **Sprint** | Sprint 4 (auth + sync) |

## Overview

The Auth feature handles user authentication, cross-device synchronization, and app settings. This is the most architecturally complex feature because it touches all other features through sync.

---

## User Stories

### Authentication
- As a user, I can use the app without creating an account (anonymous/local mode)
- As a user, I can create an account with email
- As a user, I can sign in to an existing account
- As a user, I can sign out
- As a user, I can reset my password

### Sync
- As a user, my data syncs automatically when I'm online
- As a user, I can use the app offline and changes sync later
- As a user, I can see my sync status (synced, syncing, offline)
- As a user, if I create an account after using anonymously, my local data migrates

### Settings
- As a user, I can view and edit my account info
- As a user, I can adjust app preferences (theme, notifications)
- As a user, I can export my data
- As a user, I can delete my account

---

## Quick Reference

| Layer | Purpose | Key Files |
|-------|---------|-----------|
| `data/` | Auth & sync operations | `auth_repository.dart`, `sync_repository.dart` |
| `domain/` | Models | `user.dart`, `sync_status.dart` |
| `application/` | Sync logic | `sync_service.dart` |
| `presentation/` | UI | Login, settings, onboarding screens |

---

## Folder Structure

```
auth/
├── data/
│   ├── auth_repository.dart           # Supabase auth operations
│   ├── sync_repository.dart           # Sync coordination
│   ├── supabase_data_source.dart      # Supabase API calls
│   └── sync_queue_data_source.dart    # Local sync queue (SQLite)
│
├── domain/
│   ├── user.dart                      # User model
│   ├── sync_status.dart               # Sync state enum/model
│   └── sync_operation.dart            # Queued sync operation model
│
├── application/
│   ├── auth_service.dart              # Auth flow orchestration
│   └── sync_service.dart              # Sync engine
│
├── presentation/
│   ├── screens/
│   │   ├── login_screen.dart          # Sign in / sign up
│   │   ├── onboarding_screen.dart     # First launch experience
│   │   └── settings_screen.dart       # Account & app settings
│   │
│   ├── widgets/
│   │   ├── auth_form.dart             # Email/password form
│   │   ├── sync_status_indicator.dart # Shows sync state in UI
│   │   └── settings_tile.dart         # Individual setting row
│   │
│   └── providers/
│       ├── auth_provider.dart         # Current user state
│       ├── sync_provider.dart         # Sync status state
│       └── settings_provider.dart     # App preferences
│
└── README.md
```

---

## Data Models

### User

```dart
class User {
  final String id;              // Supabase user ID (or local UUID if anonymous)
  final String? email;          // Null if anonymous
  final bool isAnonymous;       // True = local only, False = synced account
  final DateTime createdAt;
  final DateTime? lastSyncAt;   // Last successful sync timestamp
}
```

### Sync Status

```dart
enum SyncStatus {
  synced,       // All changes uploaded, no pending changes
  syncing,      // Currently syncing
  pending,      // Offline changes waiting to sync
  offline,      // No network connection
  error,        // Sync failed (will retry)
}
```

### Sync Operation (queue item)

```dart
class SyncOperation {
  final int id;                 // Auto-increment local ID
  final String tableName;       // 'decks', 'cards', 'reviews'
  final String recordId;        // UUID of the record
  final String operation;       // 'INSERT', 'UPDATE', 'DELETE'
  final String data;            // JSON payload
  final DateTime createdAt;
  final int retryCount;         // For exponential backoff
}
```

---

## Supabase Setup

### Tables (mirror local SQLite schema)

```sql
-- Supabase tables include user_id for Row Level Security

CREATE TABLE decks (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users NOT NULL,
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE cards (
  id UUID PRIMARY KEY,
  deck_id UUID REFERENCES decks NOT NULL,
  front TEXT NOT NULL,
  back TEXT NOT NULL,
  -- ... FSRS fields ...
  created_at TIMESTAMPTZ NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL,
  is_deleted BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE reviews (
  id UUID PRIMARY KEY,
  card_id UUID REFERENCES cards NOT NULL,
  reviewed_at TIMESTAMPTZ NOT NULL,
  rating INTEGER NOT NULL,
  -- ... other fields ...
);
```

### Row Level Security (RLS)

```sql
-- Users can only access their own data
ALTER TABLE decks ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can CRUD own decks" ON decks
  FOR ALL USING (auth.uid() = user_id);

-- Similar policies for cards and reviews
```

---

## Sync Architecture

### Overview

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   SQLite    │────▶│  Sync Queue │────▶│  Supabase   │
│  (source of │     │  (pending   │     │  (cloud     │
│   truth)    │◀────│   changes)  │◀────│   backup)   │
└─────────────┘     └─────────────┘     └─────────────┘
```

### Sync Flow

**On local change (create/update/delete):**
1. Write to SQLite immediately
2. Add operation to sync queue
3. If online, trigger sync

**Sync process:**
1. Get pending operations from queue (oldest first)
2. For each operation:
   - Send to Supabase
   - If success: remove from queue
   - If conflict: resolve (last-write-wins)
   - If network error: keep in queue, retry later
3. After push: pull latest changes from Supabase
4. Apply remote changes to SQLite

### Conflict Resolution

**Strategy: Last-Write-Wins**
- Compare `updated_at` timestamps
- More recent change wins
- Simple, predictable, may lose data in edge cases
- Sufficient for MVP; can improve later

### Offline Queue Table

```sql
CREATE TABLE sync_queue (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  table_name TEXT NOT NULL,
  record_id TEXT NOT NULL,
  operation TEXT NOT NULL,    -- 'INSERT', 'UPDATE', 'DELETE'
  data TEXT NOT NULL,         -- JSON payload
  created_at TEXT NOT NULL,
  retry_count INTEGER DEFAULT 0
);

CREATE INDEX idx_sync_queue_created ON sync_queue(created_at);
```

---

## Anonymous to Account Migration

When a user creates an account after using anonymously:

1. Create Supabase account
2. Get new Supabase user ID
3. Update all local records' `user_id` to new ID
4. Sync all local data to Supabase
5. Update local user record: `isAnonymous = false`

```dart
Future<void> migrateAnonymousToAccount(String newUserId) async {
  // Update user_id on all local data
  await db.execute('UPDATE decks SET user_id = ?', [newUserId]);
  await db.execute('UPDATE cards SET user_id = ?', [newUserId]);
  
  // Queue everything for sync
  final decks = await deckRepository.getAllDecks();
  for (final deck in decks) {
    await syncQueue.add(SyncOperation(
      tableName: 'decks',
      recordId: deck.id,
      operation: 'INSERT',
      data: deck.toJson(),
    ));
  }
  // ... same for cards and reviews
  
  // Trigger sync
  await syncService.sync();
}
```

---

## Key Implementation Notes

### Auth Flow

```
App Launch
    ↓
Check local user
    ↓
┌─────────────────┬─────────────────┐
│ Has account     │ No account      │
│ (isAnonymous    │ (first launch   │
│  = false)       │  or anonymous)  │
└────────┬────────┴────────┬────────┘
         ↓                 ↓
    Auto sign in      Onboarding
    with Supabase        screen
         ↓                 ↓
    Trigger sync      "Continue
         ↓             without
    Home screen        account"
                          ↓
                     Create local
                     anonymous user
                          ↓
                     Home screen
```

### Settings Screen

- Account section (email, sign out, delete account)
- Sync section (status, last synced, manual sync button)
- Appearance section (theme toggle if implemented)
- About section (version, licenses)
- Export data button
- Sign in/Create account button (if anonymous)

### Sync Status Indicator

Show in app bar or home screen:
- ✓ Synced (green check)
- ↻ Syncing (spinning)
- ⏸ Pending (yellow, with count)
- ✕ Offline (gray)
- ⚠ Error (red, tap for details)

---

## Dependencies

### Internal
- All other features (sync touches decks, cards, reviews)
- `core/routing` for navigation guards

### External
- `supabase_flutter: ^2.3.0`
- `flutter_riverpod`
- `connectivity_plus` — for online/offline detection
- `shared_preferences` — for simple settings storage

---

## Testing Requirements

### Unit Tests
- [ ] Auth service sign up flow
- [ ] Auth service sign in flow
- [ ] Sync queue operations (add, remove, retry)
- [ ] Conflict resolution logic
- [ ] Anonymous migration

### Integration Tests
- [ ] Full sync cycle (push local changes, pull remote)
- [ ] Offline → online sync recovery
- [ ] Sign out clears local data appropriately

---

## Security Considerations

- Never store passwords locally
- Use Supabase's built-in auth (handles tokens securely)
- RLS ensures users can't access others' data
- Consider: encrypt local SQLite database?

---

## Open Questions

- [ ] OAuth providers (Google, Apple sign-in)?
- [ ] Email verification required?
- [ ] How long to keep soft-deleted records before purging?
- [ ] Sync frequency when online (realtime vs polling)?
- [ ] What happens if user signs in on new device? (Full download)

---

## Changelog

| Date | Change | Author |
|------|--------|--------|
| [DATE] | Initial README created | Austin |
