import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/session.dart';
import '../models/body_stat.dart';
import '../models/body_part.dart';
import '../models/exercise_body_part.dart';
import '../models/weight_training.dart';

/// Repository class for managing gym-related database operations
class GymRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  /// SESSIONS table operations
  Future<List<Session>> getAllSessions() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'SESSIONS',
      orderBy: 'Date DESC',
    );
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<Session?> getSessionById(int id) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'SESSIONS',
      where: 'ID = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Session.fromMap(maps.first);
  }

  Future<List<Session>> getSessionsByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'SESSIONS',
      where: 'Date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map((map) => Session.fromMap(map)).toList();
  }

  Future<int> insertSession(Session session) async {
    final db = await _databaseHelper.database;
    return await db.insert('SESSIONS', session.toMap());
  }

  Future<int> updateSession(Session session) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'SESSIONS',
      session.toMap(),
      where: 'ID = ?',
      whereArgs: [session.id],
    );
  }

  Future<int> deleteSession(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'SESSIONS',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// BODY_STATS table operations
  Future<List<BodyStat>> getAllBodyStats() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'BODY_STATS',
      orderBy: 'Date DESC',
    );
    return maps.map((map) => BodyStat.fromMap(map)).toList();
  }

  Future<List<BodyStat>> getBodyStatsByDateRange(DateTime start, DateTime end) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'BODY_STATS',
      where: 'Date BETWEEN ? AND ?',
      whereArgs: [start.toIso8601String(), end.toIso8601String()],
    );
    return maps.map((map) => BodyStat.fromMap(map)).toList();
  }

  Future<int> insertBodyStat(BodyStat bodyStat) async {
    final db = await _databaseHelper.database;
    return await db.insert('BODY_STATS', bodyStat.toMap());
  }

  Future<int> updateBodyStat(BodyStat bodyStat) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'BODY_STATS',
      bodyStat.toMap(),
      where: 'ID = ?',
      whereArgs: [bodyStat.id],
    );
  }

  Future<int> deleteBodyStat(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'BODY_STATS',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// BODY_PARTS table operations
  Future<List<BodyPart>> getAllBodyParts() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('BODY_PARTS');
    return maps.map((map) => BodyPart.fromMap(map)).toList();
  }

  Future<BodyPart?> getBodyPartByName(String name) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'BODY_PARTS',
      where: 'Name = ?',
      whereArgs: [name],
    );
    if (maps.isEmpty) return null;
    return BodyPart.fromMap(maps.first);
  }

  /// EXERCISE_BODY_PARTS table operations
  Future<List<ExerciseBodyPart>> getAllExerciseBodyParts() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('EXERCISE_BODY_PARTS');
    return maps.map((map) => ExerciseBodyPart.fromMap(map)).toList();
  }

  Future<List<ExerciseBodyPart>> getExerciseBodyPartsByExercise(String exercise) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'EXERCISE_BODY_PARTS',
      where: 'Exercise = ?',
      whereArgs: [exercise],
    );
    return maps.map((map) => ExerciseBodyPart.fromMap(map)).toList();
  }

  Future<List<ExerciseBodyPart>> getExerciseBodyPartsByBodyPart(String bodyPart) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'EXERCISE_BODY_PARTS',
      where: 'BodyPart = ?',
      whereArgs: [bodyPart],
    );
    return maps.map((map) => ExerciseBodyPart.fromMap(map)).toList();
  }

  /// Get all distinct exercise names from EXERCISE_BODY_PARTS
  Future<List<String>> getAllExerciseNames() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT DISTINCT Exercise FROM EXERCISE_BODY_PARTS ORDER BY Exercise',
    );
    return result.map((map) => map['Exercise'] as String).toList();
  }

  /// Add a new exercise with multiple body parts.
  /// Inserts one row per body part into EXERCISE_BODY_PARTS.
  Future<void> addExercise(String name, List<String> bodyParts) async {
    final db = await _databaseHelper.database;
    for (final bodyPart in bodyParts) {
      await db.insert(
        'EXERCISE_BODY_PARTS',
        {'Exercise': name, 'BodyPart': bodyPart},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<int> deleteExerciseBodyPart(String exercise, String bodyPart) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'EXERCISE_BODY_PARTS',
      where: 'Exercise = ? AND BodyPart = ?',
      whereArgs: [exercise, bodyPart],
    );
  }

  /// Delete all body part mappings for an exercise
  Future<int> deleteExercise(String exercise) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'EXERCISE_BODY_PARTS',
      where: 'Exercise = ?',
      whereArgs: [exercise],
    );
  }

  /// WEIGHT_TRAINING table operations
  Future<List<WeightTraining>> getAllWeightTrainingRecords() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'WEIGHT_TRAINING',
      orderBy: 'Date DESC',
    );
    return maps.map((map) => WeightTraining.fromMap(map)).toList();
  }

  /// Get all weight training records for a specific exercise, newest first
  Future<List<WeightTraining>> getWeightTrainingByExercise(String exercise) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'WEIGHT_TRAINING',
      where: 'Exercises = ?',
      whereArgs: [exercise],
      orderBy: 'Date DESC',
    );
    return maps.map((map) => WeightTraining.fromMap(map)).toList();
  }

  /// Get the most recent weight training record for an exercise
  Future<WeightTraining?> getLatestWeightForExercise(String exercise, [String? trainingStyle]) async {
    final db = await _databaseHelper.database;
    if (trainingStyle != null) {
      final List<Map<String, dynamic>> maps = await db.query('WEIGHT_TRAINING',
        where: 'Exercises = ? AND TrainingStyle = ?',
        whereArgs: [exercise, trainingStyle],
        orderBy: 'Date DESC',
        limit: 1,
      );
      if (maps.isEmpty) return null;
      return WeightTraining.fromMap(maps.first);
    }
    final List<Map<String, dynamic>> maps = await db.query('WEIGHT_TRAINING',
      where: 'Exercises = ?',
      whereArgs: [exercise],
      orderBy: 'Date DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return WeightTraining.fromMap(maps.first);
  }

  /// Get weight training records by training style
  Future<List<WeightTraining>> getWeightTrainingByStyle(String trainingStyle) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'WEIGHT_TRAINING',
      where: 'TrainingStyle = ?',
      whereArgs: [trainingStyle],
      orderBy: 'Date DESC',
    );
    return maps.map((map) => WeightTraining.fromMap(map)).toList();
  }

  Future<int> insertWeightTraining(WeightTraining weightTraining) async {
    final db = await _databaseHelper.database;
    return await db.insert('WEIGHT_TRAINING', weightTraining.toMap());
  }

  Future<int> updateWeightTraining(WeightTraining weightTraining) async {
    final db = await _databaseHelper.database;
    return await db.update(
      'WEIGHT_TRAINING',
      weightTraining.toMap(),
      where: 'ID = ?',
      whereArgs: [weightTraining.id],
    );
  }

  Future<int> deleteWeightTraining(int id) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'WEIGHT_TRAINING',
      where: 'ID = ?',
      whereArgs: [id],
    );
  }

  /// Get exercises matching any of the given body parts (for workout flow)
  Future<List<String>> getExerciseNamesByBodyParts(List<String> bodyParts) async {
    if (bodyParts.isEmpty) return [];
    final db = await _databaseHelper.database;
    final placeholders = List.filled(bodyParts.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT DISTINCT Exercise FROM EXERCISE_BODY_PARTS WHERE BodyPart IN ($placeholders) ORDER BY Exercise',
      bodyParts,
    );
    return result.map((map) => map['Exercise'] as String).toList();
  }

  /// Get the most recent body weight from SESSIONS
  Future<double?> getLatestBodyWeight() async {
    final db = await _databaseHelper.database;
    final result = await db.rawQuery(
      'SELECT BodyWeight FROM SESSIONS WHERE BodyWeight IS NOT NULL ORDER BY Date DESC LIMIT 1',
    );
    if (result.isEmpty) return null;
    return result.first['BodyWeight'] as double?;
  }

  /// Utility methods
  Future<void> close() async {
    await _databaseHelper.close();
  }

  /// Get database statistics
  Future<Map<String, int>> getDatabaseStats() async {
    final db = await _databaseHelper.database;
    final tables = await _databaseHelper.getTableNames();
    
    final stats = <String, int>{};
    for (final table in tables) {
      final count = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table')
      ) ?? 0;
      stats[table] = count;
    }
    
    return stats;
  }
}