import 'dart:io';
import 'dart:ui';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/measurement.dart';

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

  Future<String> exportToCsv(
    List<Measurement> measurements, {
    String? deviceId,
  }) async {
    final csvData = buildCsv(measurements);
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    // Device-prefixed filename so the instructor can tell groups' files apart.
    final prefix = (deviceId == null || deviceId.isEmpty) ? 'aq' : 'aq_$deviceId';
    final filePath = '${directory.path}/${prefix}_$dateStr.csv';
    final file = File(filePath);
    await file.writeAsString(csvData);
    return filePath;
  }

  /// [sharePositionOrigin] anchors the iOS share sheet; newer iOS versions
  /// throw a PlatformException when it is missing.
  Future<void> shareCsv(String filePath, {Rect? sharePositionOrigin}) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Air Quality Measurements',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
