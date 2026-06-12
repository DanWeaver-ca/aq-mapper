import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aq_mapping_app/main.dart';

void main() {
  testWidgets('App launches with home screen and session chip',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'session_group_name': 'Maple Group',
      'session_device_id': 'UTSC-AQMS-07',
      'session_temp_unit': 'C',
    });

    await tester.pumpWidget(const AQMappingApp());
    await tester.pumpAndSettle();

    expect(find.text('Air Quality Mapper'), findsOneWidget);
    expect(find.text('Add Measurement'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('View Map'), findsOneWidget);
    expect(find.text('Export / Import Data'), findsOneWidget);
    expect(find.text('Maple Group · UTSC-AQMS-07'), findsOneWidget);
  });

  testWidgets('home screen fits landscape without overflow',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'session_group_name': 'Maple Group',
      'session_device_id': 'UTSC-AQMS-07',
      'session_temp_unit': 'C',
    });
    // iPhone-ish landscape viewport.
    await tester.binding.setSurfaceSize(const Size(844, 390));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const AQMappingApp());
    await tester.pumpAndSettle();

    // An overflow would surface as a FlutterError exception here.
    expect(tester.takeException(), isNull);
    expect(find.text('Air Quality Mapper'), findsOneWidget);
    // The 2x2 landscape grid must show all four destinations on screen
    // without scrolling.
    for (final label in [
      'Add Measurement',
      'History',
      'View Map',
      'Export / Import Data'
    ]) {
      expect(
        tester.getRect(find.text(label)).bottom,
        lessThanOrEqualTo(390),
        reason: '$label should be fully visible in landscape',
      );
    }
  });

  testWidgets('unconfigured session forces setup screen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AQMappingApp());
    await tester.pumpAndSettle();

    expect(find.text('Session Setup'), findsOneWidget);
    expect(find.text('Group name'), findsOneWidget);
  });
}
