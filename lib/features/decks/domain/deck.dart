import 'package:equatable/equatable.dart';
import 'package:lapse/core/domain/sync_status.dart';
import 'package:uuid/uuid.dart';
import 'package:lapse/core/database/database_constants.dart';

class Deck extends Equatable {
  final String deckId; // UUID, generated on creation
  final String? parentId; // ID of parent (optional)
  final String deckName; // Deck title (required)
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted; // Soft delete for sync
  final String userId;
  final SyncStatus syncStatus; // Synced, pending, conflict

  const Deck({
    required this.deckId,
    this.parentId, // Defaults to null
    required this.deckName,
    required this.createdAt,
    required this.updatedAt,
    this.isDeleted = false,
    this.userId = '',
    this.syncStatus = SyncStatus.synced,
  });

  /// Creates a new deck with auto-generated ID and timestamps.
  factory Deck.create({required String deckName, String? parentId}) {
    final now = DateTime.now();
    return Deck(
      deckId: const Uuid().v4(),
      parentId: parentId,
      deckName: deckName,
      createdAt: now,
      updatedAt: now,
      userId: '',
    );
  }

  Deck copyWith({
    Optional<String?>? parentId,
    String? deckName,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDeleted,
    SyncStatus? syncStatus,
  }) {
    return Deck(
      deckId: deckId, // Deck Id cannot be changed
      parentId: parentId != null && parentId.isSet
          ? parentId.value
          : this.parentId, // call using copyWith(parentId: Optional.value(null)) to set parentId to null
      deckName: deckName ?? this.deckName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt, // Always update timestamp on change
      isDeleted: isDeleted ?? this.isDeleted,
      userId: userId, // immutable — set at creation
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  /// Serializes to a DB-ready column map.
  /// Excludes runtime-only fields: cards, cardCount, dueCount.
  Map<String, dynamic> toMap() {
    return {
      DatabaseConstants.colDeckId: deckId,
      DatabaseConstants.colParentId: parentId,
      DatabaseConstants.colDeckName: deckName,
      DatabaseConstants.colUserId: userId, // placeholder until auth
      DatabaseConstants.colCreatedAt: createdAt.toUtc().toIso8601String(),
      DatabaseConstants.colUpdatedAt: updatedAt.toUtc().toIso8601String(),
      DatabaseConstants.colIsDeleted: isDeleted ? 1 : 0,
      DatabaseConstants.colSyncStatus: syncStatus.name,
    };
  }

  /// Deserializes from a DB column map.
  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      deckId: map[DatabaseConstants.colDeckId] as String,
      parentId: map[DatabaseConstants.colParentId] as String?,
      deckName: map[DatabaseConstants.colDeckName] as String,
      createdAt: DateTime.parse(map[DatabaseConstants.colCreatedAt] as String),
      updatedAt: DateTime.parse(map[DatabaseConstants.colUpdatedAt] as String),
      isDeleted: map[DatabaseConstants.colIsDeleted] == 1,
      syncStatus: SyncStatus.values.byName(map[DatabaseConstants.colSyncStatus] as String),
      userId: map[DatabaseConstants.colUserId] as String,
    );
  }

  @override
  List<Object?> get props => [deckId, parentId, deckName, createdAt, updatedAt, isDeleted, userId, syncStatus];
}

class Optional<T> {
  // allows you to set a field to null explicitly, or leave it unchanged
  final T? value;
  final bool isSet;

  const Optional.value(this.value) : isSet = true;
  const Optional.unset() : value = null, isSet = false;
}
