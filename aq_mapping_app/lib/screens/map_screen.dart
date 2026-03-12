import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _databaseService = DatabaseService();
  List<Measurement> _measurements = [];
  bool _isLoading = true;

  // UTSC campus center
  static const _utscCenter = LatLng(43.7841, -79.1873);

  @override
  void initState() {
    super.initState();
    _loadMeasurements();
  }

  Future<void> _loadMeasurements() async {
    final measurements = await _databaseService.getAllMeasurements();
    setState(() {
      _measurements = measurements;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Map (${_measurements.length} points)'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : FlutterMap(
              options: MapOptions(
                initialCenter: _measurements.isNotEmpty
                    ? LatLng(
                        _measurements.first.latitude,
                        _measurements.first.longitude,
                      )
                    : _utscCenter,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.utsc.aq.aq_mapping_app',
                ),
                MarkerLayer(
                  markers: _measurements.map((m) => _buildMarker(m)).toList(),
                ),
              ],
            ),
    );
  }

  Marker _buildMarker(Measurement m) {
    return Marker(
      point: LatLng(m.latitude, m.longitude),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showMeasurementPopup(m),
        child: Container(
          decoration: BoxDecoration(
            color: _getMarkerColor(m.pm25),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Text(
              m.pm25?.toStringAsFixed(0) ?? '?',
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

  Color _getMarkerColor(double? pm25) {
    if (pm25 == null) return Colors.grey;
    if (pm25 <= 12) return Colors.green;
    if (pm25 <= 35) return Colors.orange;
    if (pm25 <= 55) return Colors.deepOrange;
    return Colors.red;
  }

  void _showMeasurementPopup(Measurement m) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Measurement Details',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                m.timestamp.toLocal().toString().substring(0, 19),
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 12),
              _infoRow('Location',
                  '${m.latitude.toStringAsFixed(5)}, ${m.longitude.toStringAsFixed(5)}'),
              if (m.pm25 != null) _infoRow('PM2.5', '${m.pm25} ug/m3'),
              if (m.pm10 != null) _infoRow('PM10', '${m.pm10} ug/m3'),
              if (m.co2 != null) _infoRow('CO2', '${m.co2} ppm'),
              if (m.hcho != null) _infoRow('HCHO', '${m.hcho} mg/m3'),
              if (m.temperature != null) _infoRow('Temp', '${m.temperature} C'),
              if (m.humidity != null) _infoRow('Humidity', '${m.humidity}%'),
              if (m.notes != null && m.notes!.isNotEmpty)
                _infoRow('Notes', m.notes!),
              const SizedBox(height: 8),
            ],
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
