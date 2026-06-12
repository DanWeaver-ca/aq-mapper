import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aq_mapping_app/models/measurement.dart';
import 'package:aq_mapping_app/services/csv_export_service.dart';

import 'measurement_test.dart' show fullMeasurement;

Map<String, String> rowByHeader(List<String> headers, List<dynamic> row) => {
      for (var i = 0; i < headers.length && i < row.length; i++)
        headers[i]: row[i].toString(),
    };

void main() {
  test('header order matches the Temtop-first contract exactly', () {
    expect(Measurement.csvHeaders, [
      'DATE',
      'PM2.5(ug/m3)',
      'PM10(ug/m3)',
      'PARTICLES(per/L)',
      'CO2(ppm)',
      'HCHO(mg/m3)',
      'TEMPERATURE',
      'HUMIDITY(%)',
      'TEMPUNIT',
      'LATITUDE',
      'LONGITUDE',
      'GROUP',
      'DEVICE',
      'LOCATION_TYPE',
      'PM2.5_VAR(ug/m3)',
      'PM10_VAR(ug/m3)',
      'CO2_VAR(ppm)',
      'HCHO_VAR(mg/m3)',
      'TEMPERATURE_VAR',
      'HUMIDITY_VAR(%)',
      'UID',
      'NOTES',
    ]);
  });

  test('export → parse → fromCsvRow restores every field', () {
    final original = fullMeasurement();
    final csvText = CsvExportService().buildCsv([original]);
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(csvText.replaceAll('\r\n', '\n'), eol: '\n');
    final headers = rows.first.map((c) => c.toString()).toList();
    final restored = Measurement.fromCsvRow(rowByHeader(headers, rows[1]));

    expect(restored.uid, original.uid);
    expect(restored.timestamp, original.timestamp); // second precision in test data
    expect(restored.latitude, closeTo(original.latitude, 1e-6));
    expect(restored.longitude, closeTo(original.longitude, 1e-6));
    expect(restored.pm25, original.pm25);
    expect(restored.pm25Var, original.pm25Var);
    expect(restored.pm10, original.pm10);
    expect(restored.particles, original.particles);
    expect(restored.co2, original.co2);
    expect(restored.co2Var, original.co2Var);
    expect(restored.hcho, original.hcho);
    expect(restored.hchoVar, original.hchoVar);
    expect(restored.temperature, original.temperature);
    expect(restored.tempUnit, original.tempUnit);
    expect(restored.humidity, original.humidity);
    expect(restored.humidityVar, original.humidityVar);
    expect(restored.groupName, original.groupName);
    expect(restored.deviceId, original.deviceId);
    expect(restored.isIndoor, original.isIndoor);
    expect(restored.notes, original.notes);
  });

  test('nulls export as empty strings and import back as nulls', () {
    final original = Measurement(
      uid: 'NA-1-0000',
      timestamp: DateTime(2026, 6, 12, 9, 0, 0),
      latitude: 43.78,
      longitude: -79.18,
    );
    final csvText = CsvExportService().buildCsv([original]);
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(csvText.replaceAll('\r\n', '\n'), eol: '\n');
    final headers = rows.first.map((c) => c.toString()).toList();
    final restored = Measurement.fromCsvRow(rowByHeader(headers, rows[1]));
    expect(restored.pm25, isNull);
    expect(restored.particles, isNull);
    expect(restored.groupName, isNull);
    expect(restored.isIndoor, isNull);
    expect(restored.notes, isNull);
  });

  test('notes with commas and quotes survive the round trip', () {
    final original = fullMeasurement()
        .copyWith(notes: 'windy, near "AA building", 2nd floor');
    final csvText = CsvExportService().buildCsv([original]);
    final rows = const CsvToListConverter(shouldParseNumbers: false)
        .convert(csvText.replaceAll('\r\n', '\n'), eol: '\n');
    final headers = rows.first.map((c) => c.toString()).toList();
    final restored = Measurement.fromCsvRow(rowByHeader(headers, rows[1]));
    expect(restored.notes, original.notes);
  });

  test('legacy export without UID gets a deterministic fallback key', () {
    final row = {
      'DATE': '2026-06-12 10:00:00',
      'LATITUDE': '43.784100',
      'LONGITUDE': '-79.187300',
      'DEVICE': 'UTSC-AQMS-05',
      'PM2.5(ug/m3)': '12.5',
    };
    final a = Measurement.fromCsvRow(Map.of(row));
    final b = Measurement.fromCsvRow(Map.of(row));
    expect(a.uid, b.uid);
    expect(a.uid, contains('UTSC-AQMS-05'));
  });

  test('row missing coordinates throws FormatException', () {
    expect(
      () => Measurement.fromCsvRow({'DATE': '2026-06-12 10:00:00'}),
      throwsFormatException,
    );
  });
}
