import 'package:flutter_test/flutter_test.dart';
import 'package:aq_mapping_app/models/measurement.dart';

Measurement fullMeasurement() => Measurement(
      id: 7,
      uid: 'UTSC-AQMS-03-1750000000000-a1b2',
      timestamp: DateTime(2026, 6, 12, 14, 3, 21),
      latitude: 43.784123,
      longitude: -79.187456,
      pm25: 14.7,
      pm25Var: 1.2,
      pm10: 24.8,
      pm10Var: 2.0,
      particles: 2311,
      co2: 425,
      co2Var: 15,
      hcho: 0.051,
      hchoVar: 0.01,
      temperature: 20.7,
      temperatureVar: 0.5,
      tempUnit: 'C',
      humidity: 75.3,
      humidityVar: 3,
      groupName: 'Maple Group',
      deviceId: 'UTSC-AQMS-03',
      isIndoor: true,
      source: 'local',
      notes: 'near food court, busy',
    );

void main() {
  group('Measurement map round-trip', () {
    test('all fields survive toMap/fromMap', () {
      final original = fullMeasurement();
      final restored = Measurement.fromMap(original.toMap());
      expect(restored.uid, original.uid);
      expect(restored.timestamp, original.timestamp);
      expect(restored.latitude, original.latitude);
      expect(restored.longitude, original.longitude);
      expect(restored.pm25, original.pm25);
      expect(restored.pm25Var, original.pm25Var);
      expect(restored.pm10, original.pm10);
      expect(restored.pm10Var, original.pm10Var);
      expect(restored.particles, original.particles);
      expect(restored.co2, original.co2);
      expect(restored.co2Var, original.co2Var);
      expect(restored.hcho, original.hcho);
      expect(restored.hchoVar, original.hchoVar);
      expect(restored.temperature, original.temperature);
      expect(restored.temperatureVar, original.temperatureVar);
      expect(restored.tempUnit, original.tempUnit);
      expect(restored.humidity, original.humidity);
      expect(restored.humidityVar, original.humidityVar);
      expect(restored.groupName, original.groupName);
      expect(restored.deviceId, original.deviceId);
      expect(restored.isIndoor, original.isIndoor);
      expect(restored.source, original.source);
      expect(restored.notes, original.notes);
    });

    test('all-null sensors survive round-trip', () {
      final original = Measurement(
        uid: 'NA-1-ffff',
        timestamp: DateTime(2026, 1, 1),
        latitude: 43.78,
        longitude: -79.18,
      );
      final restored = Measurement.fromMap(original.toMap());
      expect(restored.pm25, isNull);
      expect(restored.particles, isNull);
      expect(restored.isIndoor, isNull);
      expect(restored.tempUnit, 'C');
      expect(restored.source, 'local');
    });
  });

  group('uid generation', () {
    test('contains device id and is unique across calls', () {
      final ts = DateTime(2026, 6, 12, 10, 0, 0);
      final uids = {
        for (var i = 0; i < 200; i++) Measurement.generateUid('UTSC-AQMS-09', ts)
      };
      expect(uids.length, 200);
      expect(uids.first, startsWith('UTSC-AQMS-09-'));
    });

    test('null device falls back to NA', () {
      expect(Measurement.generateUid(null, DateTime(2026)), startsWith('NA-'));
    });
  });

  group('copyWith', () {
    test('overrides only the given fields', () {
      final m = fullMeasurement();
      final copy = m.copyWith(source: 'imported', notes: 'merged');
      expect(copy.source, 'imported');
      expect(copy.notes, 'merged');
      expect(copy.uid, m.uid);
      expect(copy.pm25, m.pm25);
    });
  });
}
