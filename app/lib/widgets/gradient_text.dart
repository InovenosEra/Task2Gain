import 'package:flutter/material.dart';

/// Renders text painted with a linear gradient instead of a solid color.
/// Use for big "hero" numbers and titles — gives the gamified feel.
class GradientText extends StatelessWidget {
  const GradientText(
    this.text, {
    super.key,
    required this.style,
    required this.colors,
    this.begin = Alignment.topLeft,
    this.end = Alignment.bottomRight,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final List<Color> colors;
  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => LinearGradient(
        colors: colors,
        begin: begin,
        end: end,
      ).createShader(rect),
      child: Text(
        text,
        textAlign: textAlign,
        style: style.copyWith(color: Colors.white),
      ),
    );
  }
}
