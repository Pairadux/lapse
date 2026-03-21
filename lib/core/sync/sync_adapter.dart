import 'package:lapse/core/database/database_constants.dart';
import 'package:lapse/core/domain/sync_status.dart';

/// Converts between SQLite column maps and Supabase row maps.
///
/// SQLite stores booleans as integers (0/1) and includes `sync_status`.
/// Supabase uses native booleans and has no `sync_status` column.
/// Only two fields differ — this adapter lives at the Supabase boundary
/// so models and repositories stay SQLite-native.
abstract final class SyncAdapter {
  /// Prepares a local SQLite row for upsert to Supabase.
  ///
  /// - Removes `sync_status` (server doesn't store it)
  /// - Converts `is_deleted` from int (0/1) to bool (if present)
  static Map<String, dynamic> toSupabaseRow(Map<String, dynamic> localMap) {
    final row = Map<String, dynamic>.of(localMap);
    row.remove(DatabaseConstants.colSyncStatus);

    if (row.containsKey(DatabaseConstants.colIsDeleted)) {
      row[DatabaseConstants.colIsDeleted] =
          row[DatabaseConstants.colIsDeleted] == 1;
    }

    return row;
  }

  /// Converts a Supabase row into a SQLite-ready column map.
  ///
  /// - Adds `sync_status = 'synced'` (remote data is authoritative)
  /// - Converts `is_deleted` from bool to int (if present)
  static Map<String, dynamic> fromSupabaseRow(Map<String, dynamic> remoteMap) {
    final row = Map<String, dynamic>.of(remoteMap);
    row[DatabaseConstants.colSyncStatus] = SyncStatus.synced.name;

    if (row.containsKey(DatabaseConstants.colIsDeleted)) {
      row[DatabaseConstants.colIsDeleted] =
          row[DatabaseConstants.colIsDeleted] == true ? 1 : 0;
    }

    return row;
  }
}
