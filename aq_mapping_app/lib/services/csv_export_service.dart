import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/measurement.dart';
import 'csv_export_platform.dart'
    if (dart.library.io) 'csv_export_platform_io.dart'
    if (dart.library.js_interop) 'csv_export_platform_web.dart';

export 'csv_export_platform.dart' show SendOutcome;

class CsvExportService {
  /// Whether "save a copy" exists as its own button on this platform (web).
  /// On mobile the share sheet's built-in save target covers it.
  bool get hasSeparateSave => kHasSeparateSave;

  /// Builds the CSV text (header + rows). Pure, so tests can use it without
  /// touching the filesystem.
  String buildCsv(List<Measurement> measurements) {
    final rows = <List<String>>[
      Measurement.csvHeaders,
      ...measurements.map((m) => m.toCsvRow()),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Opens the platform share flow so the student can send the CSV to the
  /// instructor (AirDrop, Mail…). Returns what actually happened; browsers
  /// without file sharing save the CSV instead ([SendOutcome.savedInstead]).
  /// [shareOrigin] anchors the iOS share popover (required on newer iOS).
  Future<SendOutcome> send(
    List<Measurement> measurements, {
    String? deviceId,
    Rect? shareOrigin,
  }) =>
      sendCsv(buildCsv(measurements), _filename(deviceId),
          shareOrigin: shareOrigin);

  /// Saves the CSV locally without sharing (on web: a browser download).
  Future<void> save(List<Measurement> measurements, {String? deviceId}) =>
      saveCsv(buildCsv(measurements), _filename(deviceId));

  /// Device-prefixed filename so the instructor can tell groups' files apart.
  String _filename(String? deviceId) {
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final prefix =
        (deviceId == null || deviceId.isEmpty) ? 'aq' : 'aq_$deviceId';
    return '${prefix}_$dateStr.csv';
  }
}
