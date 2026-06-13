import 'package:flutter/material.dart';
import 'app_config.dart';
import 'screens/home_screen.dart';
// Selects the SQLite backend per platform: native sqflite on mobile, the WASM
// (IndexedDB) backend on web. Picked at compile time via conditional import.
import 'services/db_factory_stub.dart'
    if (dart.library.io) 'services/db_factory_io.dart'
    if (dart.library.js_interop) 'services/db_factory_web.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  configureDatabaseFactory();
  runApp(const AQMappingApp());
}

class AQMappingApp extends StatelessWidget {
  const AQMappingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
