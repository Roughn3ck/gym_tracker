import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/models/session.dart';
import 'package:gym_tracker/models/body_stat.dart';
import 'package:gym_tracker/models/weight_training.dart';
import 'package:gym_tracker/models/body_part.dart';
import 'package:gym_tracker/models/exercise_body_part.dart';

void main() {
  runApp(const GymTrackerApp());
}

class GymTrackerApp extends StatelessWidget {
  const GymTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gym Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: ChangeNotifierProvider(
        create: (context) => GymRepository(),
        child: const DatabaseTestPage(),
      ),
    );
  }
}

class DatabaseTestPage extends StatefulWidget {
  const DatabaseTestPage({super.key});

  @override
  State<DatabaseTestPage> createState() => _DatabaseTestPageState();
}

class _DatabaseTestPageState extends State<DatabaseTestPage> {
  String _status = 'Initializing...';
  List<String> _tableNames = [];
  Map<String, int> _recordCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      
      // Initialize database
      await repository.init();
      
      // Get table names
      final tables = await repository.getTableNames();
      setState(() {
        _tableNames = tables;
        _status = 'Database initialized successfully';
      });

      // Get record counts for each table
      for (final table in tables) {
        final count = await repository.getRecordCount(table);
        setState(() {
          _recordCounts[table] = count;
        });
      }

      // Test some data retrieval
      final sessions = await repository.getAllSessions();
      final bodyStats = await repository.getAllBodyStats();
      final weightTrainings = await repository.getAllWeightTrainings();
      final bodyParts = await repository.getAllBodyParts();
      final exerciseBodyParts = await repository.getAllExerciseBodyParts();

      setState(() {
        _isLoading = false;
        _status = 'Database test completed successfully';
      });

      print('Sessions: ${sessions.length} records');
      print('Body Stats: ${bodyStats.length} records');
      print('Weight Trainings: ${weightTrainings.length} records');
      print('Body Parts: ${bodyParts.length} records');
      print('Exercise Body Parts: ${exerciseBodyParts.length} records');

    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gym Tracker - Database Test'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _status,
              style: TextStyle(
                fontSize: 16,
                color: _status.contains('Error') ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              const Text(
                'Database Tables:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              ..._tableNames.map((table) => ListTile(
                title: Text(table),
                trailing: Text('${_recordCounts[table] ?? 0} records'),
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              )).toList(),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _initializeDatabase,
                child: const Text('Refresh Database'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}