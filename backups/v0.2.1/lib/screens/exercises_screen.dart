import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/models/body_part.dart';
import 'package:gym_tracker/models/exercise_body_part.dart';
import 'package:gym_tracker/models/weight_training.dart';
import 'package:gym_tracker/state/training_state.dart';
import 'package:gym_tracker/state/data_refresh_notifier.dart';

/// Screen for browsing exercises, viewing weights, and adding new exercises
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  List<BodyPart> _bodyParts = [];
  Map<String, List<ExerciseBodyPart>> _exercisesByBodyPart = {};
  Map<String, WeightTraining?> _latestWeights = {};
  bool _isLoading = true;
  String _error = '';
  int _lastRefreshCount = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final bodyParts = await repository.getAllBodyParts();
      final allExercises = await repository.getAllExerciseBodyParts();

      final exercisesByBodyPart = <String, List<ExerciseBodyPart>>{};
      final latestWeights = <String, WeightTraining?>{};

      for (final bp in bodyParts) {
        exercisesByBodyPart[bp.name] = allExercises
            .where((e) => e.bodyPart == bp.name)
            .toList();
      }

      final trainingState = Provider.of<TrainingState>(context, listen: false);
      final exerciseNames = allExercises.map((e) => e.exercise).toSet();
      for (final name in exerciseNames) {
        latestWeights[name] = await repository.getLatestWeightForExercise(name, trainingState.currentModeName);
      }

      if (mounted) {
        setState(() {
          _bodyParts = bodyParts;
          _exercisesByBodyPart = exercisesByBodyPart;
          _latestWeights = latestWeights;
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load exercises: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _addExercise() async {
    final result = await showDialog<_NewExerciseData>(
      context: context,
      builder: (dialogContext) => _AddExerciseDialog(
        bodyParts: _bodyParts.map((bp) => bp.name).toList(),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);

      await repository.addExercise(result.name, result.bodyParts);

      if (result.weight.isNotEmpty) {
        final wt = WeightTraining(
          date: DateTime.now(),
          trainingStyle: result.trainingStyle,
          exercises: result.name,
          weight: result.weight,
          reps: result.reps,
          sets: result.sets,
        );
        await repository.insertWeightTraining(wt);
      }

      if (!mounted) return;
      context.read<DataRefreshNotifier>().notifyDataChanged();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exercise "${result.name}" added!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add exercise: $e')),
        );
      }
    }
  }

  Future<void> _modifyWeight(String exerciseName) async {
    final current = _latestWeights[exerciseName];
    final result = await showDialog<_ModifyWeightResult>(
      context: context,
      builder: (dialogContext) => _ModifyWeightDialog(
        exerciseName: exerciseName,
        currentWeight: current?.weight ?? '',
        currentReps: current?.reps.toString() ?? '',
        currentSets: current?.sets.toString() ?? '',
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);

      if (current != null && current.id != null) {
        // Update the existing entry with all fields.
        await repository.updateWeightTraining(current.copyWith(
          weight: result.weight,
          reps: int.tryParse(result.reps) ?? 0,
          sets: int.tryParse(result.sets) ?? 0,
          date: DateTime.now(),
        ));
      } else {
        // No existing entry — insert a new one.
        final trainingState = Provider.of<TrainingState>(context, listen: false);
        final wt = WeightTraining(
          date: DateTime.now(),
          trainingStyle: trainingState.currentModeName,
          exercises: exerciseName,
          weight: result.weight,
          reps: int.tryParse(result.reps) ?? 0,
          sets: int.tryParse(result.sets) ?? 0,
        );
        await repository.insertWeightTraining(wt);
      }

      if (!mounted) return;
      context.read<DataRefreshNotifier>().notifyDataChanged();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated $exerciseName: ${result.weight} kg, ${result.reps} reps, ${result.sets} sets')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _showWeightHistory(String exerciseName) async {
    final repository = Provider.of<GymRepository>(context, listen: false);
    final records = await repository.getWeightTrainingByExercise(exerciseName);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$exerciseName — Weight History'),
        content: SizedBox(
          width: double.maxFinite,
          child: records.isEmpty
              ? const Text('No weight history yet.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final r = records[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        '${_formatDate(r.date)} — ${r.weight} kg',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${r.trainingStyle} | ${r.reps} reps x ${r.sets} sets',
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Watch the DataRefreshNotifier — when notifyDataChanged() fires anywhere
    // in the app, this widget rebuilds. We compare refreshCount to our last
    // seen value and trigger a data reload in a post-frame callback.
    final notifier = Provider.of<DataRefreshNotifier>(context);
    if (notifier.refreshCount != _lastRefreshCount) {
      _lastRefreshCount = notifier.refreshCount;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadData();
      });
    }

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(onPressed: _loadData, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _bodyParts.isEmpty
                  ? const Center(child: Text('No body parts found', style: TextStyle(color: Colors.grey)))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8.0),
                        itemCount: _bodyParts.length,
                        itemBuilder: (context, index) {
                          final bp = _bodyParts[index];
                          final exercises = _exercisesByBodyPart[bp.name] ?? [];
                          if (exercises.isEmpty) return const SizedBox.shrink();
                          return ExpansionTile(
                            title: Text(bp.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            subtitle: Text('${exercises.length} exercises'),
                            children: exercises.map((ex) {
                              final latest = _latestWeights[ex.exercise];
                              return Card(
                                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
                                elevation: 1,
                                child: ListTile(
                                  dense: true,
                                  title: Text(ex.exercise),
                                  subtitle: Text(
                                    latest != null
                                        ? '${latest.weight} kg | ${latest.trainingStyle} | ${latest.reps}x${latest.sets}'
                                        : 'No weight recorded yet',
                                    style: TextStyle(color: latest != null ? null : Colors.grey),
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'modify') {
                                        _modifyWeight(ex.exercise);
                                      } else if (value == 'history') {
                                        _showWeightHistory(ex.exercise);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(value: 'modify', child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Modify Weight')])),
                                      const PopupMenuItem(value: 'history', child: Row(children: [Icon(Icons.history, size: 20), SizedBox(width: 8), Text('Weight History')])),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExercise,
        tooltip: 'Add exercise',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _NewExerciseData {
  final String name;
  final List<String> bodyParts;
  final String trainingStyle;
  final String weight;
  final int reps;
  final int sets;

  _NewExerciseData({
    required this.name,
    required this.bodyParts,
    required this.trainingStyle,
    required this.weight,
    required this.reps,
    required this.sets,
  });
}

class _AddExerciseDialog extends StatefulWidget {
  final List<String> bodyParts;

  const _AddExerciseDialog({required this.bodyParts});

  @override
  State<_AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<_AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _setsController = TextEditingController();
  String _trainingStyle = 'Hypertrophy';
  final Set<String> _selectedBodyParts = {};

  @override
  void dispose() {
    _nameController.dispose();
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Exercise'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Exercise Name', border: OutlineInputBorder()),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Enter an exercise name';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _trainingStyle,
                decoration: const InputDecoration(labelText: 'Training Style', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'Hypertrophy', child: Text('Hypertrophy')),
                  DropdownMenuItem(value: 'Strength', child: Text('Strength')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _trainingStyle = value);
                },
              ),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerLeft, child: Text('Body Parts (select at least one):')),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: widget.bodyParts.map((bp) {
                  final selected = _selectedBodyParts.contains(bp);
                  return FilterChip(
                    label: Text(bp),
                    selected: selected,
                    onSelected: (value) {
                      setState(() {
                        if (value) { _selectedBodyParts.add(bp); } else { _selectedBodyParts.remove(bp); }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(labelText: 'Initial Weight (optional)', border: OutlineInputBorder(), suffixText: 'kg'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: TextFormField(controller: _repsController, decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: TextFormField(controller: _setsController, decoration: const InputDecoration(labelText: 'Sets', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              if (_selectedBodyParts.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select at least one body part')));
                return;
              }
              final data = _NewExerciseData(
                name: _nameController.text.trim(),
                bodyParts: _selectedBodyParts.toList(),
                trainingStyle: _trainingStyle,
                weight: _weightController.text.trim(),
                reps: int.tryParse(_repsController.text) ?? 0,
                sets: int.tryParse(_setsController.text) ?? 0,
              );
              Navigator.of(context).pop(data);
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

/// Result from the Modify Weight dialog — includes weight, reps, and sets.
class _ModifyWeightResult {
  final String weight;
  final String reps;
  final String sets;

  _ModifyWeightResult({required this.weight, required this.reps, required this.sets});
}

class _ModifyWeightDialog extends StatefulWidget {
  final String exerciseName;
  final String currentWeight;
  final String currentReps;
  final String currentSets;

  const _ModifyWeightDialog({
    required this.exerciseName,
    required this.currentWeight,
    required this.currentReps,
    required this.currentSets,
  });

  @override
  State<_ModifyWeightDialog> createState() => _ModifyWeightDialogState();
}

class _ModifyWeightDialogState extends State<_ModifyWeightDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;
  late final TextEditingController _setsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: widget.currentWeight);
    _repsController = TextEditingController(text: widget.currentReps);
    _setsController = TextEditingController(text: widget.currentSets);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    _setsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Modify — ${widget.exerciseName}'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _weightController,
              decoration: const InputDecoration(labelText: 'Weight', border: OutlineInputBorder(), suffixText: 'kg'),
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) return 'Enter a weight';
                return null;
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _repsController,
                    decoration: const InputDecoration(labelText: 'Reps', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _setsController,
                    decoration: const InputDecoration(labelText: 'Sets', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_ModifyWeightResult(
                weight: _weightController.text.trim(),
                reps: _repsController.text.trim(),
                sets: _setsController.text.trim(),
              ));
            }
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
