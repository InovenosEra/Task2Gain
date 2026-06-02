import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The "Little City" daylight theme — a sunny sky world (the same sky the game
/// board uses) used as the backdrop for the welcome + auth screens. Light,
/// warm, and game-first. Palette + helpers live here so every onboarding
/// screen stays in sync.
class CitySky {
  const CitySky._();

  // Sky gradient (top -> bottom), mirrors city_game.dart's _drawSky world.
  static const skyTop = Color(0xFF8ED7F6);
  static const skyMid = Color(0xFFBFE3F0);
  static const skyWarm = Color(0xFFFFE2A8);
  static const skyBottom = Color(0xFFFFC97A);

  // Royal wordmark colours (chosen to stay bold on the light sky).
  static const wm = Color(0xFF4B2A8A); // violet word
  static const accent = Color(0xFFEF476F); // pink "2"

  // Ink for content on light panels/cards.
  static const ink = Color(0xFF2A2D43);
  static const inkSoft = Color(0xFF8A8FA6);

  // Faint skyline.
  static const building = Color(0xFF7B2CBF);
  static const buildingDeep = Color(0xFF3A0F63);

  // Light form surfaces.
  static const panel = Colors.white;
  static const fieldFill = Color(0xFFF2F3F8);
  static const fieldBorder = Color(0xFFE2E4EE);
  static const focus = Color(0xFF7B2CBF);

  // Gold CTA (shared with the rest of the brand).
  static const gold = Color(0xFFFFD166);
  static const goldDeep = Color(0xFFFFA94D);
}

/// Fredoka — the rounded, chunky display face used for the wordmark, titles and
/// CTAs in the city theme.
TextStyle cityFont({
  double size = 16,
  FontWeight weight = FontWeight.w600,
  Color color = CitySky.wm,
  double? height,
  double? letterSpacing,
}) {
  return GoogleFonts.fredoka(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );
}

/// The "Task2Play" wordmark in the Sticker-Pop style (Fredoka, layered 3D
/// shadow), recoloured Royal so it reads on the bright sky: violet word, pink
/// "2", soft drop + white top highlight.
class Task2PlayWordmark extends StatelessWidget {
  const Task2PlayWordmark({super.key, this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) {
    const violetShadows = [
      Shadow(offset: Offset(0, 2.5), color: Color(0xFFC9B3E8)),
      Shadow(offset: Offset(0, 6), blurRadius: 9, color: Color(0x2E281446)),
      Shadow(offset: Offset(0, 1), color: Color(0x80FFFFFF)),
    ];
    const pinkShadows = [
      Shadow(offset: Offset(0, 2.5), color: Color(0xFFF5B6C6)),
      Shadow(offset: Offset(0, 6), blurRadius: 9, color: Color(0x2E281446)),
      Shadow(offset: Offset(0, 1), color: Color(0x80FFFFFF)),
    ];
    final base = GoogleFonts.fredoka(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: CitySky.wm,
      shadows: violetShadows,
    );
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'Task'),
          TextSpan(
            text: '2',
            style: base.copyWith(color: CitySky.accent, shadows: pinkShadows),
          ),
          const TextSpan(text: 'Play'),
        ],
        style: base,
      ),
      textDirection: TextDirection.ltr,
    );
  }
}

/// Full-bleed city-sky backdrop. Paints the sky gradient, a warm sun glow,
/// drifting clouds, and a faint skyline behind [child].
class CitySkyBackground extends StatelessWidget {
  const CitySkyBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CitySkyPainter(),
      isComplex: true,
      child: SizedBox.expand(child: child),
    );
  }
}

/// White rounded panel that holds a form on top of the city sky. Matches the
/// welcome screen's clay-card surface so onboarding feels like one world.
class CityCard extends StatelessWidget {
  const CityCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A1063).withValues(alpha: 0.26),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Back chevron tinted for the bright sky (RTL: arrow points to the start).
class CityBackButton extends StatelessWidget {
  const CityBackButton({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.arrow_forward, color: CitySky.wm),
    );
  }
}

/// Gold pill CTA in the city theme (Fredoka, dark-violet ink). Shared by the
/// welcome CTA and the form submit buttons.
class CityButton extends StatelessWidget {
  const CityButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: enabled
                ? const [CitySky.gold, CitySky.goldDeep]
                : [
                    CitySky.gold.withValues(alpha: 0.4),
                    CitySky.goldDeep.withValues(alpha: 0.4),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: CitySky.goldDeep.withValues(alpha: 0.5),
                    blurRadius: 18,
                    offset: const Offset(0, 9),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Color(0xFF3A1063),
                  ),
                )
              : Text(
                  label,
                  style: cityFont(
                    size: 18,
                    weight: FontWeight.w700,
                    color: const Color(0xFF3A1063),
                  ),
                ),
        ),
      ),
    );
  }
}

class _CitySkyPainter extends CustomPainter {
  // Deterministic building heights so the skyline is stable across repaints.
  static const _heights = <double>[
    58, 86, 46, 104, 70, 92, 52, 80, 64, 98, 48, 74, 60, 88,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // 1. Sky gradient.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 0),
          Offset(0, h),
          const [
            CitySky.skyTop,
            CitySky.skyMid,
            CitySky.skyWarm,
            CitySky.skyBottom,
          ],
          const [0.0, 0.36, 0.76, 1.0],
        ),
    );

    // 2. Warm sun glow, upper-left (same light source as the game buildings).
    final sun = Offset(w * 0.13, h * 0.05);
    final sr = h * 0.62;
    canvas.drawCircle(
      sun,
      sr,
      Paint()
        ..shader = ui.Gradient.radial(
          sun,
          sr,
          const [Color(0xCCFFF4CE), Color(0x00FFF4CE)],
        ),
    );

    // 3. Clouds.
    _cloud(canvas, Offset(w * 0.74, h * 0.16), 1.0);
    _cloud(canvas, Offset(w * 0.24, h * 0.26), 0.7);

    // 4. Faint skyline along the bottom.
    _skyline(canvas, size);

    // 5. Warm haze fading the skyline into the horizon.
    final hazeH = h * 0.42;
    canvas.drawRect(
      Rect.fromLTWH(0, h - hazeH, w, hazeH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, h - hazeH),
          Offset(0, h),
          const [Color(0x00FFE2A8), Color(0xD9FBDF9E), Color(0xF2FFC97A)],
          const [0.0, 0.55, 1.0],
        ),
    );
  }

  void _cloud(Canvas canvas, Offset o, double s) {
    final paint = Paint()..color = const Color(0xEAFFFFFF);
    void puff(double dx, double dy, double r) =>
        canvas.drawCircle(Offset(o.dx + dx * s, o.dy + dy * s), r * s, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(o.dx, o.dy + 8 * s), width: 60 * s, height: 16 * s),
        Radius.circular(10 * s),
      ),
      paint,
    );
    puff(0, 0, 17);
    puff(20, 5, 13);
    puff(-20, 6, 12);
    puff(9, -9, 13);
  }

  void _skyline(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    const bw = 34.0, gap = 9.0;
    final unit = bw + gap;
    final count = (w / unit).ceil() + 1;
    final totalW = count * unit - gap;
    var x = (w - totalW) / 2;

    final windowPaint = Paint()..color = const Color(0x3DFFE6BF);
    for (var i = 0; i < count; i++) {
      final bh = _heights[i % _heights.length];
      final top = h - bh;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(x, top, bw, bh),
          topLeft: const Radius.circular(7),
          topRight: const Radius.circular(7),
        ),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(x, top),
            Offset(x, h),
            const [Color(0x527B2CBF), Color(0x423A0F63)],
          ),
      );
      final rows = (bh / 22).floor();
      for (var r = 0; r < rows; r++) {
        for (var c = 0; c < 2; c++) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x + 8 + c * 16, top + 10 + r * 18.0, 6, 6),
              const Radius.circular(1.5),
            ),
            windowPaint,
          );
        }
      }
      x += unit;
    }
  }

  @override
  bool shouldRepaint(covariant _CitySkyPainter oldDelegate) => false;
}
