import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _gold = Color(0xFFFFD166);
const _pink = Color(0xFFEF476F);
const _violet = Color(0xFF7B2CBF);

/// Vector logo for Task2Gain. Scales perfectly at any size.
class Task2GainLogo extends StatelessWidget {
  const Task2GainLogo({super.key, this.size = 120});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter()),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final radius = w * 0.26;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(radius),
    );

    canvas.drawRRect(
      rect.shift(Offset(0, h * 0.04)),
      Paint()
        ..color = _gold.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_gold, _pink, _violet],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(rect, bodyPaint);

    final sheenPath = Path()
      ..moveTo(w * 0.12, h * 0.18)
      ..quadraticBezierTo(w * 0.5, h * 0.0, w * 0.85, h * 0.12)
      ..quadraticBezierTo(w * 0.5, h * 0.32, w * 0.12, h * 0.5)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    canvas.drawCircle(
      Offset(w * 0.5, h * 0.55),
      w * 0.34,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: '2',
        style: GoogleFonts.heebo(
          fontSize: w * 0.78,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: w * 0.04,
              offset: Offset(0, w * 0.02),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final textOffset = Offset(
      (w - tp.width) / 2,
      h * 0.55 - tp.height / 2,
    );
    tp.paint(canvas, textOffset);

    _drawSparkle(canvas, Offset(w * 0.82, h * 0.18), w * 0.08, Colors.white);
    _drawSparkle(
      canvas,
      Offset(w * 0.16, h * 0.82),
      w * 0.05,
      Colors.white.withValues(alpha: 0.7),
    );
  }

  void _drawSparkle(Canvas canvas, Offset center, double size, Color color) {
    final path = Path();
    final cx = center.dx;
    final cy = center.dy;
    final long = size;
    final short = size * 0.25;
    path.moveTo(cx, cy - long);
    path.quadraticBezierTo(cx + short, cy - short, cx + long, cy);
    path.quadraticBezierTo(cx + short, cy + short, cx, cy + long);
    path.quadraticBezierTo(cx - short, cy + short, cx - long, cy);
    path.quadraticBezierTo(cx - short, cy - short, cx, cy - long);
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

