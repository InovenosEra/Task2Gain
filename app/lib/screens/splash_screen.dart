import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/gradient_text.dart';
import '../widgets/screen_background.dart';
import '../widgets/task2gain_logo.dart';
import 'main_navigation.dart';
import 'welcome_screen.dart';

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
  Timer? _navigationTimer;

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
      if (!mounted) return;
      _controller.forward();
      _navigationTimer ??= Timer(const Duration(milliseconds: 2500), () {
        if (!mounted) return;
        final isLoggedIn = FirebaseAuth.instance.currentUser != null;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, _, _) =>
                isLoggedIn
                    ? const MainNavigation()
                    : const WelcomeScreen(),
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
    _navigationTimer?.cancel();
    _controller.dispose();
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
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppPalette.gold.withValues(alpha: 0.3),
                                AppPalette.gold.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                        const Task2GainLogo(size: 160),
                      ],
                    ),
                    // Pull the tagline up into the logo's glow so it reads as
                    // part of the mark, and paint it in the logo gradient.
                    Transform.translate(
                      offset: const Offset(0, -24),
                      child: GradientText(
                        'משפחה. משימות. פרסים.',
                        textAlign: TextAlign.center,
                        style: bodyFont(
                          size: 19,
                          weight: FontWeight.w700,
                        ),
                        colors: AppPalette.heroGrad,
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
