import 'package:flutter_test/flutter_test.dart';
import 'package:aq_mapping_app/main.dart';

void main() {
  testWidgets('App launches with home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AQMappingApp());
    expect(find.text('Air Quality Mapper'), findsOneWidget);
    expect(find.text('Add Measurement'), findsOneWidget);
    expect(find.text('View Map'), findsOneWidget);
    expect(find.text('Export Data'), findsOneWidget);
  });
}
