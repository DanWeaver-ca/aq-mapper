import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:aq_mapping_app/screens/data_screen.dart';
import 'package:aq_mapping_app/services/database_service.dart';

import 'measurement_test.dart' show fullMeasurement;

// The send/save platform calls themselves (share sheet, browser download)
// are thin shims that can only be exercised on a real device/browser; these
// tests cover the widget state around them.
void main() {
  sqfliteFfiInit();

  late Database db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // No-isolate factory: widget tests run in a fake-async zone that never
    // receives the ffi worker isolate's replies, so the same-isolate variant
    // is required here (plain test() bodies can use databaseFactoryFfi).
    db = await databaseFactoryFfiNoIsolate.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false));
    await DatabaseService.onCreateDb(db, 2);
    DatabaseService.testDatabase = db;
  });

  tearDown(() async {
    DatabaseService.testDatabase = null;
    await db.close();
  });

  Future<void> pumpDataScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: DataScreen()));
    await tester.pumpAndSettle();
  }

  ElevatedButton sendButton(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.ancestor(
        of: find.text('Send to instructor'),
        matching: find.byType(ElevatedButton),
      ));

  testWidgets('empty database: send button shown but disabled',
      (tester) async {
    await pumpDataScreen(tester);

    expect(find.text('0 measurements'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNull);
  });

  testWidgets('with a measurement: send button enabled', (tester) async {
    await DatabaseService().insertMeasurement(fullMeasurement());
    await pumpDataScreen(tester);

    expect(find.text('1 measurements'), findsOneWidget);
    expect(sendButton(tester).onPressed, isNotNull);
  });

  testWidgets('no separate save button on the io platform', (tester) async {
    // On iOS/Android (and in this io test environment) the share sheet's own
    // "Save to Files" covers saving, so the app must not show a second button.
    await DatabaseService().insertMeasurement(fullMeasurement());
    await pumpDataScreen(tester);

    expect(find.text('Save CSV to my phone'), findsNothing);
  });
}
