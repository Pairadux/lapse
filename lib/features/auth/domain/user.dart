class User {
  final String id;              // Supabase user ID (or local UUID if anonymous)
  final String? email;          // Null if anonymous
  final bool isAnonymous;       // True = local only, False = synced account
  final DateTime createdAt;
  final DateTime? lastSyncAt;   // Last successful sync timestamp
}