import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aq_mapping_app/models/map_variable.dart';
import 'package:aq_mapping_app/models/measurement.dart';

void main() {
  test('null always maps to grey', () {
    for (final v in MapVariable.values) {
      expect(v.colorFor(null), Colors.grey, reason: v.label);
    }
  });

  group('threshold boundaries (≤ is inclusive)', () {
    void check(MapVariable v, Map<double, Color> cases) {
      cases.forEach((value, color) {
        expect(v.colorFor(value), color, reason: '${v.label} @ $value');
      });
    }

    test('PM2.5', () {
      check(MapVariable.pm25, {
        0: Colors.green,
        12: Colors.green,
        12.1: Colors.orange,
        35: Colors.orange,
        35.1: Colors.deepOrange,
        55: Colors.deepOrange,
        55.1: Colors.red,
        400: Colors.red,
      });
    });

    test('PM10', () {
      check(MapVariable.pm10, {
        25: Colors.green,
        25.1: Colors.orange,
        50: Colors.orange,
        50.1: Colors.deepOrange,
        100: Colors.deepOrange,
        100.1: Colors.red,
      });
    });

    test('CO2', () {
      check(MapVariable.co2, {
        400: Colors.green,
        800: Colors.green,
        800.1: Colors.orange,
        1000: Colors.orange,
        1000.1: Colors.deepOrange,
        1500: Colors.deepOrange,
        1501: Colors.red,
      });
    });

    test('HCHO', () {
      check(MapVariable.hcho, {
        0.01: Colors.green,
        0.04: Colors.green,
        0.05: Colors.orange,
        0.08: Colors.orange,
        0.09: Colors.deepOrange,
        0.1: Colors.deepOrange,
        0.11: Colors.red,
      });
    });

    test('temperature comfort scale', () {
      check(MapVariable.temperature, {
        -10: Colors.blue,
        15: Colors.blue,
        15.1: Colors.green,
        24: Colors.green,
        24.1: Colors.orange,
        30: Colors.orange,
        30.1: Colors.red,
      });
    });

    test('humidity comfort scale', () {
      check(MapVariable.humidity, {
        10: Colors.blue,
        30: Colors.blue,
        30.1: Colors.green,
        60: Colors.green,
        60.1: Colors.orange,
        80: Colors.orange,
        80.1: Colors.red,
      });
    });
  });

  test('valueOf picks the matching field', () {
    final m = Measurement(
      uid: 'u',
      timestamp: DateTime(2026),
      latitude: 0,
      longitude: 0,
      pm25: 1,
      pm10: 2,
      co2: 3,
      hcho: 4,
      temperature: 5,
      humidity: 6,
    );
    expect(MapVariable.pm25.valueOf(m), 1);
    expect(MapVariable.pm10.valueOf(m), 2);
    expect(MapVariable.co2.valueOf(m), 3);
    expect(MapVariable.hcho.valueOf(m), 4);
    expect(MapVariable.temperature.valueOf(m), 5);
    expect(MapVariable.humidity.valueOf(m), 6);
  });

  test('redThreshold is the top band lower edge', () {
    expect(MapVariable.pm25.redThreshold, 55);
    expect(MapVariable.co2.redThreshold, 1500);
  });

  test('bandRange renders readable ranges', () {
    expect(MapVariable.pm25.bandRange(0), '≤12');
    expect(MapVariable.pm25.bandRange(1), '12–35');
    expect(MapVariable.pm25.bandRange(3), '>55');
    expect(MapVariable.hcho.bandRange(1), '0.04–0.08');
  });
}
