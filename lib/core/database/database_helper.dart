import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_constants.dart';

/// Singleton helper that owns the app's SQLite [Database] connection.
class DatabaseHelper {
  final String _dbName;

  DatabaseHelper._({String? dbName})
      : _dbName = dbName ?? DatabaseConstants.databaseName;
  static final DatabaseHelper instance = DatabaseHelper._();

  /// Creates an independent instance with its own DB file for testing.
  @visibleForTesting
  DatabaseHelper.forTesting({String dbName = 'test.db'}) : _dbName = dbName;

  Database? _database;

  /// Returns the open database, creating it on first access.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: DatabaseConstants.databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Enables FK enforcement for every new connection.
  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Runs all v1 DDL from [DatabaseConstants.createStatements].
  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    for (final sql in DatabaseConstants.createStatements) {
      batch.execute(sql);
    }
    await batch.commit(noResult: true);
  }

  /// Sequential migration loop for future schema versions.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    for (var version = oldVersion + 1; version <= newVersion; version++) {
      switch (version) {
        case 2:
          await _migrateV2(db);
          break;
        default:
          break;
      }
    }
  }

  /// v2: Add step column to cards table for FSRS learning step tracking.
  Future<void> _migrateV2(Database db) async {
    final columns = await db.rawQuery(
      'PRAGMA table_info(${DatabaseConstants.tableCards})',
    );
    final hasStep = columns.any((col) => col['name'] == DatabaseConstants.colStep);
    if (!hasStep) {
      await db.execute(
        'ALTER TABLE ${DatabaseConstants.tableCards} ADD COLUMN ${DatabaseConstants.colStep} INTEGER',
      );
    }
  }

  /// Deletes all rows from every table, preserving the schema.
  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(DatabaseConstants.tableReviews);
      await txn.delete(DatabaseConstants.tableCards);
      await txn.delete(DatabaseConstants.tableDecks);
    });
  }

  /// Closes the database and resets the cached reference.
  /// Primarily used for test teardown.
  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
