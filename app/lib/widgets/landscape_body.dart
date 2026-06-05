import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared landscape layout for the pushed section screens (tasks / shop /
/// family / profile): an optional compact [strip] across the top (summary +
/// quick actions), then the section's primary [content] filling the full
/// width below. Stacked, never side-by-side, so the content uses the whole
/// landscape frame.
class LandscapeSection extends StatelessWidget {
  const LandscapeSection({super.key, this.strip, required this.content});

  /// Compact full-width summary bar shown above the content. Optional.
  final Widget? strip;

  /// Primary content (grids / lists). Fills the remaining height.
  final Widget content;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (strip != null) ...[strip!, const SizedBox(height: 12)],
          Expanded(child: content),
        ],
      ),
    );
  }
}

/// Section heading used above a content grid/list, with an optional trailing
/// widget (e.g. an availability dot). Keeps the heading rhythm identical
/// across the section screens.
class PaneTitle extends StatelessWidget {
  const PaneTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Text(title, style: displayFont(size: 20, weight: FontWeight.w900)),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}
