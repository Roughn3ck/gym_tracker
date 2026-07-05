import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/models/session.dart';
import 'package:gym_tracker/models/body_part.dart';
import 'package:gym_tracker/state/data_refresh_notifier.dart';

/// Screen for viewing workout history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Session> _sessions = [];
  List<BodyPart> _allBodyParts = [];
  bool _isLoading = true;
  String _error = '';
  int _lastRefreshCount = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _loadBodyParts();
  }

  Future<void> _loadBodyParts() async {
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final bodyParts = await repository.getAllBodyParts();
      if (mounted) {
        setState(() {
          _allBodyParts = bodyParts;
        });
      }
    } catch (_) {
      // Body parts load failure is non-critical for history display
    }
  }

  Future<void> _loadHistory() async {
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final sessions = await repository.getAllSessions();

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load history: $e';
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parses a session's `bodyParts` JSON array string into a comma-joined list.
  String? _parseBodyParts(String? bodyPartsJson) {
    if (bodyPartsJson == null) return null;
    try {
      final decoded = jsonDecode(bodyPartsJson);
      if (decoded is! List) return bodyPartsJson;
      if (decoded.isEmpty) return null;
      return decoded.map((e) => e.toString()).join(', ');
    } catch (_) {
      return bodyPartsJson;
    }
  }

  Future<void> _modifySession(Session session) async {
    final result = await showDialog<Session>(
      context: context,
      builder: (dialogContext) => _EditSessionDialog(
        existing: session,
        bodyParts: _allBodyParts.map((bp) => bp.name).toList(),
      ),
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      await repository.updateSession(result.copyWith(id: session.id));
      if (!mounted) return;
      context.read<DataRefreshNotifier>().notifyDataChanged();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update session: $e')),
        );
      }
    }
  }

  Future<void> _deleteSession(Session session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session'),
        content: Text(
            'Delete session ${session.id} from ${_formatDate(session.date)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      await repository.deleteSession(session.id!);
      if (!mounted) return;
      context.read<DataRefreshNotifier>().notifyDataChanged();
      await _loadHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Session deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
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
        _loadHistory();
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
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.red),
                        const SizedBox(height: 12),
                        Text(_error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _loadHistory,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(
                      child: Text(
                        'No workout history yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _sessions.length,
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12.0),
                          elevation: 2,
                          child: ListTile(
                            title: Text(
                              'Session ${session.id}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text('Date: ${_formatDate(session.date)}'),
                                if (session.workout != null)
                                  Text('Workout: ${session.workout}'),
                                Builder(builder: (_) {
                                  final parsed =
                                      _parseBodyParts(session.bodyParts);
                                  if (parsed == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text('Body Parts: $parsed');
                                }),
                                if (session.trainingStyle != null)
                                  Text('Style: ${session.trainingStyle}'),
                                if (session.runDuration != null)
                                  Text('Run: ${session.runDuration} km'),
                                if (session.runTime != null)
                                  Text('Run Time: ${session.runTime} min'),
                                if (session.saunaDuration != null)
                                  Text('Sauna: ${session.saunaDuration} min'),
                                if (session.bodyWeight != null)
                                  Text(
                                      'Body Weight: ${session.bodyWeight} kg'),
                                if (session.other != null &&
                                    session.other!.isNotEmpty)
                                  Text('Notes: ${session.other}'),
                              ],
                            ),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'modify') {
                                  _modifySession(session);
                                } else if (value == 'delete') {
                                  _deleteSession(session);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'modify',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Modify'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete',
                                          style:
                                              TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _loadHistory,
        tooltip: 'Refresh history',
        child: const Icon(Icons.refresh),
      ),
    );
  }
}

/// Dialog for editing an existing session
class _EditSessionDialog extends StatefulWidget {
  final Session existing;
  final List<String> bodyParts;

  const _EditSessionDialog({
    required this.existing,
    required this.bodyParts,
  });

  @override
  State<_EditSessionDialog> createState() => _EditSessionDialogState();
}

class _EditSessionDialogState extends State<_EditSessionDialog> {
  final _workoutController = TextEditingController();
  final _bodyWeightController = TextEditingController();
  final _runDistanceController = TextEditingController();
  final _runTimeController = TextEditingController();
  final _saunaController = TextEditingController();
  final _notesController = TextEditingController();
  late DateTime _selectedDate;
  late String _trainingStyle;
  late Set<String> _selectedBodyParts;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _selectedDate = s.date;
    _trainingStyle = s.trainingStyle ?? 'Hypertrophy';
    _workoutController.text = s.workout ?? '';
    _bodyWeightController.text = s.bodyWeight?.toString() ?? '';
    _runDistanceController.text = s.runDuration?.toString() ?? '';
    _runTimeController.text = s.runTime?.toString() ?? '';
    _saunaController.text = s.saunaDuration?.toString() ?? '';
    _notesController.text = s.other ?? '';
    // Parse body parts from JSON
    _selectedBodyParts = {};
    if (s.bodyParts != null) {
      try {
        final decoded = jsonDecode(s.bodyParts!);
        if (decoded is List) {
          _selectedBodyParts = decoded.map((e) => e.toString()).toSet();
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _workoutController.dispose();
    _bodyWeightController.dispose();
    _runDistanceController.dispose();
    _runTimeController.dispose();
    _saunaController.dispose();
    _notesController.dispose();
    super.dispose();
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
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Modify Session'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            TextFormField(
              controller: _workoutController,
              decoration: const InputDecoration(
                labelText: 'Workout',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _trainingStyle,
              decoration: const InputDecoration(
                labelText: 'Training Style',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                    value: 'Hypertrophy', child: Text('Hypertrophy')),
                DropdownMenuItem(value: 'Strength', child: Text('Strength')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _trainingStyle = value);
              },
            ),
            const SizedBox(height: 12),
            const Align(
                alignment: Alignment.centerLeft, child: Text('Body Parts:')),
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
                      if (value) {
                        _selectedBodyParts.add(bp);
                      } else {
                        _selectedBodyParts.remove(bp);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final session = Session(
              id: widget.existing.id,
              date: _selectedDate,
              workout: _workoutController.text.trim().isEmpty
                  ? null
                  : _workoutController.text.trim(),
              bodyParts: jsonEncode(_selectedBodyParts.toList()),
              runDuration: double.tryParse(_runDistanceController.text),
              runTime: int.tryParse(_runTimeController.text),
              saunaDuration: int.tryParse(_saunaController.text),
              bodyWeight: double.tryParse(_bodyWeightController.text),
              trainingStyle: _trainingStyle,
              other: _notesController.text.trim().isNotEmpty
                  ? _notesController.text.trim()
                  : null,
            );
            Navigator.of(context).pop(session);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}