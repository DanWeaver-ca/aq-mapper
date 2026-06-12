import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/map_variable.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';
import 'entry_screen.dart';

/// All recorded measurements, newest first. Tap to edit, swipe to delete.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _databaseService = DatabaseService();
  List<Measurement> _measurements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    final measurements = await _databaseService.getAllMeasurements();
    if (!mounted) return;
    setState(() {
      _measurements = measurements;
      _isLoading = false;
    });
  }

  Future<bool> _confirmDelete(Measurement m) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete measurement?'),
        content: Text(
            'Recorded ${DateFormat('yyyy-MM-dd HH:mm').format(m.timestamp)}. '
            'This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _edit(Measurement m) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryScreen(existing: m)),
    );
    if (changed == true) await _loadMeasurements();
  }

  String _summaryLine(Measurement m) {
    final parts = <String>[
      if (m.pm25 != null) 'PM2.5 ${m.pm25}',
      if (m.co2 != null) 'CO₂ ${m.co2!.toStringAsFixed(0)}',
      if (m.hcho != null) 'HCHO ${m.hcho}',
      if (m.temperature != null)
        '${m.temperature!.toStringAsFixed(1)}°${m.tempUnit}',
    ];
    return parts.isEmpty ? 'No sensor values' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('History (${_measurements.length})'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _measurements.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'No measurements yet.\nAdd one from the home screen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _measurements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final m = _measurements[index];
                    return Dismissible(
                      key: ValueKey(m.uid),
                      direction: DismissDirection.endToStart,
                      confirmDismiss: (_) => _confirmDelete(m),
                      onDismissed: (_) async {
                        await _databaseService.deleteMeasurement(m.id!);
                        setState(() => _measurements.removeAt(index));
                      },
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child:
                            const Icon(Icons.delete, color: Colors.white),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 10,
                          backgroundColor:
                              MapVariable.pm25.colorFor(m.pm25),
                        ),
                        title: Text(
                          _summaryLine(m),
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Row(
                          children: [
                            Text(DateFormat('MM-dd HH:mm')
                                .format(m.timestamp)),
                            const SizedBox(width: 6),
                            if (m.isIndoor != null)
                              Icon(
                                m.isIndoor!
                                    ? Icons.meeting_room_outlined
                                    : Icons.park_outlined,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                            if (m.groupName != null) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  m.groupName!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                        trailing: m.source == 'imported'
                            ? Chip(
                                label: const Text('imported'),
                                visualDensity: VisualDensity.compact,
                                labelStyle: const TextStyle(fontSize: 10),
                                backgroundColor: Colors.grey[200],
                              )
                            : const Icon(Icons.chevron_right),
                        onTap: () => _edit(m),
                      ),
                    );
                  },
                ),
    );
  }
}
