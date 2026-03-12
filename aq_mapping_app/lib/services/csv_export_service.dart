import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../models/measurement.dart';

class CsvExportService {
  Future<String> exportToCsv(List<Measurement> measurements) async {
    final rows = <List<String>>[
      Measurement.csvHeaders,
      ...measurements.map((m) => m.toCsvRow()),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final directory = await getApplicationDocumentsDirectory();
    final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filePath = '${directory.path}/aq_data_$dateStr.csv';
    final file = File(filePath);
    await file.writeAsString(csvData);
    return filePath;
  }

  Future<void> shareCsv(String filePath) async {
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'Air Quality Measurements',
    );
  }
}
