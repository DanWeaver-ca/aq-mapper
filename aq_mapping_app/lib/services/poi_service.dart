import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app_config.dart';

/// A labelled point of interest for the lab map (a TA station, a suggested
/// measuring spot…), drawn from the deployment's optional
/// `campus_pois.geojson`.
class CampusPoi {
  final String name;
  final LatLng point;
  const CampusPoi({required this.name, required this.point});
}

/// Everything the optional POI file contributes to the map: labelled points
/// plus boundary outlines (stay-inside-this-area polygons or lines).
class CampusPois {
  final List<CampusPoi> pois;
  final List<List<LatLng>> outlines;
  const CampusPois({this.pois = const [], this.outlines = const []});

  bool get isEmpty => pois.isEmpty && outlines.isEmpty;

  /// Parses the GeoJSON subset produced by geojson.io: a FeatureCollection
  /// of Points (name property → label), Polygons / MultiPolygons (outer
  /// rings → outlines) and LineStrings (→ outlines). Anything unparseable
  /// contributes nothing rather than failing the map.
  factory CampusPois.fromGeoJson(String text) {
    final pois = <CampusPoi>[];
    final outlines = <List<LatLng>>[];
    try {
      final root = jsonDecode(text);
      if (root is! Map || root['type'] != 'FeatureCollection') {
        return const CampusPois();
      }
      LatLng pos(dynamic c) =>
          LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      List<LatLng> ring(dynamic coords) =>
          [for (final c in coords as List) pos(c)];

      for (final feature in (root['features'] as List? ?? const [])) {
        if (feature is! Map) continue;
        final geometry = feature['geometry'];
        if (geometry is! Map) continue;
        final props = feature['properties'];
        final name = (props is Map
                ? (props['name'] ?? props['Name'] ?? props['title'])
                : null)
            ?.toString();
        final coords = geometry['coordinates'];
        switch (geometry['type']) {
          case 'Point':
            pois.add(CampusPoi(name: name ?? 'POI', point: pos(coords)));
          case 'LineString':
            outlines.add(ring(coords));
          case 'Polygon':
            for (final r in coords as List) {
              outlines.add(ring(r));
            }
          case 'MultiPolygon':
            for (final polygon in coords as List) {
              for (final r in polygon as List) {
                outlines.add(ring(r));
              }
            }
        }
      }
    } catch (e) {
      debugPrint('campus_pois.geojson unusable: $e');
      return const CampusPois();
    }
    return CampusPois(pois: pois, outlines: outlines);
  }
}

/// Loads the deployment's optional POI file.
///
/// The file lives at the site root next to the app (copied there by the
/// deploy workflow from the repo root). Fetched fresh on each app start;
/// the last good copy is cached in preferences so the map still shows POIs
/// offline in the field. Missing file = empty result = feature invisible.
class PoiService {
  PoiService({http.Client? client, Uri? base})
      : _client = client ?? http.Client(),
        _base = base ?? Uri.base;

  final http.Client _client;
  final Uri _base;

  static final String _cacheKey =
      '${storageKey.isEmpty ? '' : '${storageKey}_'}campus_pois_cache';

  Future<CampusPois> load() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final resp = await _client
          .get(_base.resolve('campus_pois.geojson'))
          .timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200 &&
          resp.body.trimLeft().startsWith('{')) {
        final parsed = CampusPois.fromGeoJson(resp.body);
        if (!parsed.isEmpty) {
          await prefs.setString(_cacheKey, resp.body);
        }
        return parsed;
      }
    } catch (e) {
      debugPrint('POI fetch failed (using cache if any): $e');
    }
    final cached = prefs.getString(_cacheKey);
    return cached == null ? const CampusPois() : CampusPois.fromGeoJson(cached);
  }
}
