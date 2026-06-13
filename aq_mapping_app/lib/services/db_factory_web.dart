import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web: use the WASM SQLite backend, which persists the database in IndexedDB.
/// Requires `sqlite3.wasm` in web/ (added by `dart run
/// sqflite_common_ffi_web:setup`).
///
/// We use the *no-web-worker* factory on purpose: the shared-worker variant
/// can require cross-origin-isolation (COOP/COEP) headers, which static hosts
/// like GitHub Pages cannot set. Running in the main isolate avoids that, at a
/// negligible cost for our small datasets (hundreds of rows).
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
