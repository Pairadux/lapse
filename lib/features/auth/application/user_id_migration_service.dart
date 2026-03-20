import '../../../core/database/database_constants.dart';
import '../../../core/database/database_helper.dart';

/// One-time migration that stamps all local data with the authenticated
/// user's id and marks it for sync.
///
/// Runs as an atomic SQLite transaction — if the app is killed mid-migration,
/// SQLite auto-rolls back. The migration is idempotent: rows already stamped
/// with a user_id are left untouched (WHERE clause only matches empty strings).
class UserIdMigrationService {
  final DatabaseHelper _dbHelper;

  UserIdMigrationService({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  /// Stamps all rows with `user_id = ''` with [authUserId] and sets
  /// their `sync_status` to `'pending'`.
  ///
  /// Safe to call multiple times — UPDATEs only match rows where
  /// `user_id = ''`, so repeated calls are no-ops. Four UPDATE statements
  /// matching zero rows complete in microseconds.
  Future<void> migrateLocalData(String authUserId) async {
    if (authUserId.isEmpty) return;

    final db = await _dbHelper.database;

    await db.transaction((txn) async {
      await txn.rawUpdate(
        "UPDATE ${DatabaseConstants.tableDecks} "
        "SET ${DatabaseConstants.colUserId} = ?, ${DatabaseConstants.colSyncStatus} = 'pending' "
        "WHERE ${DatabaseConstants.colUserId} = ''",
        [authUserId],
      );
      await txn.rawUpdate(
        "UPDATE ${DatabaseConstants.tableCards} "
        "SET ${DatabaseConstants.colUserId} = ?, ${DatabaseConstants.colSyncStatus} = 'pending' "
        "WHERE ${DatabaseConstants.colUserId} = ''",
        [authUserId],
      );
      await txn.rawUpdate(
        "UPDATE ${DatabaseConstants.tableReviews} "
        "SET ${DatabaseConstants.colUserId} = ?, ${DatabaseConstants.colSyncStatus} = 'pending' "
        "WHERE ${DatabaseConstants.colUserId} = '' OR ${DatabaseConstants.colUserId} IS NULL",
        [authUserId],
      );
      await txn.rawUpdate(
        "UPDATE ${DatabaseConstants.tableReviewSessionSummary} "
        "SET ${DatabaseConstants.colUserId} = ?, ${DatabaseConstants.colSyncStatus} = 'pending' "
        "WHERE ${DatabaseConstants.colUserId} = ''",
        [authUserId],
      );
    });
  }
}
