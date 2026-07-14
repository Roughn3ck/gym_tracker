import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/models/body_part.dart';
import 'package:gym_tracker/models/session.dart';
import 'package:gym_tracker/models/weight_training.dart';
import 'package:gym_tracker/state/training_state.dart';
import 'package:gym_tracker/state/data_refresh_notifier.dart';

/// Visual state of an exercise entry in the workout screen.
enum ExerciseEntryState { idle, expanded, completed }

/// Screen for starting and logging a workout session
class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  // Session data
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedBodyParts = {};
  final _workoutController = TextEditingController();
  final _bodyWeightController = TextEditingController();
  final _runDistanceController = TextEditingController();
  final _runTimeController = TextEditingController();
  final _saunaController = TextEditingController();
  final _notesController = TextEditingController();

  // Exercise data
  List<BodyPart> _allBodyParts = [];
  List<String> _availableExercises = [];
  List<_ExerciseEntry> _exerciseEntries = [];
  final Map<String, WeightTraining?> _latestWeights = {};
  double? _lastBodyWeight;
  bool _isLoading = false;
  int _lastRefreshCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _workoutController.dispose();
    _bodyWeightController.dispose();
    _runDistanceController.dispose();
    _runTimeController.dispose();
    _saunaController.dispose();
    _notesController.dispose();
    for (final entry in _exerciseEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final bodyParts = await repository.getAllBodyParts();
      final lastWeight = await repository.getLatestBodyWeight();

      if (mounted) {
        setState(() {
          _allBodyParts = bodyParts;
          _lastBodyWeight = lastWeight;
          if (lastWeight != null) {
            _bodyWeightController.text = lastWeight.toString();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onBodyPartsChanged() async {
    if (_selectedBodyParts.isEmpty) {
      setState(() {
        _availableExercises = [];
        for (final entry in _exerciseEntries) {
          entry.dispose();
        }
        _exerciseEntries.clear();
      });
      return;
    }

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final exercises = await repository.getExerciseNamesByBodyParts(
        _selectedBodyParts.toList(),
      );

      // Load latest weights for these exercises (only for ones not yet loaded)
      final trainingState = Provider.of<TrainingState>(context, listen: false);
      for (final name in exercises) {
        if (!_latestWeights.containsKey(name)) {
          _latestWeights[name] =
              await repository.getLatestWeightForExercise(name, trainingState.currentModeName);
        }
      }

      // Preserve existing entries (completed/expanded states) for exercises
      // still in the list. Create new idle entries for new exercises.
      // Dispose entries for exercises no longer in the list.
      final existingByName = <String, _ExerciseEntry>{};
      for (final entry in _exerciseEntries) {
        existingByName[entry.name] = entry;
      }

      final newEntries = <_ExerciseEntry>[];
      for (final name in exercises) {
        if (existingByName.containsKey(name)) {
          // Keep existing entry (preserves completed/expanded state)
          newEntries.add(existingByName[name]!);
          existingByName.remove(name);
        } else {
          // Create new idle entry with pre-filled data from latest weight
          final latest = _latestWeights[name];
          newEntries.add(_ExerciseEntry(
            name: name,
            weight: latest?.weight ?? '',
            reps: latest?.reps.toString() ?? '',
            sets: latest?.sets.toString() ?? '',
          ));
        }
      }

      // Dispose entries for exercises no longer in the list
      for (final entry in existingByName.values) {
        entry.dispose();
      }

      if (!mounted) return;
      setState(() {
        _availableExercises = exercises;
        _exerciseEntries = newEntries;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load exercises: $e')),
      );
    }
  }

  /// Reloads the exercise list when new exercises have been added in the
  /// Exercises tab. Called when DataRefreshNotifier fires.
  Future<void> _refreshExercisesAfterDataChange() async {
    if (_selectedBodyParts.isEmpty) return;
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final exercises = await repository.getExerciseNamesByBodyParts(
        _selectedBodyParts.toList(),
      );

      // Refresh latest weights cache for all exercises
      final trainingState = Provider.of<TrainingState>(context, listen: false);
      for (final name in exercises) {
        _latestWeights[name] =
            await repository.getLatestWeightForExercise(name, trainingState.currentModeName);
      }

      // Preserve existing entries, add new ones
      final existingByName = <String, _ExerciseEntry>{};
      for (final entry in _exerciseEntries) {
        existingByName[entry.name] = entry;
      }

      final newEntries = <_ExerciseEntry>[];
      for (final name in exercises) {
        if (existingByName.containsKey(name)) {
          newEntries.add(existingByName[name]!);
          existingByName.remove(name);
        } else {
          final latest = _latestWeights[name];
          newEntries.add(_ExerciseEntry(
            name: name,
            weight: latest?.weight ?? '',
            reps: latest?.reps.toString() ?? '',
            sets: latest?.sets.toString() ?? '',
          ));
        }
      }

      for (final entry in existingByName.values) {
        entry.dispose();
      }

      if (!mounted) return;
      setState(() {
        _availableExercises = exercises;
        _exerciseEntries = newEntries;
      });
    } catch (_) {
      // Best-effort refresh
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  // --- Exercise state transitions ---

  void _onTrain(_ExerciseEntry entry) {
    setState(() {
      for (final e in _exerciseEntries) {
        if (e.state == ExerciseEntryState.expanded) {
          e.state = ExerciseEntryState.completed;
        }
      }
      entry.state = ExerciseEntryState.expanded;
    });
  }

  void _onComplete(_ExerciseEntry entry) {
    setState(() {
      entry.state = ExerciseEntryState.completed;
    });
  }

  void _onEdit(_ExerciseEntry entry) {
    setState(() {
      for (final e in _exerciseEntries) {
        if (e.state == ExerciseEntryState.expanded) {
          e.state = ExerciseEntryState.completed;
        }
      }
      entry.state = ExerciseEntryState.expanded;
    });
  }

  Future<void> _saveSession() async {
    // Body parts are no longer required — a session can be just cardio,
    // sauna, body weight, or notes without any exercises.
    final trainingState = Provider.of<TrainingState>(context, listen: false);
    final repository = Provider.of<GymRepository>(context, listen: false);

    try {
      // Auto-complete any currently expanded exercise before saving
      for (final entry in _exerciseEntries) {
        if (entry.state == ExerciseEntryState.expanded) {
          entry.state = ExerciseEntryState.completed;
        }
      }

      String notes = _notesController.text.trim();

      final workoutText = _workoutController.text.trim();
      final session = Session(
        date: _selectedDate,
        workout: workoutText.isEmpty ? null : workoutText,
        bodyParts: jsonEncode(_selectedBodyParts.toList()),
        runDistance: double.tryParse(_runDistanceController.text),
        runTime: int.tryParse(_runTimeController.text),
        saunaDuration: int.tryParse(_saunaController.text),
        bodyWeight: double.tryParse(_bodyWeightController.text),
        trainingStyle: trainingState.currentModeName,
        other: notes.isNotEmpty ? notes : null,
      );
      await repository.insertSession(session);
      if (!mounted) return;

      // Save only completed exercises with non-empty weight
      for (final entry in _exerciseEntries) {
        if (entry.state != ExerciseEntryState.completed) continue;
        if (entry.weightController.text.trim().isEmpty) continue;
        final wt = WeightTraining(
          date: _selectedDate,
          trainingStyle: trainingState.currentModeName,
          exercises: entry.name,
          weight: entry.weightController.text.trim(),
          reps: int.tryParse(entry.repsController.text) ?? 0,
          sets: int.tryParse(entry.setsController.text) ?? 0,
        );
        await repository.insertWeightTraining(wt);
      }

      if (!mounted) return;
      // Notify other screens (History, Exercises, Profile) to refresh.
      context.read<DataRefreshNotifier>().notifyDataChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session saved!')),
      );
      _resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save session: $e')),
      );
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedBodyParts.clear();
      _workoutController.clear();
      _runDistanceController.clear();
      _runTimeController.clear();
      _saunaController.clear();
      _notesController.clear();
      for (final entry in _exerciseEntries) {
        entry.dispose();
      }
      _exerciseEntries.clear();
      _availableExercises.clear();
      if (_lastBodyWeight != null) {
        _bodyWeightController.text = _lastBodyWeight.toString();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final trainingState = Provider.of<TrainingState>(context);

    // Watch the DataRefreshNotifier — when notifyDataChanged() fires (e.g.
    // after adding a new exercise in the Exercises tab), reload the exercise
    // list so new exercises appear automatically without toggling body parts.
    final notifier = Provider.of<DataRefreshNotifier>(context);
    if (notifier.refreshCount != _lastRefreshCount) {
      _lastRefreshCount = notifier.refreshCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshExercisesAfterDataChange();
      });
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Training Mode Toggle
                  _buildModeToggle(trainingState),
                  const SizedBox(height: 20),

                  // Session Setup
                  _buildSectionTitle('Session Setup'),
                  const SizedBox(height: 8),

                  // Date picker
                  InkWell(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Workout free-text description
                  TextFormField(
                    controller: _workoutController,
                    decoration: const InputDecoration(
                      labelText: 'Workout',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Body part selection
                  const Text('Body Parts (optional):'),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    children: _allBodyParts.map((bp) {
                      final selected = _selectedBodyParts.contains(bp.name);
                      return FilterChip(
                        label: Text(bp.name),
                        selected: selected,
                        onSelected: (value) {
                          setState(() {
                            if (value) {
                              _selectedBodyParts.add(bp.name);
                            } else {
                              _selectedBodyParts.remove(bp.name);
                            }
                          });
                          _onBodyPartsChanged();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),

                  // Body weight
                  TextFormField(
                    controller: _bodyWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Body Weight (kg)',
                      border: OutlineInputBorder(),
                      suffixText: 'kg',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 20),

                  // Exercises section
                  if (_exerciseEntries.isNotEmpty) ...[
                    _buildSectionTitle('Exercises'),
                    const SizedBox(height: 8),
                    for (final entry in _exerciseEntries)
                      _buildExerciseCard(entry),
                    const SizedBox(height: 20),
                  ],

                  // Cardio & Recovery
                  _buildSectionTitle('Cardio & Recovery'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _runDistanceController,
                          decoration: const InputDecoration(
                            labelText: 'Run Dist',
                            border: OutlineInputBorder(),
                            suffixText: 'km',
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _runTimeController,
                          decoration: const InputDecoration(
                            labelText: 'Run Time',
                            border: OutlineInputBorder(),
                            suffixText: 'min',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _saunaController,
                    decoration: const InputDecoration(
                      labelText: 'Sauna Duration',
                      border: OutlineInputBorder(),
                      suffixText: 'min',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),

                  // Notes
                  _buildSectionTitle('Notes'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Session Notes (additional runs, etc.)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),

                  // Save button
                  FilledButton.icon(
                    onPressed: _saveSession,
                    icon: const Icon(Icons.check),
                    label: const Text('Save Session'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _resetForm,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset Form'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 45),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildModeToggle(TrainingState trainingState) {
    return Card(
      elevation: 4,
      color: trainingState.currentModeColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trainingState.currentModeName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  trainingState.currentModeDescription,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
            ElevatedButton(
              onPressed: trainingState.toggleMode,
              style: ElevatedButton.styleFrom(
                backgroundColor: trainingState.currentModeColor,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Switch to ${trainingState.isHypertrophy ? 'Strength' : 'Hyper'}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildExerciseCard(_ExerciseEntry entry) {
    final latest = _latestWeights[entry.name];
    final lastHint = latest != null ? 'Last: ${latest.weight} kg' : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: switch (entry.state) {
          ExerciseEntryState.idle => _buildIdleCard(entry, lastHint),
          ExerciseEntryState.expanded => _buildExpandedCard(entry, lastHint),
          ExerciseEntryState.completed => _buildCompletedCard(entry),
        },
      ),
    );
  }

  Widget _buildIdleCard(_ExerciseEntry entry, String? lastHint) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              if (lastHint != null)
                Text(
                  lastHint,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
            ],
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: () => _onTrain(entry),
          icon: const Icon(Icons.fitness_center, size: 18),
          label: const Text('Train'),
        ),
      ],
    );
  }

  Widget _buildExpandedCard(_ExerciseEntry entry, String? lastHint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              entry.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            if (lastHint != null)
              Text(
                lastHint,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: entry.weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: entry.repsController,
                decoration: const InputDecoration(
                  labelText: 'Reps',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                controller: entry.setsController,
                decoration: const InputDecoration(
                  labelText: 'Sets',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => _onComplete(entry),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Complete'),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedCard(_ExerciseEntry entry) {
    final weight = entry.weightController.text.trim();
    final reps = entry.repsController.text.trim();
    final sets = entry.setsController.text.trim();
    final summaryParts = <String>[
      if (weight.isNotEmpty) '$weight kg',
      if (reps.isNotEmpty) '$reps reps',
      if (sets.isNotEmpty) '$sets sets',
    ];
    final summary = summaryParts.join(' × ');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    if (summary.isNotEmpty)
                      Text(
                        summary,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: () => _onEdit(entry),
          child: const Text('Edit'),
        ),
      ],
    );
  }
}

/// Helper class to manage exercise entry controllers and state.
class _ExerciseEntry {
  final String name;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController setsController;
  ExerciseEntryState state;

  _ExerciseEntry({
    required this.name,
    required String weight,
    required String reps,
    required String sets,
  })  : state = ExerciseEntryState.idle,
        weightController = TextEditingController(text: weight),
        repsController = TextEditingController(text: reps),
        setsController = TextEditingController(text: sets);

  void dispose() {
    weightController.dispose();
    repsController.dispose();
    setsController.dispose();
  }
}