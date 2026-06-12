import 'package:latlong2/latlong.dart';

/// App-wide branding and defaults, kept in one place so the app can be
/// rebranded for other campuses or outreach events with one-line edits.
const String appTitle = 'Air Quality Mapper';

/// Last-resort map center when there are no measurements and GPS is
/// unavailable (UTSC campus). The map prefers measurement locations, then
/// the device's own location.
const LatLng defaultMapCenter = LatLng(43.7841, -79.1873);
