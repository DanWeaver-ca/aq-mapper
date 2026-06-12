import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map_heatmap/flutter_map_heatmap.dart' as fmh;
import 'package:latlong2/latlong.dart';

import '../models/map_variable.dart';
import '../models/measurement.dart';

/// Wraps flutter_map_heatmap so the rest of the app never touches it
/// directly — if the package (stale, pins flutter_map to 7.x) needs
/// replacing, only this file changes.
///
/// Caveat inherent to the package: it renders point *density*, so several
/// overlapping clean readings can glow as strongly as one polluted reading.
/// Weights are normalized to the variable's red threshold to limit this.
class MeasurementHeatmapLayer extends StatelessWidget {
  const MeasurementHeatmapLayer({
    super.key,
    required this.measurements,
    required this.variable,
    required this.reset,
  });

  final List<Measurement> measurements;
  final MapVariable variable;

  /// Fire when the selected variable or data changes so tiles regenerate.
  final Stream<void> reset;

  @override
  Widget build(BuildContext context) {
    final points = <fmh.WeightedLatLng>[];
    for (final m in measurements) {
      final value = variable.valueOf(m);
      if (value == null) continue;
      final weight = (value / variable.redThreshold).clamp(0.1, 1.5);
      points.add(fmh.WeightedLatLng(
        LatLng(m.latitude, m.longitude),
        weight.toDouble(),
      ));
    }
    if (points.isEmpty) return const SizedBox.shrink();
    return fmh.HeatMapLayer(
      heatMapDataSource: fmh.InMemoryHeatMapDataSource(data: points),
      heatMapOptions: fmh.HeatMapOptions(radius: 40, layerOpacity: 0.8),
      reset: reset,
    );
  }
}
