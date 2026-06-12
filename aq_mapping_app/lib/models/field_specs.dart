/// Validation bounds and display metadata for each sensor field.
///
/// Hard bounds block saving (physically impossible / outside sensor range);
/// soft bounds trigger a "save anyway?" confirmation for unusual values.
class FieldSpec {
  final String key;
  final String label;
  final String unit;
  final double hardMin;
  final double hardMax;
  final double? softMin;
  final double? softMax;
  final bool hasVariability;

  const FieldSpec({
    required this.key,
    required this.label,
    required this.unit,
    required this.hardMin,
    required this.hardMax,
    this.softMin,
    this.softMax,
    this.hasVariability = true,
  });

  bool isHardViolation(double v) => v < hardMin || v > hardMax;

  bool isSoftViolation(double v) =>
      (softMin != null && v < softMin!) || (softMax != null && v > softMax!);

  String hardBoundMessage() => 'Must be between $hardMin and $hardMax $unit';
}

const pm25Spec = FieldSpec(
  key: 'pm25',
  label: 'PM2.5',
  unit: 'ug/m3',
  hardMin: 0,
  hardMax: 999,
  softMax: 150,
);

const pm10Spec = FieldSpec(
  key: 'pm10',
  label: 'PM10',
  unit: 'ug/m3',
  hardMin: 0,
  hardMax: 999,
  softMax: 250,
);

const particlesSpec = FieldSpec(
  key: 'particles',
  label: 'Particles',
  unit: 'per/L',
  hardMin: 0,
  hardMax: 10000000,
  softMax: 1000000,
  hasVariability: false,
);

const co2Spec = FieldSpec(
  key: 'co2',
  label: 'CO2',
  unit: 'ppm',
  hardMin: 0,
  hardMax: 10000,
  softMin: 350,
  softMax: 5000,
);

const hchoSpec = FieldSpec(
  key: 'hcho',
  label: 'HCHO',
  unit: 'mg/m3',
  hardMin: 0,
  hardMax: 5,
  softMax: 0.5,
);

const temperatureSpec = FieldSpec(
  key: 'temperature',
  label: 'Temp',
  unit: '°C',
  hardMin: -40,
  hardMax: 60,
  softMin: -20,
  softMax: 40,
);

const humiditySpec = FieldSpec(
  key: 'humidity',
  label: 'Humidity',
  unit: '%',
  hardMin: 0,
  hardMax: 100,
);

const allFieldSpecs = [
  pm25Spec,
  pm10Spec,
  particlesSpec,
  co2Spec,
  hchoSpec,
  temperatureSpec,
  humiditySpec,
];
