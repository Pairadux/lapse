import 'package:flutter_test/flutter_test.dart';
import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:lapse/core/sync/sync_adapter.dart';

void main() {
  group('toSupabaseRow', () {
    test('removes sync_status column', () {
      final local = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'Test',
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
      };

      final result = SyncAdapter.toSupabaseRow(local);

      expect(result.containsKey(DatabaseConstants.colSyncStatus), isFalse);
      expect(result[DatabaseConstants.colDeckId], 'deck-1');
      expect(result[DatabaseConstants.colDeckName], 'Test');
    });

    test('converts is_deleted from int 1 to bool true', () {
      final local = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: 1,
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
      };

      final result = SyncAdapter.toSupabaseRow(local);

      expect(result[DatabaseConstants.colIsDeleted], isTrue);
    });

    test('converts is_deleted from int 0 to bool false', () {
      final local = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: 0,
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
      };

      final result = SyncAdapter.toSupabaseRow(local);

      expect(result[DatabaseConstants.colIsDeleted], isFalse);
    });

    test('leaves rows without is_deleted unchanged', () {
      final local = {
        DatabaseConstants.colReviewId: 'review-1',
        DatabaseConstants.colCardId: 'card-1',
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
      };

      final result = SyncAdapter.toSupabaseRow(local);

      expect(result.containsKey(DatabaseConstants.colIsDeleted), isFalse);
      expect(result[DatabaseConstants.colReviewId], 'review-1');
    });

    test('does not mutate the original map', () {
      final local = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: 1,
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
      };

      SyncAdapter.toSupabaseRow(local);

      expect(local[DatabaseConstants.colIsDeleted], 1);
      expect(local.containsKey(DatabaseConstants.colSyncStatus), isTrue);
    });

    test('preserves all other columns unchanged', () {
      final now = DateTime.now().toUtc().toIso8601String();
      final local = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'My Deck',
        DatabaseConstants.colParentId: null,
        DatabaseConstants.colUserId: 'user-123',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
        DatabaseConstants.colIsDeleted: 0,
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
      };

      final result = SyncAdapter.toSupabaseRow(local);

      expect(result[DatabaseConstants.colDeckId], 'deck-1');
      expect(result[DatabaseConstants.colDeckName], 'My Deck');
      expect(result[DatabaseConstants.colParentId], isNull);
      expect(result[DatabaseConstants.colUserId], 'user-123');
      expect(result[DatabaseConstants.colCreatedAt], now);
      expect(result[DatabaseConstants.colUpdatedAt], now);
    });
  });

  group('fromSupabaseRow', () {
    test('adds sync_status as synced', () {
      final remote = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'Test',
      };

      final result = SyncAdapter.fromSupabaseRow(remote);

      expect(result[DatabaseConstants.colSyncStatus], SyncStatus.synced.name);
    });

    test('converts is_deleted from bool true to int 1', () {
      final remote = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: true,
      };

      final result = SyncAdapter.fromSupabaseRow(remote);

      expect(result[DatabaseConstants.colIsDeleted], 1);
    });

    test('converts is_deleted from bool false to int 0', () {
      final remote = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: false,
      };

      final result = SyncAdapter.fromSupabaseRow(remote);

      expect(result[DatabaseConstants.colIsDeleted], 0);
    });

    test('leaves rows without is_deleted unchanged', () {
      final remote = {
        DatabaseConstants.colReviewId: 'review-1',
        DatabaseConstants.colCardId: 'card-1',
      };

      final result = SyncAdapter.fromSupabaseRow(remote);

      expect(result.containsKey(DatabaseConstants.colIsDeleted), isFalse);
      expect(result[DatabaseConstants.colSyncStatus], SyncStatus.synced.name);
    });

    test('does not mutate the original map', () {
      final remote = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: true,
      };

      SyncAdapter.fromSupabaseRow(remote);

      expect(remote[DatabaseConstants.colIsDeleted], isTrue);
      expect(remote.containsKey(DatabaseConstants.colSyncStatus), isFalse);
    });

    test('preserves all other columns unchanged', () {
      final now = '2026-03-20T12:00:00+00:00';
      final remote = {
        DatabaseConstants.colCardId: 'card-1',
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colFront: 'Question?',
        DatabaseConstants.colBack: 'Answer',
        DatabaseConstants.colUserId: 'user-123',
        DatabaseConstants.colCreatedAt: now,
        DatabaseConstants.colUpdatedAt: now,
        DatabaseConstants.colIsDeleted: false,
        DatabaseConstants.colDueDate: now,
        DatabaseConstants.colStability: 4.5,
        DatabaseConstants.colDifficulty: 3.2,
      };

      final result = SyncAdapter.fromSupabaseRow(remote);

      expect(result[DatabaseConstants.colCardId], 'card-1');
      expect(result[DatabaseConstants.colFront], 'Question?');
      expect(result[DatabaseConstants.colBack], 'Answer');
      expect(result[DatabaseConstants.colStability], 4.5);
      expect(result[DatabaseConstants.colDifficulty], 3.2);
    });
  });

  group('round-trip', () {
    test('toSupabaseRow then fromSupabaseRow restores original (minus sync_status value)', () {
      final original = {
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colDeckName: 'Round Trip',
        DatabaseConstants.colIsDeleted: 0,
        DatabaseConstants.colSyncStatus: SyncStatus.pending.name,
        DatabaseConstants.colUpdatedAt: '2026-03-20T12:00:00.000Z',
      };

      final supabase = SyncAdapter.toSupabaseRow(original);
      final restored = SyncAdapter.fromSupabaseRow(supabase);

      expect(restored[DatabaseConstants.colDeckId], original[DatabaseConstants.colDeckId]);
      expect(restored[DatabaseConstants.colDeckName], original[DatabaseConstants.colDeckName]);
      expect(restored[DatabaseConstants.colIsDeleted], original[DatabaseConstants.colIsDeleted]);
      expect(restored[DatabaseConstants.colUpdatedAt], original[DatabaseConstants.colUpdatedAt]);
      // sync_status is always 'synced' after round-trip (correct — pushed data is synced)
      expect(restored[DatabaseConstants.colSyncStatus], SyncStatus.synced.name);
    });

    test('fromSupabaseRow then toSupabaseRow restores original', () {
      final original = {
        DatabaseConstants.colCardId: 'card-1',
        DatabaseConstants.colDeckId: 'deck-1',
        DatabaseConstants.colIsDeleted: true,
        DatabaseConstants.colUpdatedAt: '2026-03-20T12:00:00+00:00',
      };

      final local = SyncAdapter.fromSupabaseRow(original);
      final restored = SyncAdapter.toSupabaseRow(local);

      expect(restored[DatabaseConstants.colCardId], original[DatabaseConstants.colCardId]);
      expect(restored[DatabaseConstants.colDeckId], original[DatabaseConstants.colDeckId]);
      expect(restored[DatabaseConstants.colIsDeleted], original[DatabaseConstants.colIsDeleted]);
      expect(restored[DatabaseConstants.colUpdatedAt], original[DatabaseConstants.colUpdatedAt]);
      expect(restored.containsKey(DatabaseConstants.colSyncStatus), isFalse);
    });
  });
}
