import 'package:flutter_test/flutter_test.dart';

import 'package:task2gain/main.dart';
import 'package:task2gain/widgets/task2gain_logo.dart';

void main() {
  testWidgets('Splash screen renders logo + tagline', (tester) async {
    await tester.pumpWidget(const Task2GainApp());
    await tester.pump();

    // The brand is now drawn as a graphical logo, not literal title text.
    expect(find.byType(Task2GainLogo), findsOneWidget);
    expect(find.text('משפחה. משימות. פרסים.'), findsOneWidget);
  });
}
