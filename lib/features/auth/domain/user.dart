import 'package:uuid/uuid.dart';

class User {
  String userID;              // Supabase user ID (or local UUID if anonymous)
  String? email;          // Null if anonymous
  bool isAnonymous;       // True = local only, False = synced account
  final DateTime createdAt;
  DateTime? lastSyncAt;   // Last successful sync timestamp

  User(uuid.v4(), this.email, this.isAnonymous, DateTime.now(), this.lastSyncAt);

  User.anon()
    : userID = "Anonymous",
    email = "",
    isAnonymous = true,
    createdAt = DateTime.now(),
    lastSyncAt = DateTime.now();
  // For anonymous users
}