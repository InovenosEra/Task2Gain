import 'package:flutter/material.dart';

/// Soft fade + slight slide-up for normal navigation. Use instead of
/// MaterialPageRoute for a consistent in-app feel.
class FadeUpRoute<T> extends PageRouteBuilder<T> {
  FadeUpRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (ctx, _, _) => builder(ctx),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 220),
        );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.04),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}

extension NavigatorExt on BuildContext {
  Future<T?> pushFadeUp<T>(WidgetBuilder builder) {
    return Navigator.of(this).push<T>(FadeUpRoute<T>(builder: builder));
  }

  Future<T?> replaceFadeUp<T>(WidgetBuilder builder) {
    return Navigator.of(this)
        .pushReplacement<T, void>(FadeUpRoute<T>(builder: builder));
  }
}
