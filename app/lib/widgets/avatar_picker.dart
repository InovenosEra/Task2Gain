import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

const _gold = Color(0xFFFFD166);

const kidAvatars = ['🦁', '🐯', '🐼', '🐰', '🦊', '🐸', '🦄', '🐱', '🐶', '🐧'];
const adultAvatars = ['👩', '👨', '🧑', '👧', '👦', '🦸‍♀️', '🦸', '🧙‍♀️', '🧙', '🤴'];

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.options = kidAvatars,
    this.light = false,
    this.bubbleSize = 56,
    this.photoFile,
    this.onPickPhoto,
  });

  final String selected;
  final void Function(String) onSelect;
  final List<String> options;

  /// Light styling for use on a white card (city theme).
  final bool light;
  final double bubbleSize;

  /// A locally-picked photo to preview as the selected avatar. When set, it
  /// overrides the emoji selection until an emoji is tapped.
  final File? photoFile;

  /// When provided, camera + gallery chips are shown before the emoji bubbles.
  final void Function(ImageSource source)? onPickPhoto;

  @override
  Widget build(BuildContext context) {
    const goldDeep = Color(0xFFFFA94D);
    final size = bubbleSize;
    final radius = size / 2;
    final idleBg =
        light ? const Color(0xFFF2F3F8) : Colors.white.withValues(alpha: 0.06);
    final idleBorder = light
        ? const Color(0xFFE2E4EE)
        : Colors.white.withValues(alpha: 0.1);
    final selBg = _gold.withValues(alpha: light ? 0.32 : 0.25);
    final selBorder = light ? goldDeep : _gold;
    final iconColor =
        light ? const Color(0xFF7B2CBF) : Colors.white.withValues(alpha: 0.8);
    final photoActive = photoFile != null;

    Widget chip(IconData icon, ImageSource source) {
      return GestureDetector(
        onTap: () => onPickPhoto!(source),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: idleBg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: idleBorder),
          ),
          child: Icon(icon, size: size * 0.42, color: iconColor),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        if (onPickPhoto != null) ...[
          chip(Icons.photo_camera_rounded, ImageSource.camera),
          chip(Icons.photo_library_rounded, ImageSource.gallery),
        ],
        if (photoActive)
          Container(
            width: size,
            height: size,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: selBorder, width: 2),
            ),
            child: Image.file(photoFile!, fit: BoxFit.cover),
          ),
        ...options.map((emoji) {
          final isSelected = !photoActive && emoji == selected;
          return GestureDetector(
            onTap: () => onSelect(emoji),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? selBg : idleBg,
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(
                  color: isSelected ? selBorder : idleBorder,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(emoji, style: TextStyle(fontSize: size * 0.54)),
            ),
          );
        }),
      ],
    );
  }
}

/// Normalizes a stored avatar value to a renderable emoji. Older users were
/// seeded with text identifiers like "parent-default"; map those to fallbacks
/// so the bubble doesn't render mangled text.
String normalizeAvatar(String value) {
  if (value.isEmpty) return '👤';
  if (value == 'parent-default') return adultAvatars.first;
  if (value == 'kid-default') return kidAvatars.first;
  // If the value still looks like multi-char text, fall back.
  if (value.length > 4) return '👤';
  return value;
}

/// Small circular avatar bubble for headers / lists.
class AvatarBubble extends StatelessWidget {
  const AvatarBubble({
    super.key,
    required this.emoji,
    this.size = 40,
    this.tone = _gold,
  });

  final String emoji;
  final double size;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    // A photo avatar stores a download URL in the same `value` slot an emoji
    // would occupy, so detect it here and render the image circularly.
    final isUrl = emoji.startsWith('http');
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: isUrl ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: isUrl
          ? Image.network(
              emoji,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Text(
                '👤',
                style: GoogleFonts.heebo(fontSize: size * 0.55),
              ),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Center(
                      child: SizedBox(
                        width: size * 0.4,
                        height: size * 0.4,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: tone,
                        ),
                      ),
                    ),
            )
          : Text(
              normalizeAvatar(emoji),
              style: GoogleFonts.heebo(fontSize: size * 0.55),
            ),
    );
  }
}
