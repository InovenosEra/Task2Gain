import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'level_up_overlay.dart';

/// Watches the user document for level changes and shows a celebration
/// overlay whenever the level increases.
class LevelChangeListener extends StatefulWidget {
  const LevelChangeListener({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<LevelChangeListener> createState() => _LevelChangeListenerState();
}

class _LevelChangeListenerState extends State<LevelChangeListener> {
  int? _lastSeenLevel;
  bool _showingOverlay = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .snapshots(),
      builder: (context, snap) {
        final level = (snap.data?.data()?['level'] as num?)?.toInt();
        if (level != null) {
          final prev = _lastSeenLevel;
          _lastSeenLevel = level;
          if (prev != null && level > prev && !_showingOverlay) {
            _showingOverlay = true;
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              if (!mounted) return;
              await showLevelUpOverlay(context, level);
              if (mounted) _showingOverlay = false;
            });
          }
        }
        return widget.child;
      },
    );
  }
}
