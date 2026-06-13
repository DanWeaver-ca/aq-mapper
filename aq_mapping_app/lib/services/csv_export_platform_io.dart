import 'dart:io';
import 'dart:ui';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Mobile/desktop: write the CSV to a temp file and open the native share
/// sheet (AirDrop, email, Files…). [shareOrigin] anchors the iOS popover.
Future<void> deliverCsv(String csvText, String filename,
    {Rect? shareOrigin}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(csvText);
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/csv')],
    subject: 'Air Quality Measurements',
    sharePositionOrigin: shareOrigin,
  );
}
