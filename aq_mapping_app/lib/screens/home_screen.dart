import 'package:flutter/material.dart';
import '../app_config.dart';
import '../services/session_service.dart';
import 'entry_screen.dart';
import 'history_screen.dart';
import 'map_screen.dart';
import 'data_screen.dart';
import 'session_setup_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _sessionService = SessionService();
  String? _groupName;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final configured = await _sessionService.isConfigured;
    if (!configured) {
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const SessionSetupScreen(canCancel: false),
        ),
      );
    }
    await _loadSession();
  }

  Future<void> _loadSession() async {
    final group = await _sessionService.groupName;
    final device = await _sessionService.deviceId;
    if (!mounted) return;
    setState(() {
      _groupName = group;
      _deviceId = device;
    });
  }

  Future<void> _editSession() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SessionSetupScreen(canCancel: true),
      ),
    );
    await _loadSession();
  }

  void _push(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // No AppBar: this is the root screen and the hero section below
      // already carries the app title.
      body: SafeArea(
        // Scroll-safe: content centers when it fits and scrolls when it
        // doesn't (standard LayoutBuilder + ConstrainedBox + IntrinsicHeight
        // recipe).
        child: LayoutBuilder(
          builder: (context, viewportConstraints) {
            // Landscape gets a 2x2 tile grid so all four destinations fit
            // without scrolling; portrait keeps full-width stacked buttons.
            final isLandscape =
                viewportConstraints.maxWidth > viewportConstraints.maxHeight;
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: viewportConstraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _CloudParticlesIcon(size: 48),
                            SizedBox(width: 12),
                            Text(
                              appTitle,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_groupName != null && _deviceId != null)
                          Center(
                            child: ActionChip(
                              avatar: const Icon(Icons.group, size: 18),
                              label: Text('$_groupName · $_deviceId'),
                              onPressed: _editSession,
                            ),
                          )
                        else
                          Text(
                            'Record sensor readings with GPS location',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        SizedBox(height: isLandscape ? 20 : 32),
                        ..._buildNavArea(isLandscape),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildNavArea(bool isLandscape) {
    final buttons = [
      _NavButton(
        icon: Icons.add_circle_outline,
        label: 'Add Measurement',
        color: Colors.teal,
        onPressed: () => _push(const EntryScreen()),
      ),
      _NavButton(
        icon: Icons.history,
        label: 'History',
        color: Colors.indigo,
        onPressed: () => _push(const HistoryScreen()),
      ),
      _NavButton(
        icon: Icons.map_outlined,
        label: 'View Map',
        color: Colors.blue,
        onPressed: () => _push(const MapScreen()),
      ),
      _NavButton(
        icon: Icons.import_export,
        label: 'Export / Import Data',
        color: Colors.orange,
        onPressed: () => _push(const DataScreen()),
      ),
    ];

    if (!isLandscape) {
      return [
        buttons[0],
        const SizedBox(height: 14),
        buttons[1],
        const SizedBox(height: 14),
        buttons[2],
        const SizedBox(height: 14),
        buttons[3],
      ];
    }
    return [
      Row(
        children: [
          Expanded(child: buttons[0]),
          const SizedBox(width: 14),
          Expanded(child: buttons[1]),
        ],
      ),
      const SizedBox(height: 14),
      Row(
        children: [
          Expanded(child: buttons[2]),
          const SizedBox(width: 14),
          Expanded(child: buttons[3]),
        ],
      ),
    ];
  }
}

/// A cloud outline with faint dots inside: air + thought bubble, with the
/// dots hinting at particulate composition.
class _CloudParticlesIcon extends StatelessWidget {
  const _CloudParticlesIcon({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    Widget dot(double left, double top, double diameter, double opacity) {
      return Positioned(
        left: size * left,
        top: size * top,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: Colors.teal.withValues(alpha: opacity),
            shape: BoxShape.circle,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Icon(Icons.filter_drama, size: size, color: Colors.teal),
          // Dots sit in the open body of the cloud outline.
          dot(0.32, 0.48, size * 0.09, 0.8),
          dot(0.50, 0.56, size * 0.07, 0.6),
          dot(0.62, 0.44, size * 0.08, 0.45),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label, style: const TextStyle(fontSize: 18)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}
