import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Database helper class for managing SQLite database operations
class DatabaseHelper {
  static const String _databaseName = 'gym_tracker.db';
  static const int _databaseVersion = 3;

  /// The 10 canonical v3 body part names. A valid v3 import must contain
  /// exactly these in BODY_PARTS (order-independent). Kept in sync with the
  /// CHECK constraint in create_db.py and the bundled asset.
  static const List<String> canonicalBodyParts = [
    'Quads', 'Hamstrings', 'Calves', 'Glutes', 'Chest',
    'Biceps', 'Triceps', 'Back', 'Shoulders', 'Abs',
  ];

  /// User-facing message returned by [importDatabase] on success. The UI
  /// compares against this to decide whether to refresh after an import.
  static const String importSuccessMessage = 'Database imported successfully.';

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
    // On desktop platforms (Windows, macOS, Linux), sqflite needs the FFI
    // implementation. On mobile (Android/iOS) the default factory works.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

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
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  /// Get the database file path (for export)
  Future<String?> getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    return path;
  }

  /// Validates, backs up, and replaces the live app database with the file at
  /// [sourcePath] (an absolute path to a candidate v3 SQLite file).
  ///
  /// Returns [importSuccessMessage] on success, or a user-facing error string
  /// describing why the import was refused or failed. On any failure the live
  /// DB is left untouched (and restored from backup if a partial copy left it
  /// in a bad state).
  ///
  /// Steps:
  /// 1. Validate the source file is a v3 Gym Tracker DB (read-only, no writes).
  /// 2. Close the current connection, copy the live DB to a timestamped backup.
  /// 3. Copy the source file over the live DB path.
  /// 4. Reopen so the app reads the imported data immediately.
  Future<String> importDatabase(String sourcePath) async {
    // --- Step 1: validate the source BEFORE touching the live DB ---
    final validationError = await _validateV3Database(sourcePath);
    if (validationError != null) {
      return validationError;
    }

    final livePath = await getDatabasePath();
    if (livePath == null) {
      return 'Import failed: could not resolve the live database path.';
    }

    // --- Step 2: close + back up the current DB ---
    try {
      await close();
    } catch (e) {
      return 'Import failed: could not close the current database ($e).';
    }

    final liveFile = File(livePath);
    String? backupPath;
    if (await liveFile.exists()) {
      final stamp = _timestamp();
      backupPath = '$livePath.backup.$stamp';
      try {
        await liveFile.copy(backupPath);
      } catch (e) {
        // Backup failed — we've already closed the connection, so try to
        // reopen the live DB before returning so the app keeps working.
        await _reopen();
        return 'Import failed: could not create backup ($e).';
      }
    }

    // --- Step 3: copy the source over the live path ---
    final sourceFile = File(sourcePath);
    try {
      await sourceFile.copy(livePath);
    } catch (e) {
      // Copy failed — restore the backup (if any) so we don't leave a
      // half-written or missing live DB.
      if (backupPath != null) {
        try {
          await File(backupPath).copy(livePath);
        } catch (_) {
          // Best-effort restore; fall through to the error below.
        }
      }
      await _reopen();
      return 'Import failed: could not copy the selected file ($e).';
    }

    // --- Step 4: reopen the connection so the app uses the imported data ---
    try {
      await _reopen();
    } catch (e) {
      // Reopen failed — the file on disk is the imported one, but we can't
      // open it. Surface a clear error; the user can restart the app.
      return 'Import copied but failed to reopen the database ($e). '
          'Please restart the app.';
    }

    return importSuccessMessage;
  }

  /// Validates that the SQLite file at [sourcePath] is a genuine v3 Gym Tracker
  /// database, using a temporary read-only connection. Returns `null` if valid,
  /// or a user-facing error string if not.
  ///
  /// Checks: required tables exist, SESSIONS has `Workout` + `BodyParts`
  /// columns (the v3 signature), and BODY_PARTS contains exactly the 10
  /// canonical names.
  Future<String?> _validateV3Database(String sourcePath) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return 'Import failed: the selected file does not exist.';
    }

    // Open the candidate read-only so there's no chance of mutating it.
    Database? candidate;
    try {
      candidate = await openDatabase(
        sourcePath,
        readOnly: true,
      );
    } catch (e) {
      return 'This file is not a valid SQLite database.';
    }

    try {
      // (a) Required tables.
      final requiredTables = [
        'SESSIONS', 'BODY_STATS', 'BODY_PARTS',
        'EXERCISE_BODY_PARTS', 'WEIGHT_TRAINING',
      ];
      final existingTables = await candidate.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
      );
      final existing = existingTables.map((r) => r['name'] as String).toSet();
      for (final t in requiredTables) {
        if (!existing.contains(t)) {
          return 'This database is missing required tables '
              '(no "$t"). It is not a Gym Tracker database.';
        }
      }

      // (b) v3 signature: SESSIONS must have both Workout and BodyParts.
      final sessionCols = await candidate.rawQuery('PRAGMA table_info(SESSIONS)');
      final colNames = sessionCols.map((r) => r['name'] as String).toSet();
      if (!colNames.contains('Workout') || !colNames.contains('BodyParts')) {
        return 'This database is not a Gym Tracker v3 database '
            '(missing Workout/BodyParts columns).';
      }

      // (c) BODY_PARTS must contain exactly the 10 canonical names.
      final bpRows = await candidate.query('BODY_PARTS', columns: ['Name']);
      final bpNames = bpRows.map((r) => r['Name'] as String).toSet();
      final expected = canonicalBodyParts.toSet();
      final missing = expected.difference(bpNames);
      final extra = bpNames.difference(expected);
      if (bpNames.length != expected.length ||
          missing.isNotEmpty ||
          extra.isNotEmpty) {
        final bits = <String>[];
        if (missing.isNotEmpty) bits.add('missing: ${missing.join(', ')}');
        if (extra.isNotEmpty) bits.add('unexpected: ${extra.join(', ')}');
        return 'Body part taxonomy mismatch (${bits.join('; ')}).';
      }

      return null; // all checks passed
    } finally {
      await candidate.close();
    }
  }

  /// Re-opens the singleton database connection by clearing the cached
  /// `_database` so the next `database` access re-initialises it via the
  /// existing lazy getter (which recomputes the path and re-applies the
  /// desktop-FFI setup).
  Future<void> _reopen() async {
    _database = null;
    await database;
  }

  /// Builds a `yyyyMMdd-HHmmss` timestamp for backup filenames.
  String _timestamp() {
    final n = DateTime.now();
    String p(int v) => v.toString().padLeft(2, '0');
    return '${n.year}${p(n.month)}${p(n.day)}-${p(n.hour)}${p(n.minute)}${p(n.second)}';
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