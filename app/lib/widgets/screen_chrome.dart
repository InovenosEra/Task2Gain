import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_tap.dart';
import 'screen_background.dart';

/// Common scaffold for sub-screens: gradient background + back-arrow header
/// with a centered title. Pass the body widget.
class ScreenChrome extends StatelessWidget {
  const ScreenChrome({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.floatingActionButton,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.bgDeep,
        floatingActionButton: floatingActionButton,
        body: ScreenBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(8, 8, 8, 4),
                  child: Row(
                    children: [
                      ScaleTap(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color:
                                Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: const Icon(Icons.arrow_forward,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: displayFont(
                            size: 20,
                            weight: FontWeight.w900,
                          ),
                        ),
                      ),
                      ...actions.expand(
                        (w) => [w, const SizedBox(width: 4)],
                      ),
                      SizedBox(
                        width: actions.isEmpty ? 44 : 0,
                      ),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

