import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Layered background: vertical gradient + two soft radial "auroras".
/// Use as the body of every screen for a consistent atmospheric feel.
class ScreenBackground extends StatelessWidget {
  const ScreenBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppPalette.screenGrad,
              ),
            ),
          ),
        ),
        Positioned(
          top: -60,
          right: -100,
          child: _Aurora(
            color: AppPalette.gold,
            size: 280,
            opacity: 0.18,
          ),
        ),
        Positioned(
          bottom: -120,
          left: -120,
          child: _Aurora(
            color: AppPalette.violet,
            size: 360,
            opacity: 0.32,
          ),
        ),
        Positioned(
          top: 240,
          left: -80,
          child: _Aurora(
            color: AppPalette.pink,
            size: 220,
            opacity: 0.14,
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Aurora extends StatelessWidget {
  const _Aurora({
    required this.color,
    required this.size,
    required this.opacity,
  });

  final Color color;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}

