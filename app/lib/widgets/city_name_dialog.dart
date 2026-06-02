import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Prompts for a new city name and returns it (or null if cancelled).
///
/// The dialog owns its [TextEditingController] and disposes it in its own
/// `dispose()`. Disposing the controller right after `showDialog` returns is a
/// bug: the future completes when the route is *popped*, while the [TextField]
/// is still mounted and animating out — freeing the controller then triggers a
/// "TextEditingController used after being disposed" cascade.
Future<String?> showCityNameDialog(
  BuildContext context, {
  required String initialName,
  required String hint,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => CityNameDialog(initialName: initialName, hint: hint),
  );
}

class CityNameDialog extends StatefulWidget {
  const CityNameDialog({
    super.key,
    required this.initialName,
    required this.hint,
  });

  final String initialName;
  final String hint;

  @override
  State<CityNameDialog> createState() => _CityNameDialogState();
}

class _CityNameDialogState extends State<CityNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppPalette.surface,
        title: Text('שם העיר', style: displayFont(size: 18)),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLength: 24,
          textAlign: TextAlign.right,
          style: bodyFont(size: 16),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: bodyFont(size: 16, color: Colors.white38),
          ),
          onSubmitted: (v) => Navigator.of(context).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ביטול', style: bodyFont(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_controller.text),
            child: Text('שמירה', style: bodyFont(color: AppPalette.gold)),
          ),
        ],
      ),
    );
  }
}
