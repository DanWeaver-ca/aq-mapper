import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aq_mapping_app/screens/entry_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'session_group_name': 'Maple Group',
      'session_device_id': 'UTSC-AQMS-07',
      'session_temp_unit': 'C',
    });
  });

  // The default 800x600 test viewport is wider than tall, which the screen
  // treats as landscape — so every test pins an explicit phone size
  // (portrait unless stated otherwise).
  Future<void> pumpEntry(WidgetTester tester,
      {Size size = const Size(390, 844)}) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const MaterialApp(home: EntryScreen()));
    // Fixed pumps instead of pumpAndSettle: the GPS spinner animates until
    // the (failing, in tests) location lookup resolves.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Finder fieldByLabel(String label) => find.ancestor(
        of: find.text(label),
        matching: find.byType(TextFormField),
      );

  testWidgets('non-numeric input is rejected', (tester) async {
    await pumpEntry(tester);
    await tester.enterText(fieldByLabel('PM2.5').first, 'abc');
    await tester.tap(find.text('Save Measurement'));
    await tester.pump();
    expect(find.text('Enter a valid number'), findsOneWidget);
  });

  testWidgets('hard-bound violation is blocked', (tester) async {
    await pumpEntry(tester);
    await tester.enterText(fieldByLabel('Humidity').first, '150');
    await tester.tap(find.text('Save Measurement'));
    await tester.pump();
    expect(find.textContaining('Must be between'), findsOneWidget);
  });

  testWidgets('negative PM2.5 is blocked', (tester) async {
    await pumpEntry(tester);
    await tester.enterText(fieldByLabel('PM2.5').first, '-5');
    await tester.tap(find.text('Save Measurement'));
    await tester.pump();
    expect(find.textContaining('Must be between'), findsOneWidget);
  });

  testWidgets('variability without a main value is blocked', (tester) async {
    await pumpEntry(tester);
    // First Variability field belongs to PM2.5.
    await tester.enterText(fieldByLabel('Variability').first, '2');
    await tester.tap(find.text('Save Measurement'));
    await tester.pump();
    expect(find.text('Enter PM2.5 first'), findsOneWidget);
  });

  testWidgets('valid values produce no validation errors', (tester) async {
    await pumpEntry(tester);
    await tester.enterText(fieldByLabel('PM2.5').first, '14.7');
    await tester.enterText(fieldByLabel('CO2').first, '425');
    await tester.tap(find.text('Save Measurement'));
    await tester.pump();
    expect(find.text('Enter a valid number'), findsNothing);
    expect(find.textContaining('Must be between'), findsNothing);
    // Save still aborts on missing GPS in the test environment.
    expect(find.text('GPS location not available. Please wait or retry.'),
        findsOneWidget);
  });

  testWidgets('landscape with keyboard: all fields and Save are reachable',
      (tester) async {
    // iPhone-ish landscape viewport with a simulated on-screen keyboard
    // (the viewInset shrinks the scaffold the same way the real one does).
    tester.view.viewInsets = const FakeViewPadding(bottom: 230 * 3);
    addTearDown(() => tester.view.resetViewInsets());

    await pumpEntry(tester, size: const Size(844, 390));
    expect(tester.takeException(), isNull);

    // Both the last field and the Save button must be reachable by scroll.
    await tester.scrollUntilVisible(
        find.text('Notes (optional)'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Notes (optional)'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Save Measurement'), 100,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Save Measurement'), findsOneWidget);
  });

  testWidgets('form shows indoor/outdoor toggle and all sensor fields',
      (tester) async {
    await pumpEntry(tester);
    expect(find.text('Outdoor'), findsOneWidget);
    expect(find.text('Indoor'), findsOneWidget);
    for (final label in [
      'PM2.5',
      'PM10',
      'Particles',
      'CO2',
      'HCHO',
      'Temp',
      'Humidity'
    ]) {
      expect(fieldByLabel(label), findsWidgets, reason: label);
    }
  });
}
