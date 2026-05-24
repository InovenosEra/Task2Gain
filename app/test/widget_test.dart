import 'package:flutter_test/flutter_test.dart';

import 'package:task2gain/main.dart';

void main() {
  testWidgets('Splash screen renders Task2Gain title', (tester) async {
    await tester.pumpWidget(const Task2GainApp());
    await tester.pump();

    expect(find.text('Task2Gain'), findsOneWidget);
    expect(find.text('משפחה. משימות. פרסים.'), findsOneWidget);
  });
}
