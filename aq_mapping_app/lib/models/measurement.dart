import 'dart:math';

import 'package:intl/intl.dart';

class Measurement {
  final int? id;

  /// Stable identity across export/import. Format:
  /// `deviceId|NA` + `-epochMillis-` + 8 random hex chars.
  final String uid;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? pm25;
  final double? pm25Var;
  final double? pm10;
  final double? pm10Var;
  final double? particles;
  final double? co2;
  final double? co2Var;
  final double? hcho;
  final double? hchoVar;
  final double? temperature;
  final double? temperatureVar;
  final String tempUnit;
  final double? humidity;
  final double? humidityVar;
  final String? groupName;
  final String? deviceId;

  /// null on rows recorded before the indoor/outdoor toggle existed.
  final bool? isIndoor;

  /// 'local' = recorded on this device, 'imported' = merged from another
  /// group's CSV.
  final String source;
  final String? notes;

  Measurement({
    this.id,
    required this.uid,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.pm25,
    this.pm25Var,
    this.pm10,
    this.pm10Var,
    this.particles,
    this.co2,
    this.co2Var,
    this.hcho,
    this.hchoVar,
    this.temperature,
    this.temperatureVar,
    this.tempUnit = 'C',
    this.humidity,
    this.humidityVar,
    this.groupName,
    this.deviceId,
    this.isIndoor,
    this.source = 'local',
    this.notes,
  });

  static final Random _random = Random();

  static String generateUid(String? deviceId, DateTime timestamp) {
    final suffix =
        _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0') +
            _random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '${deviceId ?? 'NA'}-${timestamp.millisecondsSinceEpoch}-$suffix';
  }

  Measurement copyWith({
    int? id,
    String? uid,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? pm25,
    double? pm25Var,
    double? pm10,
    double? pm10Var,
    double? particles,
    double? co2,
    double? co2Var,
    double? hcho,
    double? hchoVar,
    double? temperature,
    double? temperatureVar,
    String? tempUnit,
    double? humidity,
    double? humidityVar,
    String? groupName,
    String? deviceId,
    bool? isIndoor,
    String? source,
    String? notes,
  }) {
    return Measurement(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      pm25: pm25 ?? this.pm25,
      pm25Var: pm25Var ?? this.pm25Var,
      pm10: pm10 ?? this.pm10,
      pm10Var: pm10Var ?? this.pm10Var,
      particles: particles ?? this.particles,
      co2: co2 ?? this.co2,
      co2Var: co2Var ?? this.co2Var,
      hcho: hcho ?? this.hcho,
      hchoVar: hchoVar ?? this.hchoVar,
      temperature: temperature ?? this.temperature,
      temperatureVar: temperatureVar ?? this.temperatureVar,
      tempUnit: tempUnit ?? this.tempUnit,
      humidity: humidity ?? this.humidity,
      humidityVar: humidityVar ?? this.humidityVar,
      groupName: groupName ?? this.groupName,
      deviceId: deviceId ?? this.deviceId,
      isIndoor: isIndoor ?? this.isIndoor,
      source: source ?? this.source,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'uid': uid,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'pm25': pm25,
      'pm25_var': pm25Var,
      'pm10': pm10,
      'pm10_var': pm10Var,
      'particles': particles,
      'co2': co2,
      'co2_var': co2Var,
      'hcho': hcho,
      'hcho_var': hchoVar,
      'temperature': temperature,
      'temperature_var': temperatureVar,
      'temp_unit': tempUnit,
      'humidity': humidity,
      'humidity_var': humidityVar,
      'group_name': groupName,
      'device_id': deviceId,
      'is_indoor': isIndoor == null ? null : (isIndoor! ? 1 : 0),
      'source': source,
      'notes': notes,
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    final indoor = map['is_indoor'] as int?;
    return Measurement(
      id: map['id'] as int?,
      uid: map['uid'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      pm25: (map['pm25'] as num?)?.toDouble(),
      pm25Var: (map['pm25_var'] as num?)?.toDouble(),
      pm10: (map['pm10'] as num?)?.toDouble(),
      pm10Var: (map['pm10_var'] as num?)?.toDouble(),
      particles: (map['particles'] as num?)?.toDouble(),
      co2: (map['co2'] as num?)?.toDouble(),
      co2Var: (map['co2_var'] as num?)?.toDouble(),
      hcho: (map['hcho'] as num?)?.toDouble(),
      hchoVar: (map['hcho_var'] as num?)?.toDouble(),
      temperature: (map['temperature'] as num?)?.toDouble(),
      temperatureVar: (map['temperature_var'] as num?)?.toDouble(),
      tempUnit: (map['temp_unit'] as String?) ?? 'C',
      humidity: (map['humidity'] as num?)?.toDouble(),
      humidityVar: (map['humidity_var'] as num?)?.toDouble(),
      groupName: map['group_name'] as String?,
      deviceId: map['device_id'] as String?,
      isIndoor: indoor == null ? null : indoor == 1,
      source: (map['source'] as String?) ?? 'local',
      notes: map['notes'] as String?,
    );
  }

  static final DateFormat _csvDateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

  /// Temtop M2000+ native columns first (byte-identical names so exports can
  /// be compared against the device's own CSV), app-specific columns after.
  static const List<String> csvHeaders = [
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
  ];

  List<String> toCsvRow() {
    String num_(double? v) => v?.toString() ?? '';
    return [
      _csvDateFormat.format(timestamp),
      num_(pm25),
      num_(pm10),
      num_(particles),
      num_(co2),
      num_(hcho),
      num_(temperature),
      num_(humidity),
      tempUnit,
      latitude.toStringAsFixed(6),
      longitude.toStringAsFixed(6),
      groupName ?? '',
      deviceId ?? '',
      isIndoor == null ? '' : (isIndoor! ? 'indoor' : 'outdoor'),
      num_(pm25Var),
      num_(pm10Var),
      num_(co2Var),
      num_(hchoVar),
      num_(temperatureVar),
      num_(humidityVar),
      uid,
      notes ?? '',
    ];
  }

  /// Parses a row keyed by header name (tolerant of column reordering and of
  /// older app exports that lack newer columns). Throws [FormatException] if
  /// DATE/LATITUDE/LONGITUDE are missing or unparseable.
  factory Measurement.fromCsvRow(Map<String, String> row) {
    String? str(String key) {
      final v = row[key]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    double? num_(String key) {
      final v = str(key);
      return v == null ? null : double.tryParse(v);
    }

    final dateStr = str('DATE');
    final lat = num_('LATITUDE');
    final lon = num_('LONGITUDE');
    if (dateStr == null || lat == null || lon == null) {
      throw const FormatException(
          'Row is missing DATE, LATITUDE, or LONGITUDE');
    }
    final DateTime ts;
    try {
      ts = _csvDateFormat.parseStrict(dateStr);
    } on FormatException {
      throw FormatException('Unparseable DATE value: $dateStr');
    }

    final device = str('DEVICE');
    final locationType = str('LOCATION_TYPE')?.toLowerCase();
    // Older exports have no UID; build a deterministic fallback so the same
    // row always dedups to the same key.
    final uid = str('UID') ??
        '${device ?? 'NA'}|$dateStr'
            '|${lat.toStringAsFixed(6)}|${lon.toStringAsFixed(6)}';

    return Measurement(
      uid: uid,
      timestamp: ts,
      latitude: lat,
      longitude: lon,
      pm25: num_('PM2.5(ug/m3)'),
      pm25Var: num_('PM2.5_VAR(ug/m3)'),
      pm10: num_('PM10(ug/m3)'),
      pm10Var: num_('PM10_VAR(ug/m3)'),
      particles: num_('PARTICLES(per/L)'),
      co2: num_('CO2(ppm)'),
      co2Var: num_('CO2_VAR(ppm)'),
      hcho: num_('HCHO(mg/m3)'),
      hchoVar: num_('HCHO_VAR(mg/m3)'),
      temperature: num_('TEMPERATURE'),
      temperatureVar: num_('TEMPERATURE_VAR'),
      tempUnit: str('TEMPUNIT') ?? 'C',
      humidity: num_('HUMIDITY(%)'),
      humidityVar: num_('HUMIDITY_VAR(%)'),
      groupName: str('GROUP'),
      deviceId: device,
      isIndoor: locationType == null ? null : locationType == 'indoor',
      notes: str('NOTES'),
    );
  }
}
