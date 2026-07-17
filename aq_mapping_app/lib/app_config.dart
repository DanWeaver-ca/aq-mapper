import 'package:latlong2/latlong.dart';

/// App-wide branding and defaults, kept in one place so the app can be
/// rebranded for other campuses or outreach events with one-line edits.
const String appTitle = 'Air Quality Mapper';

/// Shown small in the UI so you can tell which build a student is running.
/// Bump when distributing a new version.
const String appVersion = '1.1.0';

/// Shown under "Send to instructor" on the Data screen so students can
/// address the share (the Web Share API cannot pre-fill a recipient).
/// Leave empty to hide the hint. Adopters: put your own address here.
const String instructorEmail = 'dan.weaver@utoronto.ca';

/// Last-resort map center when there are no measurements and GPS is
/// unavailable (UTSC campus). The map prefers measurement locations, then
/// the device's own location.
const LatLng defaultMapCenter = LatLng(43.7841, -79.1873);
