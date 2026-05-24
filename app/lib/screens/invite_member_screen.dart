import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/invitation_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_field.dart';
import '../widgets/gradient_text.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_chrome.dart';

class InviteMemberScreen extends StatefulWidget {
  const InviteMemberScreen({super.key, required this.familyId});
  final String familyId;

  @override
  State<InviteMemberScreen> createState() => _InviteMemberScreenState();
}

class _InviteMemberScreenState extends State<InviteMemberScreen> {
  final _service = InvitationService();
  String _role = 'kid';
  bool _generating = false;
  String? _code;
  String? _error;

  Future<void> _generate() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      final code = await _service.createInvite(
        familyId: widget.familyId,
        createdBy: uid,
        role: _role,
      );
      setState(() => _code = code);
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenChrome(
      title: 'הזמנת בן משפחה',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(
              child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 64)),
            ),
            const SizedBox(height: 12),
            GradientText(
              'מי מצטרף?',
              style: displayFont(size: 22, weight: FontWeight.w900),
              colors: AppPalette.heroGrad,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _RolePill(
                    label: 'ילד / ילדה',
                    emoji: '🧒',
                    tone: AppPalette.green,
                    selected: _role == 'kid',
                    onTap: () => setState(() => _role = 'kid'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _RolePill(
                    label: 'הורה נוסף',
                    emoji: '🧑',
                    tone: AppPalette.violet,
                    selected: _role == 'admin',
                    onTap: () => setState(() => _role = 'admin'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            if (_code != null) ...[
              _CodeCard(code: _code!),
              const SizedBox(height: 14),
              Text(
                'שלח את הקוד באיזה אמצעי שאתה אוהב.\nהם פותחים אפליקציה → "יש לי קוד הזמנה" → מקלידים.',
                textAlign: TextAlign.center,
                style: bodyFont(
                  size: 13,
                  color: Colors.white60,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              ScaleTap(
                onTap: _generating ? null : _generate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, color: Colors.white70),
                        const SizedBox(width: 6),
                        Text(
                          'צור קוד נוסף',
                          style: displayFont(
                              size: 14, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ] else
              PrimaryButton(
                label: 'יצירת קוד הזמנה',
                onTap: _generate,
                loading: _generating,
              ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.label,
    required this.emoji,
    required this.tone,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final Color tone;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? tone.withValues(alpha: 0.22)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? tone
                : Colors.white.withValues(alpha: 0.1),
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(
              label,
              style: displayFont(
                size: 14,
                weight: selected ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF34206B),
            Color(0xFF1A1B3A),
            Color(0xFF3F1A55),
          ],
        ),
        border: Border.all(
          color: AppPalette.gold.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.gold.withValues(alpha: 0.4),
            blurRadius: 28,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'הקוד שלך',
            style: bodyFont(
              size: 12,
              color: Colors.white60,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          GradientText(
            code,
            style: monoFont(size: 54).copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
            colors: AppPalette.heroGrad,
          ),
          const SizedBox(height: 10),
          ScaleTap(
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: AppPalette.green,
                  content: Text(
                    'הקוד הועתק 📋',
                    style: bodyFont(
                      color: AppPalette.bgDeep,
                      weight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.copy,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'העתק',
                    style: bodyFont(
                      color: Colors.white70,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
