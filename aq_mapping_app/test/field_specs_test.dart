import 'package:flutter_test/flutter_test.dart';
import 'package:aq_mapping_app/models/field_specs.dart';

void main() {
  test('hard bounds block impossible values', () {
    expect(pm25Spec.isHardViolation(-1), isTrue);
    expect(pm25Spec.isHardViolation(0), isFalse);
    expect(pm25Spec.isHardViolation(999), isFalse);
    expect(pm25Spec.isHardViolation(1000), isTrue);

    expect(humiditySpec.isHardViolation(100), isFalse);
    expect(humiditySpec.isHardViolation(100.1), isTrue);

    expect(temperatureSpec.isHardViolation(-40), isFalse);
    expect(temperatureSpec.isHardViolation(-41), isTrue);
    expect(temperatureSpec.isHardViolation(60), isFalse);
    expect(temperatureSpec.isHardViolation(61), isTrue);
  });

  test('soft bounds warn on unusual values', () {
    expect(pm25Spec.isSoftViolation(150), isFalse);
    expect(pm25Spec.isSoftViolation(151), isTrue);

    // CO2 warns both low (below outdoor ambient) and high.
    expect(co2Spec.isSoftViolation(349), isTrue);
    expect(co2Spec.isSoftViolation(425), isFalse);
    expect(co2Spec.isSoftViolation(5001), isTrue);

    expect(hchoSpec.isSoftViolation(0.5), isFalse);
    expect(hchoSpec.isSoftViolation(0.51), isTrue);

    // Humidity has no soft bounds — hard 0–100 covers it.
    expect(humiditySpec.isSoftViolation(99), isFalse);
  });

  test('every sensor field has a spec', () {
    expect(allFieldSpecs.map((s) => s.key), [
      'pm25',
      'pm10',
      'particles',
      'co2',
      'hcho',
      'temperature',
      'humidity',
    ]);
    // Particles is the only field without a ± companion.
    expect(
      allFieldSpecs.where((s) => !s.hasVariability).map((s) => s.key),
      ['particles'],
    );
  });
}
