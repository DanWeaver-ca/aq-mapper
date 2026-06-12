import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../models/field_specs.dart';
import '../models/measurement.dart';
import '../services/database_service.dart';
import '../services/location_service.dart';
import '../services/session_service.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key, this.existing});

  /// When set, the screen edits this measurement instead of creating a new
  /// one: GPS/timestamp/uid/source are preserved unless re-captured.
  final Measurement? existing;

  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _FieldPair {
  final FieldSpec spec;
  final TextEditingController value = TextEditingController();
  final TextEditingController variability = TextEditingController();

  _FieldPair(this.spec);

  void dispose() {
    value.dispose();
    variability.dispose();
  }
}

class _EntryScreenState extends State<EntryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationService = LocationService();
  final _databaseService = DatabaseService();
  final _sessionService = SessionService();

  late final Map<String, _FieldPair> _fields = {
    for (final spec in allFieldSpecs) spec.key: _FieldPair(spec),
  };
  final _notesController = TextEditingController();

  Position? _currentPosition;
  bool _isLoadingLocation = true;
  bool _isSaving = false;
  bool _isIndoor = false;
  String? _locationError;
  DateTime? _capturedAt;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _prefillFromExisting(widget.existing!);
    } else {
      _getLocation();
    }
  }

  void _prefillFromExisting(Measurement m) {
    String fmt(double? v) => v?.toString() ?? '';
    _fields['pm25']!.value.text = fmt(m.pm25);
    _fields['pm25']!.variability.text = fmt(m.pm25Var);
    _fields['pm10']!.value.text = fmt(m.pm10);
    _fields['pm10']!.variability.text = fmt(m.pm10Var);
    _fields['particles']!.value.text = fmt(m.particles);
    _fields['co2']!.value.text = fmt(m.co2);
    _fields['co2']!.variability.text = fmt(m.co2Var);
    _fields['hcho']!.value.text = fmt(m.hcho);
    _fields['hcho']!.variability.text = fmt(m.hchoVar);
    _fields['temperature']!.value.text = fmt(m.temperature);
    _fields['temperature']!.variability.text = fmt(m.temperatureVar);
    _fields['humidity']!.value.text = fmt(m.humidity);
    _fields['humidity']!.variability.text = fmt(m.humidityVar);
    _notesController.text = m.notes ?? '';
    _isIndoor = m.isIndoor ?? false;
    _isLoadingLocation = false;
    _capturedAt = m.timestamp;
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
        _capturedAt = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _locationError = e.toString();
        _isLoadingLocation = false;
      });
    }
  }

  double? _parsedValue(String key) {
    final text = _fields[key]!.value.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  double? _parsedVariability(String key) {
    final text = _fields[key]!.variability.text.trim();
    return text.isEmpty ? null : double.tryParse(text);
  }

  /// Returns human-readable descriptions of unusual (soft-bound) values.
  List<String> _softWarnings() {
    final warnings = <String>[];
    for (final pair in _fields.values) {
      final v = _parsedValue(pair.spec.key);
      if (v != null && pair.spec.isSoftViolation(v)) {
        warnings.add('${pair.spec.label} = $v ${pair.spec.unit} is unusual');
      }
      final variability = _parsedVariability(pair.spec.key);
      if (variability != null && v != null && variability > v) {
        warnings.add(
            '${pair.spec.label} variability (±$variability) exceeds the '
            'value itself');
      }
    }
    return warnings;
  }

  Future<void> _saveMeasurement() async {
    if (!_formKey.currentState!.validate()) return;

    final latitude = _isEditing && _currentPosition == null
        ? widget.existing!.latitude
        : _currentPosition?.latitude;
    final longitude = _isEditing && _currentPosition == null
        ? widget.existing!.longitude
        : _currentPosition?.longitude;
    if (latitude == null || longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS location not available. Please wait or retry.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final warnings = _softWarnings();
    if (warnings.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unusual values'),
          content: Text(
              '${warnings.join('.\n')}.\n\nDouble-check the sensor display. '
              'Save anyway?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Save anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    setState(() => _isSaving = true);

    final groupName =
        widget.existing?.groupName ?? await _sessionService.groupName;
    final deviceId =
        widget.existing?.deviceId ?? await _sessionService.deviceId;
    final tempUnit =
        widget.existing?.tempUnit ?? await _sessionService.tempUnit;
    final timestamp = widget.existing?.timestamp ?? DateTime.now();

    final measurement = Measurement(
      id: widget.existing?.id,
      uid: widget.existing?.uid ?? Measurement.generateUid(deviceId, timestamp),
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
      pm25: _parsedValue('pm25'),
      pm25Var: _parsedVariability('pm25'),
      pm10: _parsedValue('pm10'),
      pm10Var: _parsedVariability('pm10'),
      particles: _parsedValue('particles'),
      co2: _parsedValue('co2'),
      co2Var: _parsedVariability('co2'),
      hcho: _parsedValue('hcho'),
      hchoVar: _parsedVariability('hcho'),
      temperature: _parsedValue('temperature'),
      temperatureVar: _parsedVariability('temperature'),
      tempUnit: tempUnit,
      humidity: _parsedValue('humidity'),
      humidityVar: _parsedVariability('humidity'),
      groupName: groupName,
      deviceId: deviceId,
      isIndoor: _isIndoor,
      source: widget.existing?.source ?? 'local',
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );

    if (_isEditing) {
      await _databaseService.updateMeasurement(measurement);
    } else {
      await _databaseService.insertMeasurement(measurement);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isEditing ? 'Measurement updated!' : 'Measurement saved!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  void dispose() {
    for (final pair in _fields.values) {
      pair.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    return Scaffold(
      // Scaffold resizes body above keyboard — combined with Column layout
      // this keeps the Save button always visible just above the keyboard.
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Measurement' : 'Add Measurement'),
      ),
      // Tap anywhere outside a field to dismiss the keyboard
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          // Landscape: with the keyboard up there is too little height to
          // pin Save below the fields, so the whole form (Save included)
          // scrolls as one unit. Portrait: Save stays pinned above the
          // keyboard.
          child: isLandscape
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildForm(),
                      const SizedBox(height: 16),
                      _buildSaveButton(),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // ── Scrollable field area ─────────────────────────────
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: _buildForm(),
                      ),
                    ),
                    // ── Save button — always visible above keyboard ───────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: _buildSaveButton(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLocationCard(),
          const SizedBox(height: 12),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Outdoor'),
                icon: Icon(Icons.park_outlined),
              ),
              ButtonSegment(
                value: true,
                label: Text('Indoor'),
                icon: Icon(Icons.meeting_room_outlined),
              ),
            ],
            selected: {_isIndoor},
            onSelectionChanged: (s) => setState(() => _isIndoor = s.first),
          ),
          const SizedBox(height: 16),
          _buildSensorRow(_fields['pm25']!),
          _buildSensorRow(_fields['pm10']!),
          _buildSensorRow(_fields['particles']!),
          _buildSensorRow(_fields['co2']!),
          _buildSensorRow(_fields['hcho']!),
          _buildSensorRow(_fields['temperature']!),
          _buildSensorRow(_fields['humidity']!),
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
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
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
            : Text(
                _isEditing ? 'Update Measurement' : 'Save Measurement',
                style: const TextStyle(fontSize: 18),
              ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final lat = _currentPosition?.latitude ?? widget.existing?.latitude;
    final lon = _currentPosition?.longitude ?? widget.existing?.longitude;
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
                        Flexible(child: Text('Getting GPS location...')),
                      ],
                    )
                  : _locationError != null
                      ? Text(
                          _locationError!,
                          style: const TextStyle(color: Colors.red),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${lat?.toStringAsFixed(5)}, '
                              '${lon?.toStringAsFixed(5)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (_capturedAt != null)
                              Text(
                                DateFormat('yyyy-MM-dd HH:mm:ss')
                                    .format(_capturedAt!),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
            ),
            if (!_isLoadingLocation)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _getLocation,
                tooltip: _isEditing ? 'Re-capture GPS' : 'Refresh location',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorRow(_FieldPair pair) {
    final spec = pair.spec;
    final keyboard = TextInputType.numberWithOptions(
      decimal: true,
      signed: spec.hardMin < 0,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: spec.hasVariability
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: pair.value,
                    keyboardType: keyboard,
                    decoration: InputDecoration(
                      labelText: spec.label,
                      suffixText: spec.unit,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (v) => _validateValue(spec, v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: pair.variability,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Variability',
                      prefixText: '± ',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => _validateVariability(spec, v),
                  ),
                ),
              ],
            )
          : TextFormField(
              controller: pair.value,
              keyboardType: keyboard,
              decoration: InputDecoration(
                labelText: spec.label,
                suffixText: spec.unit,
                border: const OutlineInputBorder(),
              ),
              validator: (v) => _validateValue(spec, v),
            ),
    );
  }

  String? _validateValue(FieldSpec spec, String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final v = double.tryParse(text.trim());
    if (v == null) return 'Enter a valid number';
    if (spec.isHardViolation(v)) return spec.hardBoundMessage();
    return null;
  }

  String? _validateVariability(FieldSpec spec, String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final v = double.tryParse(text.trim());
    if (v == null) return 'Invalid number';
    if (v < 0) return 'Must be ≥ 0';
    if (v > spec.hardMax) return 'Too large';
    if (_fields[spec.key]!.value.text.trim().isEmpty) {
      return 'Enter ${spec.label} first';
    }
    return null;
  }
}
