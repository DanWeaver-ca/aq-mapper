import 'dart:convert';
import 'dart:ui';
import 'package:share_plus/share_plus.dart';
import 'package:web/web.dart' as web;

import 'csv_export_platform.dart' show SendOutcome;
// Re-export so code importing this variant (via the conditional import in
// csv_export_service.dart) sees the shared outcome type too.
export 'csv_export_platform.dart' show SendOutcome;

/// Web: saving a copy and sending to the instructor are genuinely different
/// actions, so the Data screen shows both buttons.
const bool kHasSeparateSave = true;

/// Trigger a browser download of the CSV (lands in Downloads / the iOS Files
/// app). The data is small (a few hundred rows), so a data: URL is well
/// within browser limits.
Future<void> saveCsv(String csvText, String filename) async {
  final href = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(csvText)}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = href
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

/// Open the share sheet (AirDrop, Mail, Drive…) via the Web Share API — iOS
/// Safari 15+ and Android Chrome. Requires HTTPS (or localhost); where the
/// browser can't share files (desktop Firefox, http:// test servers) this
/// falls back to [saveCsv] and reports it via [SendOutcome.savedInstead]
/// rather than failing silently.
Future<SendOutcome> sendCsv(String csvText, String filename,
    {Rect? shareOrigin}) async {
  // share_plus's own silent download fallback is disabled so the caller can
  // tell the student what actually happened.
  Share.downloadFallbackEnabled = false;
  final file = XFile.fromData(utf8.encode(csvText),
      mimeType: 'text/csv', name: filename);
  try {
    final result = await Share.shareXFiles(
      [file],
      subject: 'Air Quality Measurements',
      // XFile.fromData drops the name on web; this restores the
      // device-prefixed filename the instructor tells groups apart by.
      fileNameOverrides: [filename],
      sharePositionOrigin: shareOrigin,
    );
    return result.status == ShareResultStatus.dismissed
        ? SendOutcome.cancelled
        : SendOutcome.shared;
  } catch (_) {
    await saveCsv(csvText, filename);
    return SendOutcome.savedInstead;
  }
}
