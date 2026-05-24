import 'dart:math';

/// What kind of reward a prize grants.
enum PrizeType { points, tokens, cosmetic }

/// A single prize outcome. No outcome is ever negative — the "no-loss" rule.
class PrizeReward {
  const PrizeReward({
    required this.type,
    required this.value,
    required this.label,
    required this.emoji,
  });

  final PrizeType type;

  /// For points/tokens this is the int amount (as num); for cosmetic it's the
  /// cosmetic id (String).
  final Object value;
  final String label;
  final String emoji;

  bool get isPositive {
    switch (type) {
      case PrizeType.points:
      case PrizeType.tokens:
        return (value as num) > 0;
      case PrizeType.cosmetic:
        return (value as String).isNotEmpty;
    }
  }

  int get intValue => (value as num).toInt();
}

/// A wheel segment = a reward plus a selection weight.
class WheelSegment {
  const WheelSegment({required this.reward, required this.weight});
  final PrizeReward reward;
  final int weight;

  String get label => reward.label;
  bool get isPositive => reward.isPositive;
}

const defaultJackpotLabel = 'ג׳קפוט!';

/// Default wheel config. Weights are tunable; the smallest reward is still
/// positive so the wheel can never "lose".
const defaultWheelSegments = <WheelSegment>[
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 5, label: '5 נקודות', emoji: '⭐'),
    weight: 30,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 15, label: '15 נקודות', emoji: '⭐'),
    weight: 24,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 40, label: '40 נקודות', emoji: '🌟'),
    weight: 14,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.tokens, value: 1, label: 'אסימון', emoji: '🎟️'),
    weight: 18,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.tokens, value: 3, label: '3 אסימונים', emoji: '🎟️'),
    weight: 8,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.cosmetic,
        value: 'frame_confetti',
        label: 'מסגרת קונפטי',
        emoji: '🖼️'),
    weight: 4,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points,
        value: 200,
        label: defaultJackpotLabel,
        emoji: '💎'),
    weight: 2,
  ),
];

/// Default scratch-card prize pool (each panel reveal draws from this).
const defaultScratchRewards = <WheelSegment>[
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 10, label: '10 נקודות', emoji: '⭐'),
    weight: 40,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 30, label: '30 נקודות', emoji: '🌟'),
    weight: 22,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.tokens, value: 1, label: 'אסימון', emoji: '🎟️'),
    weight: 28,
  ),
  WheelSegment(
    reward: PrizeReward(
        type: PrizeType.points, value: 100, label: '100 נקודות', emoji: '💎'),
    weight: 10,
  ),
];

PrizeReward _weightedPick(Random rng, List<WheelSegment> segments) {
  final total = segments.fold<int>(0, (s, seg) => s + seg.weight);
  var roll = rng.nextInt(total);
  for (final seg in segments) {
    if (roll < seg.weight) return seg.reward;
    roll -= seg.weight;
  }
  return segments.last.reward; // unreachable; safe fallback
}

/// Rolls the wheel; result is always positive (no-loss).
PrizeReward rollWheel([Random? rng]) =>
    _weightedPick(rng ?? Random(), defaultWheelSegments);

/// Rolls a scratch reward; result is always positive (no-loss).
PrizeReward rollScratch([Random? rng]) =>
    _weightedPick(rng ?? Random(), defaultScratchRewards);

/// Index of [reward] within [defaultWheelSegments] (for animating the wheel
/// to the winning slice). Returns 0 if not found.
int wheelSegmentIndex(PrizeReward reward) {
  for (var i = 0; i < defaultWheelSegments.length; i++) {
    if (identical(defaultWheelSegments[i].reward, reward)) return i;
  }
  return 0;
}
