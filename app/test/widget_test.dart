import 'package:flutter_test/flutter_test.dart';

import 'package:task2play/main.dart';
import 'package:task2play/widgets/task2play_logo.dart';

void main() {
  testWidgets('Splash screen renders logo + tagline', (tester) async {
    await tester.pumpWidget(const Task2PlayApp());
    await tester.pump();

    // The brand is now drawn as a graphical logo, not literal title text.
    expect(find.byType(Task2PlayLogo), findsOneWidget);
    expect(find.text('משפחה. משימות. פרסים.'), findsOneWidget);
  });
}
