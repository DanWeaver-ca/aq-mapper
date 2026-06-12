import 'package:flutter/material.dart';
import 'measurement.dart';

/// One color band of a variable's legend: values up to (and including)
/// [upperBound] get [color]. A null upperBound means "everything above".
class LegendBand {
  final double? upperBound;
  final Color color;
  final String label;
  const LegendBand(this.upperBound, this.color, this.label);
}

/// A sensor variable that can color the map. Thresholds for PM2.5/PM10/CO2/
/// HCHO follow the lab's air-quality bands; temperature and humidity use
/// comfort-based scales.
enum MapVariable {
  pm25(
    label: 'PM2.5',
    unit: 'µg/m³',
    bands: [
      LegendBand(12, Colors.green, 'good'),
      LegendBand(35, Colors.orange, 'moderate'),
      LegendBand(55, Colors.deepOrange, 'unhealthy (sensitive)'),
      LegendBand(null, Colors.red, 'unhealthy'),
    ],
  ),
  pm10(
    label: 'PM10',
    unit: 'µg/m³',
    bands: [
      LegendBand(25, Colors.green, 'good'),
      LegendBand(50, Colors.orange, 'moderate'),
      LegendBand(100, Colors.deepOrange, 'unhealthy (sensitive)'),
      LegendBand(null, Colors.red, 'unhealthy'),
    ],
  ),
  co2(
    label: 'CO₂',
    unit: 'ppm',
    bands: [
      LegendBand(800, Colors.green, 'fresh'),
      LegendBand(1000, Colors.orange, 'acceptable'),
      LegendBand(1500, Colors.deepOrange, 'stuffy'),
      LegendBand(null, Colors.red, 'poor ventilation'),
    ],
  ),
  hcho(
    label: 'HCHO',
    unit: 'mg/m³',
    bands: [
      LegendBand(0.04, Colors.green, 'good'),
      LegendBand(0.08, Colors.orange, 'moderate'),
      LegendBand(0.1, Colors.deepOrange, 'elevated'),
      LegendBand(null, Colors.red, 'high'),
    ],
  ),
  temperature(
    label: 'Temp',
    unit: '°C',
    bands: [
      LegendBand(15, Colors.blue, 'cold'),
      LegendBand(24, Colors.green, 'comfortable'),
      LegendBand(30, Colors.orange, 'warm'),
      LegendBand(null, Colors.red, 'hot'),
    ],
  ),
  humidity(
    label: 'RH',
    unit: '%',
    bands: [
      LegendBand(30, Colors.blue, 'dry'),
      LegendBand(60, Colors.green, 'comfortable'),
      LegendBand(80, Colors.orange, 'humid'),
      LegendBand(null, Colors.red, 'very humid'),
    ],
  );

  const MapVariable({
    required this.label,
    required this.unit,
    required this.bands,
  });

  final String label;
  final String unit;
  final List<LegendBand> bands;

  double? valueOf(Measurement m) {
    switch (this) {
      case MapVariable.pm25:
        return m.pm25;
      case MapVariable.pm10:
        return m.pm10;
      case MapVariable.co2:
        return m.co2;
      case MapVariable.hcho:
        return m.hcho;
      case MapVariable.temperature:
        return m.temperature;
      case MapVariable.humidity:
        return m.humidity;
    }
  }

  Color colorFor(double? value) {
    if (value == null) return Colors.grey;
    for (final band in bands) {
      if (band.upperBound == null || value <= band.upperBound!) {
        return band.color;
      }
    }
    return bands.last.color;
  }

  /// The lower edge of the top ("red") band — used to normalize heatmap
  /// weights so a red-level reading has full intensity.
  double get redThreshold => bands[bands.length - 2].upperBound!;

  /// Range text for a band, e.g. '≤12', '12–35', '>55'.
  String bandRange(int index) {
    final band = bands[index];
    if (index == 0) return '≤${_fmt(band.upperBound!)}';
    final lower = bands[index - 1].upperBound!;
    if (band.upperBound == null) return '>${_fmt(lower)}';
    return '${_fmt(lower)}–${_fmt(band.upperBound!)}';
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
