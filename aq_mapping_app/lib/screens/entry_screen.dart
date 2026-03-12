import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();
  final _databaseService = DatabaseService();

  final _pm25Controller = TextEditingController();
  final _pm10Controller = TextEditingController();
  final _co2Controller = TextEditingController();
  final _hchoController = TextEditingController();
  final _tempController = TextEditingController();
  final _humidityController = TextEditingController();
  final _notesController = TextEditingController();

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  String? _locationError;

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  Future<void> _getLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });
    try {
      final position = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isLoadingLocation = false;
      });
    }
  }

  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS location not available. Please wait or retry.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final measurement = Measurement(
      timestamp: DateTime.now(),
      latitude: _currentPosition!.latitude,
      longitude: _currentPosition!.longitude,
      pm25: double.tryParse(_pm25Controller.text),
      pm10: double.tryParse(_pm10Controller.text),
      co2: double.tryParse(_co2Controller.text),
      hcho: double.tryParse(_hchoController.text),
      temperature: double.tryParse(_tempController.text),
      humidity: double.tryParse(_humidityController.text),
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    await _databaseService.insertMeasurement(measurement);

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Measurement saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _pm25Controller.dispose();
    _pm10Controller.dispose();
    _co2Controller.dispose();
    _hchoController.dispose();
    _tempController.dispose();
    _humidityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Scaffold resizes body above keyboard — combined with Column layout
      // this keeps the Save button always visible just above the keyboard.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Add Measurement'),
      ),
      // Tap anywhere outside a field to dismiss the keyboard
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              // ── Scrollable field area ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLocationCard(),
                        const SizedBox(height: 16),
                        _buildSensorField(_pm25Controller, 'PM2.5', 'ug/m3'),
                        _buildSensorField(_pm10Controller, 'PM10', 'ug/m3'),
                        _buildSensorField(_co2Controller, 'CO2', 'ppm'),
                        _buildSensorField(_hchoController, 'HCHO', 'mg/m3'),
                        _buildSensorField(_tempController, 'Temperature', 'C'),
                        _buildSensorField(_humidityController, 'Humidity', '%'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes (optional)',
                            hintText: 'e.g., near parking lot, windy',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                          // Extra scroll padding so Notes field clears the
                          // Save button when focused
                          scrollPadding: const EdgeInsets.only(bottom: 80),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // ── Save button — always visible above keyboard ───────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveMeasurement,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Measurement',
                            style: TextStyle(fontSize: 18),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Card(
      color: Colors.teal.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Colors.teal),
            const SizedBox(width: 8),
            Expanded(
              child: _isLoadingLocation
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Getting GPS location...'),
                      ],
                    )
                  : _locationError != null
                      ? Text(
                          _locationError!,
                          style: const TextStyle(color: Colors.red),
                        )
                      : Text(
                          '${_currentPosition!.latitude.toStringAsFixed(5)}, '
                          '${_currentPosition!.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
            ),
            if (!_isLoadingLocation)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getLocation,
                tooltip: 'Refresh location',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorField(
    TextEditingController controller,
    String label,
    String unit,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          suffixText: unit,
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value != null && value.isNotEmpty) {
            if (double.tryParse(value) == null) {
              return 'Enter a valid number';
            }
          }
          return null;
        },
      ),
    );
  }
}
