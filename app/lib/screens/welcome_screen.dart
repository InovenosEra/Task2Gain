import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/city_sky.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import 'join_with_code_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enterController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _enterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: CitySky.skyTop,
        body: CitySkyBackground(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _reveal(0.0, 0.6, const Task2PlayWordmark(size: 40)),
                      const SizedBox(height: 4),
                      _reveal(
                        0.1,
                        0.7,
                        Text(
                          'משימות שמרגישות כמו משחק',
                          textAlign: TextAlign.center,
                          style: cityFont(
                            size: 14,
                            weight: FontWeight.w600,
                            color: const Color(0xFF5B3B86),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _reveal(
                        0.2,
                        0.9,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            _ClayCard(
                              icon: '⚡',
                              tint: Color(0xFFD6FBEF),
                              title: 'משימות יומיות',
                              sub: 'שהופכות לנקודות אמיתיות',
                            ),
                            SizedBox(width: 12),
                            _ClayCard(
                              icon: '💰',
                              tint: Color(0xFFFFF1D6),
                              title: 'ארנק אמיתי',
                              sub: 'המרת נקודות לכסף',
                            ),
                            SizedBox(width: 12),
                            _ClayCard(
                              icon: '🏆',
                              tint: Color(0xFFFFE0E8),
                              title: 'רמות ולוח מובילים',
                              sub: 'כל קווסט מקרב להישגים',
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      _reveal(
                        0.55,
                        1.0,
                        ScaleTap(
                          onTap: () =>
                              context.pushFadeUp((_) => const SignupScreen()),
                          child: const _GoldCta(label: 'יאללה, מתחילים!'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _reveal(
                        0.7,
                        1.0,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _LinkButton(
                              label: 'כבר יש לי חשבון',
                              onTap: () =>
                                  context.pushFadeUp((_) => const LoginScreen()),
                            ),
                            Container(
                              width: 1,
                              height: 13,
                              margin: const EdgeInsets.symmetric(horizontal: 6),
                              color: CitySky.wm.withValues(alpha: 0.3),
                            ),
                            _LinkButton(
                              label: 'יש לי קוד הזמנה',
                              onTap: () => context
                                  .pushFadeUp((_) => const JoinWithCodeScreen()),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reveal(double start, double end, Widget child) {
    final eased = CurvedAnimation(
      parent: _enterController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: eased,
      builder: (context, _) => Opacity(
        opacity: eased.value,
        child: Transform.translate(
          offset: Offset(0, (1 - eased.value) * 12),
          child: child,
        ),
      ),
    );
  }
}

/// A bright white "clay" feature card: soft rounded panel, tinted icon
/// squircle, dark text — pops against the sky.
class _ClayCard extends StatelessWidget {
  const _ClayCard({
    required this.icon,
    required this.tint,
    required this.title,
    required this.sub,
  });

  final String icon;
  final Color tint;
  final String title;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3A1063).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(icon, style: const TextStyle(fontSize: 21)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: cityFont(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: CitySky.ink,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: bodyFont(
                    size: 10.5,
                    color: CitySky.inkSoft,
                    height: 1.2,
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

/// Gold pill CTA in the city theme (Fredoka, dark-violet ink).
class _GoldCta extends StatelessWidget {
  const _GoldCta({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 56),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [CitySky.gold, CitySky.goldDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: CitySky.goldDeep.withValues(alpha: 0.55),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Text(
        label,
        style: cityFont(
          size: 20,
          weight: FontWeight.w700,
          color: const Color(0xFF3A1063),
        ),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: CitySky.wm,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: cityFont(
          size: 13,
          weight: FontWeight.w600,
          color: CitySky.wm,
        ),
      ),
    );
  }
}
