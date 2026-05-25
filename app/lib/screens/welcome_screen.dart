import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_background.dart';
import '../widgets/task2play_logo.dart';
import 'join_with_code_screen.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterController;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _enterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _enterController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.bgDeep,
        body: ScreenBackground(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: _FloatingLogo(controller: _floatController),
                  ),
                  const SizedBox(height: 22),
                  _Reveal(
                    controller: _enterController,
                    interval: const Interval(0.0, 0.6,
                        curve: Curves.easeOutCubic),
                    child: GradientText(
                      'Task2Play',
                      style: displayFont(
                        size: 48,
                        weight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                      colors: AppPalette.heroGrad,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _Reveal(
                    controller: _enterController,
                    interval: const Interval(0.1, 0.7,
                        curve: Curves.easeOutCubic),
                    child: Text(
                      'משימות שמרגישות כמו משחק',
                      textAlign: TextAlign.center,
                      style: bodyFont(
                        size: 15,
                        color: Colors.white60,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  _StaggeredFeature(
                    controller: _enterController,
                    delay: 0.2,
                    icon: '⚡',
                    title: 'משימות יומיות',
                    subtitle: 'שהופכות לנקודות אמיתיות',
                    tint: AppPalette.green,
                  ),
                  const SizedBox(height: 10),
                  _StaggeredFeature(
                    controller: _enterController,
                    delay: 0.32,
                    icon: '💰',
                    title: 'ארנק אמיתי',
                    subtitle: 'המרת נקודות לכסף שאפשר להשתמש בו',
                    tint: AppPalette.gold,
                  ),
                  const SizedBox(height: 10),
                  _StaggeredFeature(
                    controller: _enterController,
                    delay: 0.44,
                    icon: '🏆',
                    title: 'רמות, רצפים, לוח מובילים',
                    subtitle: 'כל קווסט מקרב אתכם להישגים חדשים',
                    tint: AppPalette.pink,
                  ),
                  const Spacer(),
                  _Reveal(
                    controller: _enterController,
                    interval: const Interval(0.55, 1.0,
                        curve: Curves.easeOutCubic),
                    child: ScaleTap(
                      onTap: () => context
                          .pushFadeUp((_) => const SignupScreen()),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: const LinearGradient(
                            colors: [
                              AppPalette.gold,
                              AppPalette.goldDeep,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.gold
                                  .withValues(alpha: 0.5),
                              blurRadius: 26,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'יאללה, מתחילים!',
                            style: displayFont(
                              size: 20,
                              weight: FontWeight.w900,
                              color: AppPalette.bgDeep,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Reveal(
                    controller: _enterController,
                    interval: const Interval(0.7, 1.0,
                        curve: Curves.easeOutCubic),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _LinkButton(
                          label: 'כבר יש לי חשבון',
                          onTap: () => context.pushFadeUp(
                              (_) => const LoginScreen()),
                        ),
                        Container(
                          width: 1,
                          height: 14,
                          color: Colors.white24,
                        ),
                        _LinkButton(
                          label: 'יש לי קוד הזמנה',
                          onTap: () => context.pushFadeUp(
                              (_) => const JoinWithCodeScreen()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Wraps a child in a fade + slide-up animation tied to a parent controller
/// at the given interval.
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.controller,
    required this.interval,
    required this.child,
  });

  final AnimationController controller;
  final Interval interval;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = CurvedAnimation(parent: controller, curve: interval);
    return AnimatedBuilder(
      animation: eased,
      builder: (context, _) {
        return Opacity(
          opacity: eased.value,
          child: Transform.translate(
            offset: Offset(0, (1 - eased.value) * 12),
            child: child,
          ),
        );
      },
    );
  }
}

class _FloatingLogo extends StatelessWidget {
  const _FloatingLogo({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(controller.value);
        final dy = -6 + (-6 * t);
        return Transform.translate(
          offset: Offset(0, dy),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppPalette.gold.withValues(alpha: 0.28),
                      AppPalette.gold.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              const Task2PlayLogo(size: 140),
            ],
          ),
        );
      },
    );
  }
}

class _StaggeredFeature extends StatelessWidget {
  const _StaggeredFeature({
    required this.controller,
    required this.delay,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
  });

  final AnimationController controller;
  final double delay;
  final String icon;
  final String title;
  final String subtitle;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return _Reveal(
      controller: controller,
      interval: Interval(delay, (delay + 0.5).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: tint.withValues(alpha: 0.4)),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: displayFont(size: 15, weight: FontWeight.w800),
                  ),
                  Text(
                    subtitle,
                    style: bodyFont(size: 12, color: Colors.white60),
                  ),
                ],
              ),
            ),
          ],
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
        foregroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      child: Text(
        label,
        style: bodyFont(
          size: 13,
          color: Colors.white70,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
