import 'package:flutter_test/flutter_test.dart';

import 'package:task2pay/main.dart';

void main() {
  testWidgets('Splash screen renders Task2Pay title', (tester) async {
    await tester.pumpWidget(const Task2PayApp());
    await tester.pump();

    expect(find.text('Task2Pay'), findsOneWidget);
    expect(find.text('משפחה. משימות. פרסים.'), findsOneWidget);
  });
}
