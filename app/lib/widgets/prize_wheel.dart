import 'dart:math';
import 'package:flutter/material.dart';

import '../models/prize.dart';
import '../theme/app_theme.dart';

class PrizeWheel extends StatefulWidget {
  const PrizeWheel({
    super.key,
    required this.targetIndex,
    required this.spinning,
    required this.onSettled,
  });

  /// Index in [defaultWheelSegments] the wheel should land on.
  final int targetIndex;

  /// Drive a spin by flipping this to true.
  final bool spinning;
  final VoidCallback onSettled;

  @override
  State<PrizeWheel> createState() => _PrizeWheelState();
}

class _PrizeWheelState extends State<PrizeWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _angle = 0;

  static const _segColors = [
    AppPalette.gold,
    AppPalette.green,
    AppPalette.sky,
    AppPalette.pink,
    AppPalette.violet,
    AppPalette.goldDeep,
    AppPalette.gold,
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3600));
  }

  @override
  void didUpdateWidget(PrizeWheel old) {
    super.didUpdateWidget(old);
    if (widget.spinning && !old.spinning) _spin();
  }

  void _spin() {
    final n = defaultWheelSegments.length;
    final slice = 2 * pi / n;
    // Land the target slice's centre at the top pointer (-pi/2).
    final target = -pi / 2 - (widget.targetIndex * slice) - slice / 2;
    final base = _angle % (2 * pi);
    final end = target - base + 2 * pi * 5; // 5 full turns
    _ctrl.reset();
    final tween = Tween<double>(begin: 0, end: end)
        .chain(CurveTween(curve: Curves.easeOutQuart));
    final anim = tween.animate(_ctrl);
    anim.addListener(() => setState(() => _angle = base + anim.value));
    _ctrl.forward().whenComplete(() {
      widget.onSettled();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 300,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Transform.rotate(
              angle: _angle,
              child: CustomPaint(
                size: const Size(260, 260),
                painter: _WheelPainter(colors: _segColors),
              ),
            ),
          ),
          // Pointer at top.
          const Positioned(
            top: 0,
            child: Icon(Icons.arrow_drop_down, size: 48, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({required this.colors});
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final n = defaultWheelSegments.length;
    final slice = 2 * pi / n;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = size.width / 2;
    final textPainter = TextPainter(textDirection: TextDirection.rtl);

    for (var i = 0; i < n; i++) {
      final start = -pi / 2 + i * slice;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = colors[i % colors.length].withValues(alpha: 0.85);
      canvas.drawArc(rect, start, slice, true, paint);
      canvas.drawArc(
        rect,
        start,
        slice,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = AppPalette.bgDeep,
      );

      // Emoji label at slice mid-angle.
      final mid = start + slice / 2;
      final seg = defaultWheelSegments[i];
      textPainter.text = TextSpan(
          text: seg.reward.emoji, style: const TextStyle(fontSize: 22));
      textPainter.layout();
      final lx = center.dx + cos(mid) * radius * 0.62 - textPainter.width / 2;
      final ly = center.dy + sin(mid) * radius * 0.62 - textPainter.height / 2;
      textPainter.paint(canvas, Offset(lx, ly));
    }

    canvas.drawCircle(center, 18, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
