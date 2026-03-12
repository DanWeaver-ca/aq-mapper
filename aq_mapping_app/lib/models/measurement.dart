class Measurement {
  final int? id;
  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final double? pm25;
  final double? pm10;
  final double? co2;
  final double? hcho;
  final double? temperature;
  final double? humidity;
  final String? notes;

  Measurement({
    this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    this.pm25,
    this.pm10,
    this.co2,
    this.hcho,
    this.temperature,
    this.humidity,
    this.notes,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'pm25': pm25,
      'pm10': pm10,
      'co2': co2,
      'hcho': hcho,
      'temperature': temperature,
      'humidity': humidity,
      'notes': notes,
    };
  }

  factory Measurement.fromMap(Map<String, dynamic> map) {
    return Measurement(
      id: map['id'] as int?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      pm25: map['pm25'] as double?,
      pm10: map['pm10'] as double?,
      co2: map['co2'] as double?,
      hcho: map['hcho'] as double?,
      temperature: map['temperature'] as double?,
      humidity: map['humidity'] as double?,
      notes: map['notes'] as String?,
    );
  }

  List<String> toCsvRow() {
    return [
      timestamp.toIso8601String(),
      latitude.toStringAsFixed(6),
      longitude.toStringAsFixed(6),
      pm25?.toString() ?? '',
      pm10?.toString() ?? '',
      co2?.toString() ?? '',
      hcho?.toString() ?? '',
      temperature?.toString() ?? '',
      humidity?.toString() ?? '',
      notes ?? '',
    ];
  }

  static List<String> csvHeaders = [
    'timestamp',
    'latitude',
    'longitude',
    'PM2.5(ug/m3)',
    'PM10(ug/m3)',
    'CO2(ppm)',
    'HCHO(mg/m3)',
    'temperature(C)',
    'humidity(%)',
    'notes',
  ];
}
