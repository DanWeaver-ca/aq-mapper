import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aq_mapping_app/services/poi_service.dart';

const _geojson = '''
{
  "type": "FeatureCollection",
  "features": [
    {"type": "Feature", "properties": {"name": "TA station"},
     "geometry": {"type": "Point", "coordinates": [-79.19, 43.78]}},
    {"type": "Feature", "properties": {},
     "geometry": {"type": "Point", "coordinates": [-79.18, 43.79]}},
    {"type": "Feature", "properties": {"name": "Boundary"},
     "geometry": {"type": "Polygon", "coordinates":
       [[[-79.2, 43.77], [-79.17, 43.77], [-79.17, 43.80], [-79.2, 43.77]]]}},
    {"type": "Feature", "properties": {"name": "Walk"},
     "geometry": {"type": "LineString",
       "coordinates": [[-79.19, 43.78], [-79.18, 43.785]]}}
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final base = Uri.parse('https://example.org/aq-mapper/');

  group('CampusPois.fromGeoJson', () {
    test('parses points, polygons, and lines from geojson.io output', () {
      final pois = CampusPois.fromGeoJson(_geojson);

      expect(pois.pois, hasLength(2));
      expect(pois.pois.first.name, 'TA station');
      expect(pois.pois.first.point.latitude, closeTo(43.78, 1e-9));
      expect(pois.pois.first.point.longitude, closeTo(-79.19, 1e-9));
      expect(pois.pois[1].name, 'POI'); // nameless → placeholder

      // One polygon ring + one linestring.
      expect(pois.outlines, hasLength(2));
      expect(pois.outlines.first, hasLength(4));
    });

    test('is empty for garbage or non-FeatureCollection input', () {
      expect(CampusPois.fromGeoJson('not json').isEmpty, isTrue);
      expect(
          CampusPois.fromGeoJson(jsonEncode({'type': 'Feature'})).isEmpty,
          isTrue);
    });
  });

  group('PoiService.load', () {
    test('fetches, parses, and caches the file', () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient((request) async {
        expect(request.url.toString(),
            'https://example.org/aq-mapper/campus_pois.geojson');
        return http.Response(_geojson, 200);
      });

      final pois = await PoiService(client: client, base: base).load();

      expect(pois.pois, hasLength(2));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('campus_pois_cache'), _geojson);
    });

    test('falls back to the cached copy when the network fails', () async {
      SharedPreferences.setMockInitialValues(
          {'campus_pois_cache': _geojson});
      final client = MockClient(
          (request) async => throw http.ClientException('offline'));

      final pois = await PoiService(client: client, base: base).load();

      expect(pois.pois, hasLength(2), reason: 'field mode: offline uses cache');
    });

    test('is quietly empty when no file is deployed', () async {
      SharedPreferences.setMockInitialValues({});
      final client =
          MockClient((request) async => http.Response('nope', 404));

      final pois = await PoiService(client: client, base: base).load();

      expect(pois.isEmpty, isTrue);
    });

    test('ignores an HTML 200 (SPA fallback pages) instead of caching it',
        () async {
      SharedPreferences.setMockInitialValues({});
      final client = MockClient(
          (request) async => http.Response('<html>not found</html>', 200));

      final pois = await PoiService(client: client, base: base).load();

      expect(pois.isEmpty, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('campus_pois_cache'), isNull);
    });
  });
}
