import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/database/database_helper.dart';
import 'package:gym_tracker/models/body_stat.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

/// Profile screen for user data and settings
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<BodyStat> _bodyStats = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadBodyStats();
  }

  Future<void> _loadBodyStats() async {
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final bodyStats = await repository.getAllBodyStats();

      if (mounted) {
        setState(() {
          _bodyStats = bodyStats;
          _isLoading = false;
          _error = '';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load body stats: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _addBodyStat() async {
    final result = await showDialog<BodyStat>(
      context: context,
      builder: (dialogContext) => const _BodyStatDialog(),
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      await repository.insertBodyStat(result);
      await _loadBodyStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Body stats saved!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  Future<void> _editBodyStat(BodyStat stat) async {
    final result = await showDialog<BodyStat>(
      context: context,
      builder: (dialogContext) => _BodyStatDialog(existing: stat),
    );

    if (result == null) return;
    if (!mounted) return;

    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      await repository.updateBodyStat(result.copyWith(id: stat.id));
      await _loadBodyStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Body stats updated!')),
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

  Future<void> _deleteBodyStat(BodyStat stat) async {
    if (stat.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Body Stats'),
        content: Text(
            'Delete the entry from ${_formatDate(stat.date)}?'),
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
      await repository.deleteBodyStat(stat.id!);
      await _loadBodyStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Body stats deleted')),
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

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _exportDatabase() async {
    try {
      final dbHelper = DatabaseHelper();
      final dbPath = await dbHelper.getDatabasePath();
      if (dbPath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find database')),
          );
        }
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final exportPath = tempDir.path + '/gym_tracker_backup.db';
      await File(dbPath).copy(exportPath);
      await Share.shareXFiles(
        [XFile(exportPath)],
        subject: 'Gym Tracker Database Backup',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ' + e.toString())),
        );
      }
    }
  }

  /// Picks a .db/.sqlite/.sqlite3 file and imports it as the live app database.
  ///
  /// Flow: file picker → confirmation dialog → repository.importDatabase →
  /// SnackBar with the returned message → reload body stats on success. On any
  /// error the live DB is left untouched by the helper, so we just report.
  Future<void> _importDatabase() async {
    FilePickerResult? result;
    try {
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        allowMultiple: false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
      return;
    }

    // No file selected — user cancelled, do nothing.
    if (result == null || result.files.isEmpty) {
      return;
    }

    final filePath = result.files.single.path;
    if (filePath == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Import failed: no file selected.')),
        );
      }
      return;
    }
    final fileName = result.files.single.name;

    if (!mounted) return;

    // Confirmation dialog — replaces current data, but a backup is made.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import Database'),
        content: Text(
          'This will replace your current Gym Tracker data with the contents '
          'of "$fileName". A backup of your current database will be created. '
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Import'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Run the import via the repository.
    String message;
    try {
      final repository =
          Provider.of<GymRepository>(context, listen: false);
      message = await repository.importDatabase(filePath);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
      return;
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );

    // On success, reload this screen's data so it reflects the imported DB.
    // The other tabs reload automatically on next navigation (MainScreen
    // rebuilds each tab's State on tap).
    if (message == DatabaseHelper.importSuccessMessage) {
      await _loadBodyStats();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                          onPressed: _loadBodyStats,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User Profile Header
                      Card(
                        elevation: 3,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 40,
                                backgroundColor: Colors.blue,
                                child: Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Fitness Tracker',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_bodyStats.length} body stat records',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Body Stats Section header + Add button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Body Statistics',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _addBodyStat,
                            icon: const Icon(Icons.add),
                            label: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_bodyStats.isEmpty)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: Center(
                              child: Text(
                                'No body statistics recorded yet.\nTap "Add" to record your first measurement.',
                                style: TextStyle(color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        )
                      else
                        for (final stat in _bodyStats)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12.0),
                            child: ListTile(
                              title: Text(
                                _formatDate(stat.date),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  if (stat.weightKg != null)
                                    Text('Weight: ${stat.weightKg} kg'),
                                  if (stat.waistInches != null)
                                    Text('Waist: ${stat.waistInches} in'),
                                  if (stat.neckInches != null)
                                    Text('Neck: ${stat.neckInches} in'),
                                  if (stat.notes != null &&
                                      stat.notes!.isNotEmpty)
                                    Text('Notes: ${stat.notes}'),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'delete') {
                                    _deleteBodyStat(stat);
                                  } else if (value == 'modify') {
                                    _editBodyStat(stat);
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
                          ),

                      const SizedBox(height: 24),

                      // App Settings Section
                      const Text(
                        'Settings',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),

                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.notifications),
                              title: const Text('Notifications'),
                              trailing: Switch(
                                value: true,
                                onChanged: (value) {},
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.location_on),
                              title: const Text('GPS Tracking'),
                              trailing: Switch(
                                value: false,
                                onChanged: (value) {},
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.health_and_safety),
                              title: const Text('Health Connect'),
                              trailing: Switch(
                                value: false,
                                onChanged: (value) {},
                              ),
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: const Icon(Icons.backup),
                              title: const Text('Auto Backup'),
                              trailing: Switch(
                                value: true,
                                onChanged: (value) {},
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Actions Section
                      ElevatedButton(
                        onPressed: _loadBodyStats,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.refresh),
                            SizedBox(width: 8),
                            Text('Refresh Data'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _exportDatabase,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Export Database'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _importDatabase,
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.upload),
                            SizedBox(width: 8),
                            Text('Import Database'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBodyStat,
        tooltip: 'Add body stats',
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// Dialog for adding or editing a body stat entry
class _BodyStatDialog extends StatefulWidget {
  final BodyStat? existing;

  const _BodyStatDialog({this.existing});

  @override
  State<_BodyStatDialog> createState() => _BodyStatDialogState();
}

class _BodyStatDialogState extends State<_BodyStatDialog> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();
  final _waistController = TextEditingController();
  final _neckController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final s = widget.existing!;
      _selectedDate = s.date;
      _weightController.text =
          s.weightKg != null ? s.weightKg.toString() : '';
      _waistController.text =
          s.waistInches != null ? s.waistInches.toString() : '';
      _neckController.text =
          s.neckInches != null ? s.neckInches.toString() : '';
      _notesController.text = s.notes ?? '';
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _waistController.dispose();
    _neckController.dispose();
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
    final isEditing = widget.existing != null;
    return AlertDialog(
      title: Text(isEditing ? 'Edit Body Stats' : 'Add Body Stats'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              TextFormField(
                controller: _weightController,
                decoration: const InputDecoration(
                  labelText: 'Weight (kg)',
                  border: OutlineInputBorder(),
                  suffixText: 'kg',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final n = double.tryParse(value);
                  if (n == null || n <= 0) return 'Enter a valid weight';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _waistController,
                decoration: const InputDecoration(
                  labelText: 'Waist (inches)',
                  border: OutlineInputBorder(),
                  suffixText: 'in',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final n = double.tryParse(value);
                  if (n == null || n <= 0) return 'Enter a valid measurement';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _neckController,
                decoration: const InputDecoration(
                  labelText: 'Neck (inches)',
                  border: OutlineInputBorder(),
                  suffixText: 'in',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) return null;
                  final n = double.tryParse(value);
                  if (n == null || n <= 0) return 'Enter a valid measurement';
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              final bodyStat = BodyStat(
                date: _selectedDate,
                weightKg: double.tryParse(_weightController.text),
                waistInches: double.tryParse(_waistController.text),
                neckInches: double.tryParse(_neckController.text),
                notes: _notesController.text.isNotEmpty
                    ? _notesController.text
                    : null,
              );
              Navigator.of(context).pop(bodyStat);
            }
          },
          child: Text(isEditing ? 'Update' : 'Save'),
        ),
      ],
    );
  }
}