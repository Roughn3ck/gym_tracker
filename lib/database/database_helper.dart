import 'dart:io';
import 'dart:typed_data';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Database helper class for managing SQLite database operations.
///
/// Supports two modes:
/// - **Internal** (default): copies the bundled `gym_tracker.db` asset into the
///   app's private storage on first launch. This is the zero-config experience.
/// - **External**: opens a user-specified `.db` file directly at its filesystem
///   path — no copying. The path is persisted in SharedPreferences so the choice
///   survives app restarts. External tools can read/write the same file.
///
/// Key invariant: [getDatabasePath] always returns the **internal** path
/// (regardless of mode), so [importDatabase] and the export/share flow always
/// operate on the internal DB. The external path is exposed via
/// [externalDbPath].
class DatabaseHelper {
  static const String _databaseName = 'gym_tracker.db';
  static const int _databaseVersion = 3;

  /// SharedPreferences key for persisting the external DB path.
  static const String _prefsKeyExternalDbPath = 'external_db_path';

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

  /// User-facing message returned by [setExternalDatabase] on success.
  static const String externalDbSuccessMessage = 'External database loaded.';

  // Singleton instance
  static Database? _database;
  static DatabaseHelper? _instance;

  // --- External DB state ---
  /// The persisted external DB path, or null when using the internal DB.
  /// Loaded from SharedPreferences on first access via [loadPersistedPath].
  static String? _externalDbPath;

  /// Whether [loadPersistedPath] has been called at least once.
  static bool _pathLoaded = false;

  DatabaseHelper._internal();

  factory DatabaseHelper() {
    _instance ??= DatabaseHelper._internal();
    return _instance!;
  }

  /// Whether the database is currently using an external file.
  bool get isExternal => _externalDbPath != null && _externalDbPath!.isNotEmpty;

  /// Returns the path to the external database file, or null if using internal.
  String? get externalDbPath => _externalDbPath;

  /// Get the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Loads a persisted external DB path from SharedPreferences on startup.
  /// Called once before the first database access (inside [_initDatabase]).
  Future<void> loadPersistedPath() async {
    if (_pathLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _externalDbPath = prefs.getString(_prefsKeyExternalDbPath);
    } catch (e) {
      // If prefs can't be read, we just fall back to internal mode.
      _externalDbPath = null;
    }
    _pathLoaded = true;
  }

  /// Resolves the database path: external path if set and the file exists,
  /// otherwise the internal path. Also ensures the internal DB is copied from
  /// assets if it doesn't exist yet (only for internal mode).
  Future<String> _resolvePath() async {
    // Ensure the persisted path has been loaded.
    if (!_pathLoaded) {
      await loadPersistedPath();
    }

    // External mode: use the external path if the file still exists.
    if (_externalDbPath != null && _externalDbPath!.isNotEmpty) {
      if (await File(_externalDbPath!).exists()) {
        return _externalDbPath!;
      }
      // External file is gone — fall back to internal with a warning.
      // (A proper error dialog will be added in a later version.)
      _externalDbPath = null;
    }

    // Internal mode: compute the internal path and copy from assets if needed.
    final databasesPath = await getDatabasesPath();
    final internalPath = join(databasesPath, _databaseName);

    final exists = await databaseExists(internalPath);
    if (!exists) {
      try {
        await Directory(dirname(internalPath)).create(recursive: true);
        final ByteData data =
            await rootBundle.load('assets/databases/$_databaseName');
        final List<int> bytes =
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        await File(internalPath).writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception('Failed to copy database from assets: $e');
      }
    }

    return internalPath;
  }

  /// Initialize the database
  Future<Database> _initDatabase() async {
    // On desktop platforms (Windows, macOS, Linux), sqflite needs the FFI
    // implementation. On mobile (Android/iOS) the default factory works.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final path = await _resolvePath();

    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onOpen: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );

    // Fix legacy UNIQUE constraint on SESSIONS.Date if present.
    // This is a no-op for databases created from the v3 asset template.
    await _fixSessionsUniqueConstraintIfPresent(db);

    return db;
  }

  /// Get the **internal** database file path (for export/import).
  ///
  /// This always returns the internal path regardless of whether external
  /// mode is active. This ensures [importDatabase] always replaces the
  /// internal DB (never the external one), and the share/export flow always
  /// shares the internal DB.
  Future<String?> getDatabasePath() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);
    return path;
  }

  /// Sets the database to use an external file at [path].
  ///
  /// Validates the file is a v3 Gym Tracker DB (read-only check), then:
  /// 1. Closes the current connection.
  /// 2. Persists the path to SharedPreferences.
  /// 3. Sets [_externalDbPath].
  /// 4. Reopens so the app reads from the external file immediately.
  ///
  /// Returns [externalDbSuccessMessage] on success, or a user-facing error
  /// string if validation fails. On any failure the current DB state is
  /// left untouched.
  Future<String> setExternalDatabase(String path) async {
    // --- Validate the candidate file BEFORE touching the live DB ---
    final validationError = await _validateV3Database(path);
    if (validationError != null) {
      return validationError;
    }

    // --- Close the current connection ---
    try {
      await close();
    } catch (e) {
      return 'Failed to close the current database ($e).';
    }

    // --- Persist the external path ---
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKeyExternalDbPath, path);
    } catch (e) {
      // Prefs write failed — reopen the old DB and bail out.
      await _reopen();
      return 'Failed to persist the external database path ($e).';
    }

    _externalDbPath = path;

    // --- Reopen so the app uses the external file ---
    try {
      await _reopen();
    } catch (e) {
      return 'External database was set but could not be opened ($e). '
          'Please restart the app.';
    }

    return externalDbSuccessMessage;
  }

  /// Reverts to the internal database.
  ///
  /// Closes the current connection, clears the persisted external path, and
  /// reopens. If the internal DB doesn't exist yet, it will be created from
  /// assets on the next open (via [_resolvePath]).
  Future<void> useInternalDatabase() async {
    await close();

    // Clear the persisted external path.
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKeyExternalDbPath);
    } catch (_) {
      // Best-effort — the in-memory flag is cleared below regardless.
    }

    _externalDbPath = null;

    // Reopen — _resolvePath will fall back to the internal path.
    await _reopen();
  }

  /// Validates, backs up, and replaces the live **internal** app database with
  /// the file at [sourcePath] (an absolute path to a candidate v3 SQLite file).
  ///
  /// This always targets the internal DB (via [getDatabasePath]), even when
  /// external mode is active. If the user is in external mode, the UI should
  /// show a warning before calling this.
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
    // Note: if we're in external mode, the import replaced the *internal* DB,
    // but the app is still pointed at the external file. The user would need
    // to switch back to internal to see the imported data. The UI warns about
    // this before allowing import in external mode.
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
      return 'The selected file does not exist.';
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

  /// Checks if the SESSIONS table has a UNIQUE constraint on the Date column
  /// and removes it if present. This fixes legacy external databases (pre-v0.1.0)
  /// that have `Date TEXT NOT NULL UNIQUE`, which prevents saving two sessions
  /// on the same date.
  ///
  /// Called from [_initDatabase] after the DB is opened. For internal databases
  /// (created from the v3 asset template), this is a no-op since there's no
  /// UNIQUE constraint.
  Future<void> _fixSessionsUniqueConstraintIfPresent(Database db) async {
    try {
      final schema = await db.rawQuery(
        "SELECT sql FROM sqlite_master WHERE type='table' AND name='SESSIONS'",
      );
      if (schema.isEmpty) return;

      final createSql = schema.first['sql'] as String;
      if (!createSql.toUpperCase().contains('UNIQUE')) return;

      // Recreate the table without UNIQUE constraint
      await db.execute('''
        CREATE TABLE SESSIONS_new (
          ID INTEGER PRIMARY KEY AUTOINCREMENT,
          Date TEXT NOT NULL,
          Workout TEXT,
          BodyParts TEXT,
          RunDistance REAL,
          RunTime INTEGER,
          SaunaDuration INTEGER,
          BodyWeight REAL,
          TrainingStyle TEXT,
          Other TEXT
        )
      ''');

      // Copy all data from the old table
      await db.execute('''
        INSERT INTO SESSIONS_new (Date, Workout, BodyParts, RunDistance, RunTime, SaunaDuration, BodyWeight, TrainingStyle, Other)
        SELECT Date, Workout, BodyParts, RunDistance, RunTime, SaunaDuration, BodyWeight, TrainingStyle, Other FROM SESSIONS
      ''');

      // Drop old table and rename new
      await db.execute('DROP TABLE SESSIONS');
      await db.execute('ALTER TABLE SESSIONS_new RENAME TO SESSIONS');
    } catch (_) {
      // Best-effort — if it fails, the app will still work but with the constraint.
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