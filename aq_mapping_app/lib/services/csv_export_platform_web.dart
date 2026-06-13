import 'dart:ui';
import 'package:web/web.dart' as web;

/// Web: trigger a browser download of the CSV (lands in Downloads / the iOS
/// Files app). [shareOrigin] is unused on web. The data is small (a few
/// hundred rows), so a data: URL is well within browser limits.
Future<void> deliverCsv(String csvText, String filename,
    {Rect? shareOrigin}) async {
  final href = 'data:text/csv;charset=utf-8,${Uri.encodeComponent(csvText)}';
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = href
    ..download = filename;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
