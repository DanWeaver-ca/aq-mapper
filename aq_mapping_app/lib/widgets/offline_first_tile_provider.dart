import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

/// A flutter_map tile provider that serves pre-bundled campus tiles from app
/// assets first (so the map works offline in the field), falling back to the
/// live tile server for anything not bundled.
///
/// Tiles are bundled flat as `assets/tiles/<z>_<x>_<y>.png` (see
/// tool/download_campus_tiles.py); flat because pubspec can't glob nested
/// asset folders.
class OfflineFirstTileProvider extends TileProvider {
  OfflineFirstTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    return _AssetFirstTileImage(
      asset: 'assets/tiles/${coordinates.z}_${coordinates.x}_'
          '${coordinates.y}.png',
      url: getTileUrl(coordinates, options),
      headers: headers,
    );
  }
}

class _AssetFirstTileImage extends ImageProvider<_AssetFirstTileImage> {
  const _AssetFirstTileImage({
    required this.asset,
    required this.url,
    required this.headers,
  });

  final String asset;
  final String url;
  final Map<String, String> headers;

  @override
  Future<_AssetFirstTileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_AssetFirstTileImage>(this);

  @override
  ImageStreamCompleter loadImage(
      _AssetFirstTileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(decode),
      scale: 1.0,
      debugLabel: url,
    );
  }

  Future<ui.Codec> _load(ImageDecoderCallback decode) async {
    // 1) Bundled campus tile — present offline.
    try {
      final data = await rootBundle.load(asset);
      return decode(
          await ui.ImmutableBuffer.fromUint8List(data.buffer.asUint8List()));
    } catch (_) {
      // Not bundled — fall through to the network.
    }
    // 2) Live tile server.
    final res = await http.get(Uri.parse(url), headers: headers);
    if (res.statusCode != 200) {
      throw NetworkImageLoadException(
          statusCode: res.statusCode, uri: Uri.parse(url));
    }
    return decode(await ui.ImmutableBuffer.fromUint8List(res.bodyBytes));
  }

  @override
  bool operator ==(Object other) =>
      other is _AssetFirstTileImage && other.asset == asset && other.url == url;

  @override
  int get hashCode => Object.hash(asset, url);
}
