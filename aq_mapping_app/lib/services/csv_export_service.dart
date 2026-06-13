import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import '../models/measurement.dart';
import 'csv_export_platform.dart'
    if (dart.library.io) 'csv_export_platform_io.dart'
    if (dart.library.js_interop) 'csv_export_platform_web.dart';

class CsvExportService {
  /// Builds the CSV text (header + rows). Pure, so tests can use it without
  /// touching the filesystem.
  String buildCsv(List<Measurement> measurements) {
    final rows = <List<String>>[
      Measurement.csvHeaders,
      ...measurements.map((m) => m.toCsvRow()),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  /// Exports the measurements and hands the file to the user: the native
  /// share sheet on mobile, a browser download on web. [shareOrigin] anchors
  /// the iOS share popover (required on newer iOS).
  Future<void> exportAndShare(
    List<Measurement> measurements, {
    String? deviceId,
    Rect? shareOrigin,
  }) async {
    final csv = buildCsv(measurements);
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    // Device-prefixed filename so the instructor can tell groups' files apart.
    final prefix =
        (deviceId == null || deviceId.isEmpty) ? 'aq' : 'aq_$deviceId';
    await deliverCsv(csv, '${prefix}_$dateStr.csv', shareOrigin: shareOrigin);
  }
}
