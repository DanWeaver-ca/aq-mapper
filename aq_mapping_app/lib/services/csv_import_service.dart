import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';

class ImportResult {
  final int imported;
  final int duplicates;
  final int errors;
  const ImportResult({
    required this.imported,
    required this.duplicates,
    required this.errors,
  });
}

class CsvImportException implements Exception {
  final String message;
  CsvImportException(this.message);
  @override
  String toString() => message;
}

class CsvImportService {
  final DatabaseService _databaseService;

  CsvImportService(this._databaseService);

  /// Opens a file picker, parses the chosen CSV, and merges rows into the
  /// database with source='imported'. Returns null if the user cancelled.
  Future<ImportResult?> pickAndImport() async {
    // FileType.any rather than a custom-extension filter: extension filtering
    // is unreliable on iOS, and validity is checked by header content anyway.
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null) return null;
    final content = await File(path).readAsString();
    return importCsvText(content);
  }

  /// Parses CSV text and merges rows. Throws [CsvImportException] when the
  /// file is not an AQ Mapper export (e.g., a raw Temtop device file, which
  /// has no coordinates).
  Future<ImportResult> importCsvText(String content) async {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content.replaceAll('\r\n', '\n'));
    if (rows.isEmpty) {
      throw CsvImportException('The file is empty.');
    }

    final headers =
        rows.first.map((cell) => cell.toString().trim()).toList();
    const required = ['DATE', 'LATITUDE', 'LONGITUDE'];
    final missing =
        required.where((h) => !headers.contains(h)).toList();
    if (missing.isNotEmpty) {
      throw CsvImportException(
          'Not an AQ Mapper export (missing ${missing.join(', ')}). '
          'Raw Temtop device files cannot be imported — they have no GPS '
          'coordinates.');
    }

    final measurements = <Measurement>[];
    var errors = 0;
    for (final row in rows.skip(1)) {
      if (row.every((cell) => cell.toString().trim().isEmpty)) continue;
      final byHeader = <String, String>{
        for (var i = 0; i < headers.length && i < row.length; i++)
          headers[i]: row[i].toString(),
      };
      try {
        measurements
            .add(Measurement.fromCsvRow(byHeader).copyWith(source: 'imported'));
      } on FormatException {
        errors++;
      }
    }

    final counts = await _databaseService.insertIfNew(measurements);
    return ImportResult(
      imported: counts.inserted,
      duplicates: counts.skipped,
      errors: errors,
    );
  }
}
