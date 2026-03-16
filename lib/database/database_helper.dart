import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Database helper class for managing SQLite database operations
class DatabaseHelper {
  static const String _databaseName = 'kris_gym.db';
  static const int _databaseVersion = 1;

  // Singleton instance
  static Database? _database;
  static DatabaseHelper? _instance;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    // Check if database exists
    final exists = await databaseExists(path);

    if (!exists) {
        // Database doesn't exist, copy from assets
        try {
          await Directory(dirname(path)).create(recursive: true);
          final ByteData data = await rootBundle.load('assets/databases/$_databaseName');
          final List<int> bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
          await File(path).writeAsBytes(bytes, flush: true);
        } catch (e) {
          throw Exception('Failed to copy database from assets: $e');
        }
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onOpen: (db) async {
        // Verify database integrity
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Close the database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  /// Get all records from a table
  Future<List<Map<String, dynamic>>> getAllRecords(String tableName) async {
    final db = await database;
    return await db.query(tableName);
  }

  /// Get records from a table with optional where clause
  Future<List<Map<String, dynamic>>> getRecords(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      tableName,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  /// Insert a record into a table
  Future<int> insert(String tableName, Map<String, dynamic> values) async {
    final db = await database;
    return await db.insert(tableName, values);
  }

  /// Update records in a table
  Future<int> update(
    String tableName,
    Map<String, dynamic> values, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.update(
      tableName,
      values,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Delete records from a table
  Future<int> delete(
    String tableName, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    return await db.delete(
      tableName,
      where: where,
      whereArgs: whereArgs,
    );
  }

  /// Execute raw SQL query
  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  /// Get table schema information
  Future<List<Map<String, dynamic>>> getTableSchema(String tableName) async {
    final db = await database;
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }

  /// Get all table names in the database
  Future<List<String>> getTableNames() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
    );
    return result.map((map) => map['name'] as String).toList();
  }

  /// Check if a table exists
  Future<bool> tableExists(String tableName) async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
      [tableName],
    );
    return result.isNotEmpty;
  }
}