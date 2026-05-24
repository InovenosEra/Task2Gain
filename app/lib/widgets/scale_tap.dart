import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Wraps a tappable widget and adds a subtle scale-down on press plus light
/// haptic feedback. Used everywhere we want a "satisfying" tap feel.
class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 130),
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Duration duration;
  final bool haptic;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  void _down(_) {
    if (widget.onTap == null) return;
    setState(() => _pressed = true);
  }

  void _up([_]) {
    if (!_pressed) return;
    setState(() => _pressed = false);
  }

  Future<void> _handleTap() async {
    if (widget.onTap == null) return;
    if (widget.haptic) {
      unawaited(HapticFeedback.lightImpact());
    }
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _up,
      onTap: _handleTap,
      child: AnimatedScale(
        duration: widget.duration,
        scale: _pressed ? widget.scale : 1.0,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

