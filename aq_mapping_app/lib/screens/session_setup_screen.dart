import 'package:flutter/material.dart';
import '../services/session_service.dart';

/// One-time session setup: group name + sensor device ID + temperature unit.
/// Shown automatically on first launch; editable later from the home screen.
class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({super.key, this.canCancel = false});

  /// False on first launch (setup is required), true when editing later.
  final bool canCancel;

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  static const _customDeviceOption = 'Other…';
  static final _standardDevices = List.generate(
      25, (i) => 'UTSC-AQMS-${(i + 1).toString().padLeft(2, '0')}');

  final _formKey = GlobalKey<FormState>();
  final _sessionService = SessionService();
  final _groupController = TextEditingController();
  final _customDeviceController = TextEditingController();
  String? _selectedDevice;
  String _tempUnit = 'C';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  Future<void> _loadExisting() async {
    final group = await _sessionService.groupName;
    final device = await _sessionService.deviceId;
    final unit = await _sessionService.tempUnit;
    if (!mounted) return;
    setState(() {
      _groupController.text = group ?? '';
      if (device != null && device.isNotEmpty) {
        if (_standardDevices.contains(device)) {
          _selectedDevice = device;
        } else {
          _selectedDevice = _customDeviceOption;
          _customDeviceController.text = device;
        }
      }
      _tempUnit = unit;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _groupController.dispose();
    _customDeviceController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final device = _selectedDevice == _customDeviceOption
        ? _customDeviceController.text.trim()
        : _selectedDevice!;
    await _sessionService.save(
      groupName: _groupController.text.trim(),
      deviceId: device,
      tempUnit: _tempUnit,
    );
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: widget.canCancel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Session Setup'),
          automaticallyImplyLeading: widget.canCancel,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Enter your group name and the ID printed on your '
                      'Temtop sensor. These are attached to every '
                      'measurement you record.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _groupController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Group name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a group name'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDevice,
                      decoration: const InputDecoration(
                        labelText: 'Sensor device ID',
                        border: OutlineInputBorder(),
                      ),
                      items: [..._standardDevices, _customDeviceOption]
                          .map((d) =>
                              DropdownMenuItem(value: d, child: Text(d)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedDevice = v),
                      validator: (v) => v == null ? 'Select a device' : null,
                    ),
                    if (_selectedDevice == _customDeviceOption) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _customDeviceController,
                        decoration: const InputDecoration(
                          labelText: 'Custom device ID',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter the device ID'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Text('Temperature unit'),
                        const Spacer(),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'C', label: Text('°C')),
                            ButtonSegment(value: 'F', label: Text('°F')),
                          ],
                          selected: {_tempUnit},
                          onSelectionChanged: (s) =>
                              setState(() => _tempUnit = s.first),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Start Session'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
