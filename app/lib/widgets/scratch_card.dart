import 'package:flutter/material.dart';

import '../models/prize.dart';
import '../theme/app_theme.dart';
import 'scale_tap.dart';

class ScratchCard extends StatefulWidget {
  const ScratchCard({
    super.key,
    required this.reward,
    required this.onComplete,
  });

  /// The reward all three panels reveal (pre-rolled by the parent screen).
  final PrizeReward reward;
  final VoidCallback onComplete;

  @override
  State<ScratchCard> createState() => _ScratchCardState();
}

class _ScratchCardState extends State<ScratchCard> {
  final _revealed = [false, false, false];

  void _reveal(int i) {
    if (_revealed[i]) return;
    setState(() => _revealed[i] = true);
    if (_revealed.every((r) => r)) {
      Future.delayed(const Duration(milliseconds: 400), widget.onComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: ScaleTap(
              onTap: () => _reveal(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 84,
                height: 104,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: _revealed[i]
                        ? [AppPalette.gold, AppPalette.goldDeep]
                        : [AppPalette.surface, AppPalette.bgDeep],
                  ),
                  border: Border.all(
                    color: _revealed[i]
                        ? AppPalette.gold
                        : Colors.white.withValues(alpha: 0.15),
                    width: 2,
                  ),
                ),
                child: _revealed[i]
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(widget.reward.emoji,
                              style: const TextStyle(fontSize: 34)),
                          const SizedBox(height: 4),
                          Text(widget.reward.label,
                              textAlign: TextAlign.center,
                              style: bodyFont(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  color: AppPalette.bgDeep)),
                        ],
                      )
                    : const Text('❓', style: TextStyle(fontSize: 34)),
              ),
            ),
          ),
      ],
    );
  }
}
