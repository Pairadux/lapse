import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class User extends Equatable {
  final String userId; // Supabase user ID (or local UUID if anonymous)
  final String? email; // Null if anonymous
  final bool isAnonymous; // True = local only, False = synced account
  final DateTime createdAt;
  final DateTime? lastSyncAt; // Last successful sync timestamp

  const User({required this.userId, this.email, required this.isAnonymous, required this.createdAt, this.lastSyncAt});

  User.anon()
    : userId = const Uuid().v4(),
      email = "",
      isAnonymous = true,
      createdAt = DateTime.now(),
      lastSyncAt = DateTime.now();
  // For anonymous users

  User copyWith({String? userId, String? email, bool? isAnonymous, DateTime? createdAt, DateTime? lastSyncAt}) {
    return User(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      createdAt: createdAt ?? this.createdAt,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
    );
  }

  @override
  // TODO: implement props
  List<Object?> get props => [userId, email, isAnonymous, createdAt, lastSyncAt];
}
