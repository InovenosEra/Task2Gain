import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _bgDeep = Color(0xFF0F1030);
const _gold = Color(0xFFFFD166);
const _pink = Color(0xFFEF476F);
const _violet = Color(0xFF7B2CBF);
const _green = Color(0xFF06D6A0);

Future<void> showLevelUpOverlay(BuildContext context, int newLevel) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, _, _) => _LevelUpDialog(newLevel: newLevel),
    transitionBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      );
    },
  );
}

class _LevelUpDialog extends StatefulWidget {
  const _LevelUpDialog({required this.newLevel});
  final int newLevel;

  @override
  State<_LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<_LevelUpDialog>
    with TickerProviderStateMixin {
  late final AnimationController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _confettiController,
            builder: (_, _) => CustomPaint(
              size: const Size(340, 540),
              painter: _ConfettiPainter(progress: _confettiController.value),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            decoration: BoxDecoration(
              color: _bgDeep,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: _gold, width: 2),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: 0.3),
                  blurRadius: 30,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎊', style: TextStyle(fontSize: 76)),
                const SizedBox(height: 12),
                Text(
                  'עליית רמה!',
                  style: GoogleFonts.heebo(
                    color: _gold,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_gold, _pink, _violet],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'רמה ${widget.newLevel}',
                    style: GoogleFonts.heebo(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'כל הכבוד! 💪\nממשיכים להתקדם',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.heebo(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _bgDeep,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'אחלה!',
                    style: GoogleFonts.heebo(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress})
      : _rand = Random(42); // stable seed → same confetti per dialog

  final double progress;
  final Random _rand;

  static const _colors = [_gold, _pink, _violet, _green, Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    const count = 60;
    for (var i = 0; i < count; i++) {
      final startX = _rand.nextDouble() * size.width;
      final endY = _rand.nextDouble() * size.height;
      final drift = (_rand.nextDouble() - 0.5) * 80;
      final delay = _rand.nextDouble() * 0.3;
      final pieceProgress = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      final t = Curves.easeOutCubic.transform(pieceProgress);
      final x = startX + drift * t;
      final y = -20 + (endY + 50) * t;
      final rotation = _rand.nextDouble() * 6.28 + progress * 6;
      final color = _colors[i % _colors.length];

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      final width = 6.0 + _rand.nextDouble() * 4;
      final height = 10.0 + _rand.nextDouble() * 6;
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: width, height: height),
        Paint()..color = color.withValues(alpha: 1 - t * 0.4),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
