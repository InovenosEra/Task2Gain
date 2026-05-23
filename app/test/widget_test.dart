import 'package:flutter_test/flutter_test.dart';

import 'package:task2pay/main.dart';

void main() {
  testWidgets('Welcome screen renders Task2Pay title', (tester) async {
    await tester.pumpWidget(const Task2PayApp());
    await tester.pumpAndSettle();

    expect(find.text('Task2Pay'), findsOneWidget);
    expect(find.text('המשפחה. המשימה. הפרס.'), findsOneWidget);
    expect(find.text('יאללה, מתחילים!'), findsOneWidget);
  });
}
