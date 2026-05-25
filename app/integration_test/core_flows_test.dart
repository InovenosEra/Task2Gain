// Verification harness for Task2Play core flows. Launches the real app and
// drives navigation through every primary screen, asserting each renders.
// Read-only: it never submits forms, so it writes nothing to Firebase.
//
// Run:  flutter test integration_test/core_flows_test.dart -d <simulator-udid>
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:task2play/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Pumps in small steps until [finder] matches, or fails after [timeout].
  /// pumpAndSettle is unusable here — the splash timer, gradient animations,
  /// and Firestore streams never quiesce.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 20),
    String? label,
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 250));
      if (finder.evaluate().isNotEmpty) {
        // Let the frame visually settle for the screenshot loop.
        await tester.pump(const Duration(milliseconds: 600));
        debugPrint('STEP_OK: ${label ?? finder.toString()}');
        return;
      }
    }
    debugPrint('STEP_FAIL: ${label ?? finder.toString()}');
    fail('Timed out waiting for: ${label ?? finder.toString()}');
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    expect(f, findsWidgets, reason: 'no widget with text "$text" to tap');
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ScreenChrome's back control is an RTL forward-arrow icon, not a
  // Material/Cupertino BackButton, so pageBack() can't find it.
  Future<void> goBack(WidgetTester tester) async {
    final f = find.byIcon(Icons.arrow_forward);
    expect(f, findsWidgets, reason: 'no ScreenChrome back arrow on screen');
    await tester.tap(f.first);
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('core flows render end-to-end', (tester) async {
    await app.main();

    // 1. Splash resolves to the logged-in home tab.
    await pumpUntil(tester, find.text('משימות פתוחות'),
        label: 'home: open-quests heading');

    // 2. Shop tab.
    await tapText(tester, 'חנות');
    await pumpUntil(tester, find.text('חנות פרסים 🎁'), label: 'shop tab');

    // 2b. Prize Machine tab.
    await tapText(tester, 'פרסים');
    await pumpUntil(tester, find.text('מכונת הפרסים 🎰'),
        label: 'prize machine tab');
    await pumpUntil(tester, find.text('כרטיס גירוד'),
        label: 'prize machine: scratch section');

    // 3. Family / leaderboard tab.
    await tapText(tester, 'משפחה');
    await pumpUntil(tester, find.text('לוח המובילים 🏆'), label: 'family tab');

    // 4. Profile tab.
    await tapText(tester, 'פרופיל');
    await pumpUntil(tester, find.text('ההישגים שלי'), label: 'profile tab');

    // 5. Admin tab (this account is admin → ניהול is present).
    await tapText(tester, 'ניהול');
    await pumpUntil(tester, find.text('הזמן בן משפחה'), label: 'admin tab');

    // 6. Admin → create-quest form renders. The trigger is the "+ חדש"
    // button; "קווסט חדש" is the screen title that appears after.
    await tapText(tester, 'חדש');
    await pumpUntil(tester, find.text('צור קווסט'),
        label: 'create-quest form');
    // Back out without submitting (no Firebase write).
    await goBack(tester);
    await pumpUntil(tester, find.text('הזמן בן משפחה'),
        label: 'back to admin');

    // 7. Manage-rewards screen renders.
    await tapText(tester, 'ניהול פרסים');
    await pumpUntil(tester, find.byIcon(Icons.arrow_forward),
        label: 'manage-rewards');
    await goBack(tester);
    await pumpUntil(tester, find.text('הזמן בן משפחה'),
        label: 'back to admin from rewards');

    // 8. Home → quest detail renders, then back.
    await tapText(tester, 'משימות');
    await pumpUntil(tester, find.text('משימות פתוחות'), label: 'back home');
    await tapText(tester, 'להוריד זבל');
    await pumpUntil(tester, find.text('קושי'), label: 'quest detail');
    await goBack(tester);
    await pumpUntil(tester, find.text('משימות פתוחות'),
        label: 'back home from quest');

    // 9. Home → convert-points screen renders, then back.
    await tapText(tester, 'המר נקודות');
    await pumpUntil(tester, find.text('המר עכשיו'), label: 'convert points');
    await goBack(tester);
    await pumpUntil(tester, find.text('משימות פתוחות'),
        label: 'back home from convert');

    debugPrint('ALL_FLOWS_RENDERED');
  });
}
