import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'csv_export_platform.dart' show SendOutcome;
// Re-export so code importing this variant (via the conditional import in
// csv_export_service.dart) sees the shared outcome type too.
export 'csv_export_platform.dart' show SendOutcome;

/// Mobile/desktop: the native share sheet already includes "Save to Files",
/// so there is no separate save button on this platform.
const bool kHasSeparateSave = false;

/// No separate save UI here — routes through the share sheet, which has its
/// own save target.
Future<void> saveCsv(String csvText, String filename) async {
  await sendCsv(csvText, filename);
}

/// Write the CSV to a temp file and open the native share sheet (AirDrop,
/// Mail, Files…). [shareOrigin] anchors the iOS popover (required on newer
/// iOS).
Future<SendOutcome> sendCsv(String csvText, String filename,
    {Rect? shareOrigin}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csvText);
  final result = await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Air Quality Measurements',
    sharePositionOrigin: shareOrigin,
  );
  return result.status == ShareResultStatus.dismissed
      ? SendOutcome.cancelled
      : SendOutcome.shared;
}
