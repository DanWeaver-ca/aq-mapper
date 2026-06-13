import 'dart:ui';

/// Platform stub — replaced at compile time by the io or web variant.
Future<void> deliverCsv(String csvText, String filename, {Rect? shareOrigin}) =>
    throw UnsupportedError('CSV export is not supported on this platform.');
