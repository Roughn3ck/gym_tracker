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
    final List<Map<String, dynamic>> maps = await db.query('SESSIONS');
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
    final List<Map<String, dynamic>> maps = await db.query('BODY_STATS');
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
      where: 'BodyPart = ?',
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

  Future<int> insertExerciseBodyPart(ExerciseBodyPart exerciseBodyPart) async {
    final db = await _databaseHelper.database;
    return await db.insert('EXERCISE_BODY_PARTS', exerciseBodyPart.toMap());
  }

  Future<int> deleteExerciseBodyPart(String exercise, String bodyPart) async {
    final db = await _databaseHelper.database;
    return await db.delete(
      'EXERCISE_BODY_PARTS',
      where: 'Exercise = ? AND BodyPart = ?',
      whereArgs: [exercise, bodyPart],
    );
  }

  /// WEIGHT_TRAINING table operations
  Future<List<WeightTraining>> getAllWeightTrainingRecords() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query('WEIGHT_TRAINING');
    return maps.map((map) => WeightTraining.fromMap(map)).toList();
  }

  Future<List<WeightTraining>> getWeightTrainingBySessionId(int sessionId) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'WEIGHT_TRAINING',
      where: 'Session_ID = ?',
      whereArgs: [sessionId],
    );
    return maps.map((map) => WeightTraining.fromMap(map)).toList();
  }

  Future<List<WeightTraining>> getWeightTrainingByExercise(String exercise) async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'WEIGHT_TRAINING',
      where: 'Exercise = ?',
      whereArgs: [exercise],
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