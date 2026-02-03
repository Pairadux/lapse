import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String userId; // Supabase user ID (or local UUID if anonymous)
  final String? email; // Null if anonymous
  final bool isAnonymous; // True = local only, False = synced account
  final DateTime createdAt;
  final DateTime? lastSyncAt; // Last successful sync timestamp

  const User({required this.userId, this.email, required this.isAnonymous, required this.createdAt, this.lastSyncAt});

  // Factory for anonymous users
  factory User.anonymous() {
    return User(userId: DateTime.now().millisecondsSinceEpoch.toString(), isAnonymous: true, createdAt: DateTime.now());
  }

  // Factory from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      isAnonymous: json['isAnonymous'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastSyncAt: json['lastSyncAt'] != null ? DateTime.parse(json['lastSyncAt'] as String) : null,
    );
  }

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
