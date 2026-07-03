import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gym_tracker/repositories/gym_repository.dart';
import 'package:gym_tracker/models/session.dart';

/// Screen for viewing workout history
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Session> _sessions = [];
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final repository = Provider.of<GymRepository>(context, listen: false);
      final sessions = await repository.getAllSessions();
      
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error.isNotEmpty
              ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
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
                                if (session.bodyPart != null)
                                  Text('Body Part: ${session.bodyPart}'),
                                if (session.trainingStyle != null)
                                  Text('Style: ${session.trainingStyle}'),
                                if (session.runDuration != null)
                                  Text('Run: ${session.runDuration} km'),
                                if (session.runTime != null)
                                  Text('Run Time: ${session.runTime} min'),
                                if (session.saunaDuration != null)
                                  Text('Sauna: ${session.saunaDuration} min'),
                                if (session.bodyWeight != null)
                                  Text('Body Weight: ${session.bodyWeight} kg'),
                                if (session.other != null &&
                                    session.other!.isNotEmpty)
                                  Text('Notes: ${session.other}'),
                              ],
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              // TODO: Navigate to session detail
                            },
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