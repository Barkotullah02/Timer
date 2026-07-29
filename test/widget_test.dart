// Basic smoke test for the Multi Timer app.
//
// The original Flutter starter test referenced a counter widget that this
// project does not contain. This placeholder simply verifies the app boots
// and shows the "My Timers" list screen.

import 'package:flutter_test/flutter_test.dart';

import 'package:timer/main.dart';

void main() {
  testWidgets('App boots into the My Timers screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('My Timers'), findsOneWidget);
  });
}
