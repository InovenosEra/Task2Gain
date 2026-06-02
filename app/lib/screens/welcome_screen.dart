import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/page_routes.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_background.dart';
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
        backgroundColor: AppPalette.bgDeep,
        body: ScreenBackground(
          child: SafeArea(
            // Everything lives in one column, centred both axes. It only
            // scrolls if the content can't fit the (short) landscape height.
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 8),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight - 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _wordmark(),
                            const SizedBox(height: 6),
                            _tagline(),
                            const SizedBox(height: 12),
                            ..._features(),
                            const SizedBox(height: 12),
                            _cta(context),
                            const SizedBox(height: 6),
                            _links(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _wordmark() => _Reveal(
        controller: _enterController,
        interval: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
        child: GradientText(
          'Task2Play',
          style: displayFont(size: 29, weight: FontWeight.w900,
              letterSpacing: -1),
          colors: AppPalette.heroGrad,
          textAlign: TextAlign.center,
        ),
      );

  Widget _tagline() => _Reveal(
        controller: _enterController,
        interval: const Interval(0.1, 0.7, curve: Curves.easeOutCubic),
        child: Text(
          'משימות שמרגישות כמו משחק',
          textAlign: TextAlign.center,
          style: bodyFont(size: 15, color: Colors.white60,
              weight: FontWeight.w500),
        ),
      );

  List<Widget> _features() => [
        _StaggeredFeature(
          controller: _enterController,
          delay: 0.2,
          icon: '⚡',
          title: 'משימות יומיות',
          subtitle: 'שהופכות לנקודות אמיתיות',
          tint: AppPalette.green,
        ),
        const SizedBox(height: 6),
        _StaggeredFeature(
          controller: _enterController,
          delay: 0.32,
          icon: '💰',
          title: 'ארנק אמיתי',
          subtitle: 'המרת נקודות לכסף שאפשר להשתמש בו',
          tint: AppPalette.gold,
        ),
        const SizedBox(height: 6),
        _StaggeredFeature(
          controller: _enterController,
          delay: 0.44,
          icon: '🏆',
          title: 'רמות, רצפים, לוח מובילים',
          subtitle: 'כל קווסט מקרב אתכם להישגים חדשים',
          tint: AppPalette.pink,
        ),
      ];

  Widget _cta(BuildContext context) => _Reveal(
        controller: _enterController,
        interval: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
        child: ScaleTap(
          onTap: () => context.pushFadeUp((_) => const SignupScreen()),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [AppPalette.gold, AppPalette.goldDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppPalette.gold.withValues(alpha: 0.5),
                  blurRadius: 26,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Center(
              child: Text(
                'יאללה, מתחילים!',
                style: displayFont(size: 20, weight: FontWeight.w900,
                    color: AppPalette.bgDeep),
              ),
            ),
          ),
        ),
      );

  Widget _links(BuildContext context) => _Reveal(
        controller: _enterController,
        interval: const Interval(0.7, 1.0, curve: Curves.easeOutCubic),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _LinkButton(
              label: 'כבר יש לי חשבון',
              onTap: () => context.pushFadeUp((_) => const LoginScreen()),
            ),
            Container(width: 1, height: 14, color: Colors.white24),
            _LinkButton(
              label: 'יש לי קוד הזמנה',
              onTap: () =>
                  context.pushFadeUp((_) => const JoinWithCodeScreen()),
            ),
          ],
        ),
      );
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: tint.withValues(alpha: 0.4)),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 11),
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
