import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Standard text-input look across the app: dark fill, gold focus border,
/// pink error state. Use everywhere instead of plain TextFormField so forms
/// stay consistent.
class GameField extends StatelessWidget {
  const GameField({
    super.key,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.textDirection,
    this.obscureText = false,
    this.maxLines = 1,
    this.maxLength,
    this.validator,
    this.suffix,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final TextDirection? textDirection;
  final bool obscureText;
  final int maxLines;
  final int? maxLength;
  final String? Function(String?)? validator;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      maxLength: maxLength,
      validator: validator,
      style: bodyFont(size: 16),
      cursorColor: AppPalette.gold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: bodyFont(
          size: 15,
          color: Colors.white.withValues(alpha: 0.32),
        ),
        suffixIcon: suffix,
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: _border(Colors.white.withValues(alpha: 0.08)),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.08)),
        focusedBorder: _border(AppPalette.gold, width: 1.6),
        errorBorder: _border(AppPalette.pink),
        focusedErrorBorder: _border(AppPalette.pink, width: 1.6),
        errorStyle: bodyFont(size: 12, color: AppPalette.pink),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
}

/// Tiny label rendered above a field. Use to keep label typography consistent.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Text(
        text,
        style: bodyFont(
          size: 13,
          color: Colors.white.withValues(alpha: 0.85),
          weight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Standardized gold pill button used for primary CTA in forms.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: enabled
                ? const [AppPalette.gold, AppPalette.goldDeep]
                : [
                    AppPalette.gold.withValues(alpha: 0.35),
                    AppPalette.goldDeep.withValues(alpha: 0.35),
                  ],
          ),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppPalette.gold.withValues(alpha: 0.45),
                    blurRadius: 22,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppPalette.bgDeep,
                  ),
                )
              : Text(
                  label,
                  style: displayFont(
                    size: 18,
                    weight: FontWeight.w900,
                    color: AppPalette.bgDeep,
                  ),
                ),
        ),
      ),
    );
  }
}

/// Inline error banner for form-level errors.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppPalette.pink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppPalette.pink.withValues(alpha: 0.4)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.right,
        style: bodyFont(color: Colors.white, weight: FontWeight.w600),
      ),
    );
  }
}
