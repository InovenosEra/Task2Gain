import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _gold = Color(0xFFFFD166);
const _pink = Color(0xFFEF476F);
const _violet = Color(0xFF7B2CBF);

/// Vector logo for Task2Gain — an "achievement emblem": the wordmark
/// TASK · 2 · GAIN reads as one stamped badge, the words engraved between
/// hairline rules and evenly spaced around the hero numeral. Scales crisply
/// at any size.
class Task2GainLogo extends StatelessWidget {
  const Task2GainLogo({super.key, this.size = 120, this.iconMode = false});
  final double size;

  /// When true the badge fills the square edge-to-edge with no drop shadow,
  /// so it can be exported as a platform app icon (the OS applies its own
  /// rounded-corner mask).
  final bool iconMode;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(iconMode: iconMode)),
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({this.iconMode = false});

  final bool iconMode;

  // Vertical centres (as fractions of height) — symmetric around 0.5 so the
  // three elements are evenly spaced.
  static const double _yTask = 0.155;
  static const double _yTwo = 0.5;
  static const double _yGain = 0.845;

  // Heebo cap-height ≈ 0.70 of font size; used to centre glyphs visually.
  static const double _capRatio = 0.70;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Edge-to-edge for an app icon (OS masks corners); rounded badge otherwise.
    final radius = iconMode ? 0.0 : w * 0.26;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      Radius.circular(radius),
    );

    // Soft drop shadow — skipped in icon mode (would leave empty corners).
    if (!iconMode) {
      canvas.drawRRect(
        rect.shift(Offset(0, h * 0.04)),
        Paint()
          ..color = _gold.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
      );
    }

    // Gradient body.
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_gold, _pink, _violet],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(rect, bodyPaint);

    // Glossy sheen across the top.
    final sheenPath = Path()
      ..moveTo(w * 0.12, h * 0.20)
      ..quadraticBezierTo(w * 0.5, h * 0.0, w * 0.88, h * 0.16)
      ..quadraticBezierTo(w * 0.5, h * 0.34, w * 0.12, h * 0.50)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()..color = Colors.white.withValues(alpha: 0.13),
    );

    // Hero numeral.
    _paintGlyph(
      canvas,
      text: '2',
      fontSize: w * 0.60,
      weight: FontWeight.w900,
      cx: w * 0.5,
      yc: h * _yTwo,
      letterSpacing: 0,
      shadow: true,
    );

    // Engraved wordmark, framed by hairline rules.
    _paintFramedLabel(canvas, size, 'TASK', yc: h * _yTask);
    _paintFramedLabel(canvas, size, 'GAIN', yc: h * _yGain);
  }

  /// Paints [text] horizontally centred on [cx] with its glyph visually
  /// centred on [yc].
  void _paintGlyph(
    Canvas canvas, {
    required String text,
    required double fontSize,
    required FontWeight weight,
    required double cx,
    required double yc,
    required double letterSpacing,
    bool shadow = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.heebo(
          fontSize: fontSize,
          fontWeight: weight,
          color: Colors.white,
          letterSpacing: letterSpacing,
          height: 1.0,
          shadows: shadow
              ? [
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.26),
                    blurRadius: fontSize * 0.06,
                    offset: Offset(0, fontSize * 0.03),
                  ),
                ]
              : null,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final capHeight = fontSize * _capRatio;
    final dy = yc - (baseline - capHeight / 2);
    // Subtract the trailing letter-spacing so the text optically centres.
    final dx = cx - (tp.width - letterSpacing) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  void _paintFramedLabel(
    Canvas canvas,
    Size size,
    String text, {
    required double yc,
  }) {
    final w = size.width;
    final fontSize = w * 0.105;
    final letterSpacing = w * 0.022;

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: GoogleFonts.heebo(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          color: Colors.white.withValues(alpha: 0.96),
          letterSpacing: letterSpacing,
          height: 1.0,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: w * 0.025,
              offset: Offset(0, w * 0.008),
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textWidth = tp.width - letterSpacing;
    final baseline = tp.computeDistanceToActualBaseline(TextBaseline.alphabetic);
    final capHeight = fontSize * _capRatio;
    final dy = yc - (baseline - capHeight / 2);
    final dx = w * 0.5 - textWidth / 2;
    tp.paint(canvas, Offset(dx, dy));

    // Flanking hairline rules, centred on the glyph centre line.
    final rulePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = w * 0.012
      ..strokeCap = StrokeCap.round;
    final ruleLen = w * 0.11;
    final gap = w * 0.05;
    final leftEnd = dx - gap;
    canvas.drawLine(
        Offset(leftEnd - ruleLen, yc), Offset(leftEnd, yc), rulePaint);
    final rightStart = dx + textWidth + gap;
    canvas.drawLine(
        Offset(rightStart, yc), Offset(rightStart + ruleLen, yc), rulePaint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) =>
      oldDelegate.iconMode != iconMode;
}
