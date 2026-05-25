import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:task2play/models/prize.dart';

void main() {
  group('wheel no-loss invariant', () {
    test('every defined segment is a positive reward', () {
      for (final seg in defaultWheelSegments) {
        expect(seg.isPositive, isTrue, reason: '${seg.label} must be positive');
      }
    });

    test('1000 weighted rolls always yield a positive reward', () {
      final rng = Random(7);
      for (var i = 0; i < 1000; i++) {
        final result = rollWheel(rng);
        expect(result.isPositive, isTrue);
      }
    });

    test('rare jackpot is actually rare (< 5% over 2000 rolls)', () {
      final rng = Random(11);
      var jackpots = 0;
      for (var i = 0; i < 2000; i++) {
        if (rollWheel(rng).label == defaultJackpotLabel) jackpots++;
      }
      expect(jackpots / 2000, lessThan(0.05));
    });
  });

  group('scratch no-loss invariant', () {
    test('every scratch result is a positive reward', () {
      final rng = Random(3);
      for (var i = 0; i < 500; i++) {
        expect(rollScratch(rng).isPositive, isTrue);
      }
    });
  });
}
