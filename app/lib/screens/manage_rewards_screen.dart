import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/reward.dart';
import '../services/reward_service.dart';
import '../theme/app_theme.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_chrome.dart';

const _iconChoices = [
  '🎁', '🍦', '🎮', '📺', '🎬', '🍕', '🚲', '🧸', '🎨', '⚽', '📚', '💎',
];

class ManageRewardsScreen extends StatelessWidget {
  const ManageRewardsScreen({super.key, required this.familyId});
  final String familyId;

  @override
  Widget build(BuildContext context) {
    final service = RewardService();
    return ScreenChrome(
      title: 'חנות פרסים',
      floatingActionButton: ScaleTap(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) =>
                _AddRewardSheet(familyId: familyId, service: service),
          );
        },
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [AppPalette.gold, AppPalette.goldDeep],
            ),
            boxShadow: [
              BoxShadow(
                color: AppPalette.gold.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: AppPalette.bgDeep),
              const SizedBox(width: 6),
              Text(
                'פרס חדש',
                style: displayFont(
                  size: 15,
                  weight: FontWeight.w900,
                  color: AppPalette.bgDeep,
                ),
              ),
            ],
          ),
        ),
      ),
      child: StreamBuilder<List<Reward>>(
        stream: service.watchFamilyRewards(familyId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppPalette.gold),
            );
          }
          final rewards = snap.data ?? const [];
          if (rewards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('🎁', style: TextStyle(fontSize: 72)),
                    const SizedBox(height: 14),
                    Text(
                      'אין עדיין פרסים',
                      textAlign: TextAlign.center,
                      style:
                          displayFont(size: 22, weight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'הוסף משהו שילדים יחסכו עבורו',
                      textAlign: TextAlign.center,
                      style: bodyFont(size: 14, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            itemCount: rewards.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = rewards[i];
              return _AdminRewardTile(
                reward: r,
                onDelete: () => service.deactivate(r.id),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdminRewardTile extends StatelessWidget {
  const _AdminRewardTile({required this.reward, required this.onDelete});
  final Reward reward;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color(0x40FFD166),
                  Color(0x30EF476F),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppPalette.gold.withValues(alpha: 0.4),
              ),
            ),
            child: Text(reward.icon, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reward.title,
                  style: displayFont(size: 16, weight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  reward.stock == null
                      ? '₪${reward.priceILS.toStringAsFixed(2)}'
                      : '₪${reward.priceILS.toStringAsFixed(2)}  ·  מלאי ${reward.stock}',
                  style:
                      bodyFont(size: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          ScaleTap(
            onTap: onDelete,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppPalette.pink.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline,
                  color: AppPalette.pink, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddRewardSheet extends StatefulWidget {
  const _AddRewardSheet({required this.familyId, required this.service});
  final String familyId;
  final RewardService service;

  @override
  State<_AddRewardSheet> createState() => _AddRewardSheetState();
}

class _AddRewardSheetState extends State<_AddRewardSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController(text: '10');
  final _stockController = TextEditingController();
  String _icon = '🎁';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final stockStr = _stockController.text.trim();
      await widget.service.create(
        familyId: widget.familyId,
        createdBy: uid,
        title: _titleController.text.trim(),
        description: '',
        icon: _icon,
        priceILS: double.parse(_priceController.text.trim()),
        stock: stockStr.isEmpty ? null : int.parse(stockStr),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
          decoration: const BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'פרס חדש',
                  textAlign: TextAlign.center,
                  style: displayFont(size: 20, weight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                _label('שם הפרס'),
                _field(
                  controller: _titleController,
                  hint: 'למשל: שעה משחק נוסף',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'חובה' : null,
                ),
                const SizedBox(height: 14),
                _label('אייקון'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _iconChoices.map((icon) {
                    final selected = icon == _icon;
                    return ScaleTap(
                      onTap: () => setState(() => _icon = icon),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? AppPalette.gold.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? AppPalette.gold
                                : Colors.white.withValues(alpha: 0.1),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child:
                            Text(icon, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('מחיר (₪)'),
                          _field(
                            controller: _priceController,
                            hint: '10',
                            keyboardType: const TextInputType
                                .numberWithOptions(decimal: true),
                            textDirection: TextDirection.ltr,
                            validator: (v) {
                              final n = double.tryParse((v ?? '').trim());
                              if (n == null || n <= 0) return 'מספר חיובי';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _label('מלאי (ריק = ∞)'),
                          _field(
                            controller: _stockController,
                            hint: 'ריק',
                            keyboardType: TextInputType.number,
                            textDirection: TextDirection.ltr,
                            validator: (v) {
                              final s = (v ?? '').trim();
                              if (s.isEmpty) return null;
                              final n = int.tryParse(s);
                              if (n == null || n < 0) return 'מספר';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: bodyFont(color: AppPalette.pink)),
                ],
                const SizedBox(height: 18),
                ScaleTap(
                  onTap: _submitting ? null : _submit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: _submitting
                            ? [
                                AppPalette.gold.withValues(alpha: 0.4),
                                AppPalette.goldDeep
                                    .withValues(alpha: 0.4),
                              ]
                            : const [
                                AppPalette.gold,
                                AppPalette.goldDeep,
                              ],
                      ),
                    ),
                    child: Center(
                      child: _submitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppPalette.bgDeep,
                              ),
                            )
                          : Text(
                              'הוסף פרס',
                              style: displayFont(
                                size: 16,
                                weight: FontWeight.w900,
                                color: AppPalette.bgDeep,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, right: 4),
      child: Text(
        text,
        style: bodyFont(
          size: 12,
          color: Colors.white70,
          weight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textDirection: textDirection,
      autocorrect: false,
      enableSuggestions: false,
      validator: validator,
      style: bodyFont(size: 15),
      cursorColor: AppPalette.gold,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: bodyFont(
          size: 14,
          color: Colors.white.withValues(alpha: 0.3),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: _border(Colors.white.withValues(alpha: 0.1)),
        enabledBorder: _border(Colors.white.withValues(alpha: 0.1)),
        focusedBorder: _border(AppPalette.gold, width: 1.5),
        errorBorder: _border(AppPalette.pink),
        focusedErrorBorder: _border(AppPalette.pink, width: 1.5),
        errorStyle: bodyFont(size: 11, color: AppPalette.pink),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
}
