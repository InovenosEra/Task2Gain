import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const Task2PayApp());

const _bgDeep = Color(0xFF0F1030);
const _gold = Color(0xFFFFD166);
const _pink = Color(0xFFEF476F);
const _violet = Color(0xFF7B2CBF);

class Task2PayApp extends StatelessWidget {
  const Task2PayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    return MaterialApp(
      title: 'Task2Pay',
      debugShowCheckedModeBanner: false,
      locale: const Locale('he'),
      supportedLocales: const [Locale('he'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: base.copyWith(
        textTheme: GoogleFonts.heeboTextTheme(base.textTheme),
        colorScheme: const ColorScheme.dark(
          primary: _gold,
          secondary: Color(0xFF06D6A0),
          surface: Color(0xFF1A1B3A),
        ),
        scaffoldBackgroundColor: _bgDeep,
      ),
      home: const SplashScreen(),
    );
  }
}

/// Vector logo for Task2Pay. Scales perfectly at any size.
class Task2PayLogo extends StatelessWidget {
  const Task2PayLogo({super.key, this.size = 120});
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

    // Outer glow (soft) — drawn as a slightly larger blurred shadow via canvas.
    canvas.drawRRect(
      rect.shift(Offset(0, h * 0.04)),
      Paint()
        ..color = _gold.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16),
    );

    // Main gradient body
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [_gold, _pink, _violet],
        stops: [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRRect(rect, bodyPaint);

    // Inner highlight (top-left sheen)
    final sheenPath = Path()
      ..moveTo(w * 0.12, h * 0.18)
      ..quadraticBezierTo(w * 0.5, h * 0.0, w * 0.85, h * 0.12)
      ..quadraticBezierTo(w * 0.5, h * 0.32, w * 0.12, h * 0.5)
      ..close();
    canvas.drawPath(
      sheenPath,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );

    // Faint circular "coin" outline behind the "2"
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.55),
      w * 0.34,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.015,
    );

    // Big bold "2" using TextPainter so we can leverage Heebo at scale.
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

    // Top-right sparkle accent (4-pointed star).
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

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    // Wait for the first frame to render before starting the splash timer —
    // otherwise the cold-start delay eats the splash time and the user
    // never sees the logo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.forward();
      if (_navigationScheduled) return;
      _navigationScheduled = true;
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, _, _) => const WelcomeScreen(),
            transitionsBuilder: (_, animation, _, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1F1B5C), _bgDeep, Color(0xFF2A0B45)],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.scale(
                      scale: 0.7 + (_scale.value * 0.3),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Task2PayLogo(size: 160),
                    const SizedBox(height: 28),
                    Text(
                      'Task2Pay',
                      style: GoogleFonts.heebo(
                        fontSize: 44,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'משפחה. משימות. פרסים.',
                      style: GoogleFonts.heebo(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1F1B5C), _bgDeep, Color(0xFF2A0B45)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Center(child: Task2PayLogo(size: 120)),
                  const SizedBox(height: 24),
                  Text(
                    'Task2Pay',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.heebo(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'משפחה. משימות. פרסים.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.heebo(
                      fontSize: 18,
                      fontWeight: FontWeight.w400,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const _FeatureChip(
                      emoji: '⚡', text: 'משימות יומיות שהופכות לנקודות'),
                  const SizedBox(height: 10),
                  const _FeatureChip(
                      emoji: '💰', text: 'ארנק אמיתי — נקודות שהופכות לכסף'),
                  const SizedBox(height: 10),
                  const _FeatureChip(
                      emoji: '🏆', text: 'רמות, רצפים, ולוח מובילים משפחתי'),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {},
                    style: FilledButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _bgDeep,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Text(
                      'יאללה, מתחילים!',
                      style: GoogleFonts.heebo(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      'יש לי קוד הזמנה',
                      style: GoogleFonts.heebo(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.heebo(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
