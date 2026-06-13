import 'dart:convert';
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

/// Aggregate outcome of importing one or more files in a single pick.
class MultiImportResult {
  final int files;
  final int imported;
  final int duplicates;
  final int errors;

  /// "filename: reason" for any files that could not be parsed at all.
  final List<String> failures;

  const MultiImportResult({
    required this.files,
    required this.imported,
    required this.duplicates,
    required this.errors,
    required this.failures,
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

  /// Opens a file picker (multi-select), parses each chosen CSV, and merges
  /// rows into the database with source='imported'. Built for the classroom
  /// hub: pick all the groups' CSVs in one go. Returns null if cancelled.
  Future<MultiImportResult?> pickAndImport() async {
    // FileType.any rather than a custom-extension filter: extension filtering
    // is unreliable on iOS, and validity is checked by header content anyway.
    // withData: true loads bytes into memory so this also works on web, where
    // there is no file path.
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final named = <({String name, String content})>[];
    final failures = <String>[];
    for (final file in picked.files) {
      try {
        named.add((name: file.name, content: await _readFile(file)));
      } catch (e) {
        failures.add('${file.name}: $e');
      }
    }
    return importMany(named, priorFailures: failures);
  }

  /// Merges several CSV documents in one pass, accumulating counts and
  /// per-file failures. A bad file (e.g. a raw Temtop export with no
  /// coordinates) is skipped without aborting the rest — important when an
  /// instructor imports ~25 groups' files at once.
  Future<MultiImportResult> importMany(
    List<({String name, String content})> files, {
    List<String> priorFailures = const [],
  }) async {
    var imported = 0, duplicates = 0, errors = 0;
    final failures = <String>[...priorFailures];
    for (final file in files) {
      try {
        final r = await importCsvText(file.content);
        imported += r.imported;
        duplicates += r.duplicates;
        errors += r.errors;
      } on CsvImportException catch (e) {
        failures.add('${file.name}: ${e.message}');
      } catch (e) {
        failures.add('${file.name}: $e');
      }
    }
    return MultiImportResult(
      files: files.length,
      imported: imported,
      duplicates: duplicates,
      errors: errors,
      failures: failures,
    );
  }

  /// Reads a picked file as text from its in-memory bytes. The picker is
  /// called with withData:true, so bytes are populated on every platform
  /// (this keeps the importer free of dart:io so it compiles for web).
  Future<String> _readFile(PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes != null) return utf8.decode(bytes, allowMalformed: true);
    throw CsvImportException('Could not read ${file.name}.');
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
