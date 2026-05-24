import 'dart:ui';

import 'package:flutter/material.dart';

/// Card with a soft glow halo. Use for hero metrics / important CTAs.
class GlowCard extends StatelessWidget {
  const GlowCard({
    super.key,
    required this.child,
    this.glowColor = const Color(0xFFFFD166),
    this.glowOpacity = 0.35,
    this.glowRadius = 28,
    this.borderRadius = 24,
    this.borderColor = Colors.white24,
    this.padding = const EdgeInsets.all(16),
    this.gradient,
    this.color,
  });

  final Widget child;
  final Color glowColor;
  final double glowOpacity;
  final double glowRadius;
  final double borderRadius;
  final Color borderColor;
  final EdgeInsets padding;
  final Gradient? gradient;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: glowColor.withValues(alpha: glowOpacity),
            blurRadius: glowRadius,
            spreadRadius: glowRadius * 0.1,
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: gradient,
          color: gradient == null ? (color ?? Colors.white.withValues(alpha: 0.06)) : null,
          border: Border.all(color: borderColor),
        ),
        child: child,
      ),
    );
  }
}

/// Frosted-glass card. Light backdrop blur + translucent fill.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.all(14),
    this.tint = Colors.white,
    this.tintOpacity = 0.06,
    this.borderColor = Colors.white24,
  });

  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;
  final Color tint;
  final double tintOpacity;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: tintOpacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: borderColor.withValues(alpha: 0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
