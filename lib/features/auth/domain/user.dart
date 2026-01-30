import 'package:uuid/uuid.dart';

class User {
  final String userID;              // Supabase user ID (or local UUID if anonymous)
  final String? email;          // Null if anonymous
  final bool isAnonymous;       // True = local only, False = synced account
  final DateTime createdAt;
  final DateTime? lastSyncAt;   // Last successful sync timestamp

  const User(uuid.v4(), this.email, this.isAnonymous, DateTime.now(), this.lastSyncAt);
}