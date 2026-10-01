import 'package:flutter/material.dart';

/// Result data from the Add Exercise dialog.
class NewExerciseData {
  final String name;
  final List<String> bodyParts;
  final String trainingStyle;
  final String weight;
  final int reps;
  final int sets;

  NewExerciseData({
    required this.name,
    required this.bodyParts,
    required this.trainingStyle,
    required this.weight,
    required this.reps,
    required this.sets,
  });
}

/// Shared Add Exercise dialog.
///
/// Used by the Exercises tab (plain — no initial selection) and by the
/// Workout tab, which passes the session's selected body parts and the
/// active training style so a missing exercise can be created mid-session
/// without leaving the page.
class AddExerciseDialog extends StatefulWidget {
  final List<String> bodyParts;
  final Set<String> initialSelectedBodyParts;
  final String initialTrainingStyle;

  const AddExerciseDialog({
    super.key,
    required this.bodyParts,
    this.initialSelectedBodyParts = const <String>{},
    this.initialTrainingStyle = 'Hypertrophy',
  });

  @override
  State<AddExerciseDialog> createState() => _AddExerciseDialogState();
}

class _AddExerciseDialogState extends State<AddExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _setsController = TextEditingController();
  late String _trainingStyle;
  final Set<String> _selectedBodyParts = {};

  @override
  void initState() {
    super.initState();
    _trainingStyle = widget.initialTrainingStyle;
    _selectedBodyParts.addAll(widget.initialSelectedBodyParts);
  }

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
              final data = NewExerciseData(
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