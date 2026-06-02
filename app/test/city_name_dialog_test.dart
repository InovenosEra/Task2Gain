import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:task2play/widgets/city_name_dialog.dart';

void main() {
  // Regression: the rename dialog used to free its TextEditingController right
  // after `showDialog` returned — while the TextField was still animating out —
  // throwing "TextEditingController used after being disposed" and cascading
  // into an "_dependents.isEmpty" framework assertion (red screen on Save).
  testWidgets('save returns the new name without use-after-dispose',
      (tester) async {
    String? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCityNameDialog(
                  context,
                  initialName: 'עיר ישנה',
                  hint: 'שם העיר',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'עיר חדשה');
    await tester.tap(find.text('שמירה'));

    // Pump through the dialog's exit animation + element unmount — this is
    // exactly where the premature dispose used to blow up.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, 'עיר חדשה');
  });

  testWidgets('cancel returns null', (tester) async {
    String? result = 'sentinel';

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                result = await showCityNameDialog(
                  context,
                  initialName: 'עיר',
                  hint: 'שם העיר',
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ביטול'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNull);
  });
}
