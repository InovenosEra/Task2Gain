import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const _gold = Color(0xFFFFD166);

const kidAvatars = ['🦁', '🐯', '🐼', '🐰', '🦊', '🐸', '🦄', '🐱', '🐶', '🐧'];
const adultAvatars = ['👩', '👨', '🧑', '👧', '👦', '🦸‍♀️', '🦸', '🧙‍♀️', '🧙', '🤴'];

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    required this.selected,
    required this.onSelect,
    this.options = kidAvatars,
  });

  final String selected;
  final void Function(String) onSelect;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: options.map((emoji) {
        final isSelected = emoji == selected;
        return GestureDetector(
          onTap: () => onSelect(emoji),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? _gold.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isSelected
                    ? _gold
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        );
      }).toList(),
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
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: tone.withValues(alpha: 0.5)),
      ),
      child: Text(
        normalizeAvatar(emoji),
        style: GoogleFonts.heebo(fontSize: size * 0.55),
      ),
    );
  }
}
