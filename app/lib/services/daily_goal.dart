// Pure rules for the daily-goal token loop. Kept out of the Firestore
// transaction so they can be unit-tested without a backend.

/// True when [justEarned] points are what pushed the running [earnedToday]
/// total from below [goal] to at-or-above it — i.e. the daily goal is met
/// exactly on this earn (so we award the daily-goal token exactly once).
bool crossedDailyGoal({
  required int earnedToday,
  required int justEarned,
  required int goal,
}) {
  if (goal <= 0) return false;
  final before = earnedToday;
  final after = earnedToday + justEarned;
  return before < goal && after >= goal;
}

/// Bonus tokens granted when the streak reaches a milestone day.
int streakMilestoneTokens(int streakDay) {
  switch (streakDay) {
    case 3:
      return 2;
    case 7:
      return 3;
    case 14:
      return 5;
    case 30:
      return 10;
    default:
      return 0;
  }
}
