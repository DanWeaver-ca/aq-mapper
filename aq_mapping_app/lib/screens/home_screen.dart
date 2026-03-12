import 'package:flutter/material.dart';
import 'entry_screen.dart';
import 'map_screen.dart';
import 'export_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Air Quality Mapper'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.air,
              size: 80,
              color: Colors.teal,
            ),
            const SizedBox(height: 16),
            const Text(
              'UTSC Air Quality Lab',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record sensor readings with GPS location',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 48),
            _NavButton(
              icon: Icons.add_circle_outline,
              label: 'Add Measurement',
              color: Colors.teal,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EntryScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _NavButton(
              icon: Icons.map_outlined,
              label: 'View Map',
              color: Colors.blue,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MapScreen()),
              ),
            ),
            const SizedBox(height: 16),
            _NavButton(
              icon: Icons.file_download_outlined,
              label: 'Export Data',
              color: Colors.orange,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExportScreen()),
              ),
            ),
          ],
        ),
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
