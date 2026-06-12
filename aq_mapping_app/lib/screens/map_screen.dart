import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../app_config.dart';
import '../models/map_variable.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../widgets/heatmap_layer.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _databaseService = DatabaseService();
  final _locationService = LocationService();
  final _mapController = MapController();
  final _heatmapReset = StreamController<void>.broadcast();
  List<Measurement> _measurements = [];
  bool _isLoading = true;
  bool _showHeatmap = false;
  bool _legendExpanded = true;
  MapVariable _variable = MapVariable.pm25;

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  @override
  void dispose() {
    _heatmapReset.close();
    super.dispose();
  }

  Future<void> _loadMeasurements() async {
    final measurements = await _databaseService.getAllMeasurements();
    setState(() {
      _measurements = measurements;
      _isLoading = false;
    });
    if (measurements.isEmpty) _centerOnDevice();
  }

  /// With no measurements to frame, center the map on the device itself so
  /// the app works anywhere — not just at UTSC. Last-known fix first
  /// (instant), then a live GPS fix; the campus default stays if both fail.
  Future<void> _centerOnDevice() async {
    final last = await _locationService.getLastKnownPosition();
    if (!mounted) return;
    if (last != null) {
      _mapController.move(LatLng(last.latitude, last.longitude), 15.0);
      return;
    }
    try {
      final current = await _locationService.getCurrentPosition();
      if (!mounted) return;
      _mapController.move(
          LatLng(current.latitude, current.longitude), 15.0);
    } catch (_) {
      // Keep the default center.
    }
  }

  void _selectVariable(MapVariable v) {
    setState(() => _variable = v);
    _heatmapReset.add(null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map (${_measurements.length} points)'),
        actions: [
          IconButton(
            icon: Icon(
              _showHeatmap ? Icons.blur_on : Icons.blur_off,
              color: _showHeatmap ? Colors.amber : null,
            ),
            tooltip: _showHeatmap ? 'Show markers' : 'Show heatmap',
            onPressed: () {
              setState(() => _showHeatmap = !_showHeatmap);
              _heatmapReset.add(null);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildVariableSelector(),
                Expanded(
                  child: Stack(
                    children: [
                      _buildMap(),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: _buildLegend(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVariableSelector() {
    return Container(
      height: 52,
      color: Theme.of(context).colorScheme.surface,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final v in MapVariable.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(v.label),
                selected: _variable == v,
                onSelected: (_) => _selectVariable(v),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _measurements.isNotEmpty
            ? LatLng(
                _measurements.first.latitude,
                _measurements.first.longitude,
              )
            : defaultMapCenter,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.utsc.aq.aq_mapping_app',
        ),
        if (_showHeatmap)
          MeasurementHeatmapLayer(
            measurements: _measurements,
            variable: _variable,
            reset: _heatmapReset.stream,
          )
        else
          MarkerLayer(
            markers: _measurements.map((m) => _buildMarker(m)).toList(),
          ),
      ],
    );
  }

  Widget _buildLegend() {
    if (!_legendExpanded) {
      return ActionChip(
        avatar: const Icon(Icons.legend_toggle, size: 18),
        label: const Text('Legend'),
        onPressed: () => setState(() => _legendExpanded = true),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _legendExpanded = false),
      child: Card(
        color: Colors.white.withValues(alpha: 0.92),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_variable.label} (${_variable.unit})',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < _variable.bands.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _variable.bands[i].color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_variable.bandRange(i)}  '
                        '${_variable.bands[i].label}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1.5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text('no data', style: TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Marker _buildMarker(Measurement m) {
    final value = _variable.valueOf(m);
    final isImported = m.source == 'imported';
    return Marker(
      point: LatLng(m.latitude, m.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showMeasurementPopup(m),
        child: Container(
          decoration: BoxDecoration(
            color: _variable.colorFor(value),
            shape: BoxShape.circle,
            // Imported points get a dark border so merged datasets are
            // distinguishable from this device's own readings.
            border: Border.all(
              color: isImported ? Colors.black87 : Colors.white,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              _markerText(value),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _markerText(double? value) {
    if (value == null) return '?';
    // HCHO values are small decimals; everything else reads fine rounded.
    if (_variable == MapVariable.hcho) return value.toStringAsFixed(2);
    return value.toStringAsFixed(0);
  }

  void _showMeasurementPopup(Measurement m) {
    String withVar(double? value, double? variability, String unit) {
      if (variability != null) return '$value ± $variability $unit';
      return '$value $unit';
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Measurement Details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (m.source == 'imported')
                      Chip(
                        label: const Text('imported'),
                        visualDensity: VisualDensity.compact,
                        labelStyle: const TextStyle(fontSize: 11),
                        backgroundColor: Colors.grey[200],
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('yyyy-MM-dd HH:mm:ss')
                      .format(m.timestamp.toLocal()),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                _infoRow('Location',
                    '${m.latitude.toStringAsFixed(5)}, ${m.longitude.toStringAsFixed(5)}'),
                if (m.groupName != null) _infoRow('Group', m.groupName!),
                if (m.deviceId != null) _infoRow('Device', m.deviceId!),
                if (m.isIndoor != null)
                  _infoRow('Setting', m.isIndoor! ? 'Indoor' : 'Outdoor'),
                if (m.pm25 != null)
                  _infoRow('PM2.5', withVar(m.pm25, m.pm25Var, 'ug/m3')),
                if (m.pm10 != null)
                  _infoRow('PM10', withVar(m.pm10, m.pm10Var, 'ug/m3')),
                if (m.particles != null)
                  _infoRow('Particles', '${m.particles} per/L'),
                if (m.co2 != null)
                  _infoRow('CO2', withVar(m.co2, m.co2Var, 'ppm')),
                if (m.hcho != null)
                  _infoRow('HCHO', withVar(m.hcho, m.hchoVar, 'mg/m3')),
                if (m.temperature != null)
                  _infoRow(
                      'Temp',
                      withVar(
                          m.temperature, m.temperatureVar, '°${m.tempUnit}')),
                if (m.humidity != null)
                  _infoRow('Humidity', withVar(m.humidity, m.humidityVar, '%')),
                if (m.notes != null && m.notes!.isNotEmpty)
                  _infoRow('Notes', m.notes!),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
