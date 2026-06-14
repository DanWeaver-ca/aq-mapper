import 'package:flutter/material.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';
import '../services/csv_export_service.dart';
import '../services/csv_import_service.dart';
import '../services/session_service.dart';

/// Export, import (merge other groups' CSVs), and data management.
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _databaseService = DatabaseService();
  final _csvExportService = CsvExportService();
  late final _csvImportService = CsvImportService(_databaseService);
  final _sessionService = SessionService();

  List<Measurement> _measurements = [];
  int _localCount = 0;
  int _importedCount = 0;
  bool _isLoading = true;
  bool _isExporting = false;
  bool _isImporting = false;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    final measurements = await _databaseService.getAllMeasurements();
    final counts = await _databaseService.countBySource();
    if (!mounted) return;
    setState(() {
      _measurements = measurements;
      _localCount = counts['local'] ?? 0;
      _importedCount = counts['imported'] ?? 0;
      _isLoading = false;
    });
  }

  void _showSnack(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> _exportAndShare() async {
    if (_measurements.isEmpty) return;

    // Anchor for the iOS share sheet — must be captured before async gaps.
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null
        ? null
        : box.localToGlobal(Offset.zero) & box.size;

    setState(() => _isExporting = true);
    try {
      final deviceId = await _sessionService.deviceId;
      await _csvExportService.exportAndShare(
        _measurements,
        deviceId: deviceId,
        shareOrigin: origin,
      );
    } catch (e) {
      if (mounted) _showSnack('Export failed: $e', color: Colors.red);
    }
    if (mounted) setState(() => _isExporting = false);
  }

  Future<void> _import() async {
    setState(() => _isImporting = true);
    try {
      final result = await _csvImportService.pickAndImport();
      if (result != null && mounted) {
        final fileNote =
            result.files > 1 ? ' from ${result.files} files' : '';
        final parts = <String>[
          'Imported ${result.imported}$fileNote',
          if (result.duplicates > 0)
            'skipped ${result.duplicates} duplicates',
          if (result.errors > 0) '${result.errors} bad rows',
        ];
        _showSnack(parts.join(', '),
            color: result.imported > 0 ? Colors.green : null);
        if (result.failures.isNotEmpty) {
          await _showFailures(result.failures);
        }
        await _loadMeasurements();
      }
    } on CsvImportException catch (e) {
      if (mounted) _showSnack(e.message, color: Colors.red);
    } catch (e) {
      if (mounted) _showSnack('Import failed: $e', color: Colors.red);
    }
    if (mounted) setState(() => _isImporting = false);
  }

  Future<void> _showFailures(List<String> failures) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${failures.length} file(s) skipped'),
        content: SingleChildScrollView(
          child: Text(failures.join('\n\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearImported() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Imported Data?'),
        content: Text(
          'This removes the $_importedCount measurements imported from '
          'other groups. Your own measurements are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear Imported'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deleteImported();
      await _loadMeasurements();
      if (mounted) _showSnack('Imported measurements removed.');
    }
  }

  Future<void> _confirmDeleteAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Data?'),
        content: const Text(
          'This will permanently delete all measurements. '
          'Make sure you have exported your data first.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _databaseService.deleteAllMeasurements();
      await _loadMeasurements();
      if (mounted) _showSnack('All measurements deleted.');
    }
  }

  /// A standing reminder that the device is the only copy of the readings —
  /// important on the web build, where browser storage can be cleared.
  Widget _exportReminder() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This device holds the only copy of your readings. Export your '
              'CSV before you finish — clearing the browser or app can erase '
              'them.',
              style: TextStyle(fontSize: 13, color: Colors.brown.shade800),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24.0),
              children: [
                Icon(
                  Icons.table_chart_outlined,
                  size: 56,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  '${_measurements.length} measurements',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _measurements.isEmpty
                      ? 'No data yet.'
                      : '$_localCount mine · $_importedCount imported',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                if (_localCount > 0) _exportReminder(),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _measurements.isEmpty || _isExporting
                        ? null
                        : _exportAndShare,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.share),
                    label: Text(
                      _isExporting ? 'Exporting...' : 'Export & Share CSV',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: _isImporting ? null : _import,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_download_outlined),
                    label: Text(
                      _isImporting
                          ? 'Importing...'
                          : 'Import CSVs from other groups',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Collect the groups\' CSVs (AirDrop, email, or a shared '
                  'folder), then pick one or many here to merge them onto your '
                  'map. Duplicates are skipped automatically.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 36),
                if (_importedCount > 0)
                  TextButton.icon(
                    onPressed: _confirmClearImported,
                    icon: const Icon(Icons.layers_clear_outlined),
                    label: Text('Clear imported data ($_importedCount)'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                if (_measurements.isNotEmpty)
                  TextButton.icon(
                    onPressed: _confirmDeleteAll,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete All Measurements'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
    );
  }
}
