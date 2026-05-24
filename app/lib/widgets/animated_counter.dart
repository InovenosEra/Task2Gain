import 'package:flutter/material.dart';

/// Tweens between integer values whenever [value] changes. Great for showing
/// points/XP increasing in a satisfying way.
class AnimatedIntCounter extends StatefulWidget {
  const AnimatedIntCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
    this.curve = Curves.easeOutCubic,
    this.textAlign,
    this.builder,
  });

  final int value;
  final TextStyle style;
  final Duration duration;
  final Curve curve;
  final TextAlign? textAlign;
  final Widget Function(BuildContext context, String text)? builder;

  @override
  State<AnimatedIntCounter> createState() => _AnimatedIntCounterState();
}

class _AnimatedIntCounterState extends State<AnimatedIntCounter> {
  late int _displayed = widget.value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _displayed.toDouble(), end: widget.value.toDouble()),
      duration: widget.duration,
      curve: widget.curve,
      onEnd: () => _displayed = widget.value,
      builder: (context, current, _) {
        final text = current.round().toString();
        if (widget.builder != null) return widget.builder!(context, text);
        return Text(text, style: widget.style, textAlign: widget.textAlign);
      },
    );
  }
}
