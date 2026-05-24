import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular progress ring for the daily points goal.
class DailyGoalRing extends StatelessWidget {
  const DailyGoalRing({
    super.key,
    required this.earnedToday,
    required this.goal,
    this.size = 64,
  });

  final int earnedToday;
  final int goal;
  final double size;

  @override
  Widget build(BuildContext context) {
    final progress = goal <= 0 ? 0.0 : (earnedToday / goal).clamp(0.0, 1.0);
    final met = earnedToday >= goal && goal > 0;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                  met ? AppPalette.green : AppPalette.gold),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(met ? '✅' : '🎯', style: const TextStyle(fontSize: 16)),
              Text('$earnedToday/$goal',
                  style: displayFont(size: 11, weight: FontWeight.w900)),
            ],
          ),
        ],
      ),
    );
  }
}
