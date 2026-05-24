import 'package:flutter_test/flutter_test.dart';
import 'package:task2gain/services/daily_goal.dart';

void main() {
  group('crossedDailyGoal', () {
    test('true only when this earn pushes today from below to at-or-above goal', () {
      expect(crossedDailyGoal(earnedToday: 40, justEarned: 20, goal: 50), isTrue);
    });
    test('false when already at/above goal before this earn', () {
      expect(crossedDailyGoal(earnedToday: 60, justEarned: 20, goal: 50), isFalse);
    });
    test('goal of zero never counts as crossed', () {
      expect(crossedDailyGoal(earnedToday: 0, justEarned: 100, goal: 0), isFalse);
    });
    test('false when still below goal after this earn', () {
      expect(crossedDailyGoal(earnedToday: 10, justEarned: 20, goal: 50), isFalse);
    });
    test('exact hit counts', () {
      expect(crossedDailyGoal(earnedToday: 30, justEarned: 20, goal: 50), isTrue);
    });
  });

  group('streakMilestoneTokens', () {
    test('milestones grant bonus tokens', () {
      expect(streakMilestoneTokens(3), 2);
      expect(streakMilestoneTokens(7), 3);
      expect(streakMilestoneTokens(14), 5);
      expect(streakMilestoneTokens(30), 10);
    });
    test('non-milestone days grant 0', () {
      expect(streakMilestoneTokens(1), 0);
      expect(streakMilestoneTokens(5), 0);
      expect(streakMilestoneTokens(0), 0);
    });
  });
}
