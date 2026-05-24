import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/quest.dart';
import '../services/quest_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_field.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_chrome.dart';

const _iconChoices = ['⚡', '🧹', '📚', '🛏️', '🍽️', '🐕', '🚿', '🎨', '🏃', '🎵'];

class CreateQuestScreen extends StatefulWidget {
  const CreateQuestScreen({
    super.key,
    required this.familyId,
    this.existing,
  });
  final String familyId;
  final Quest? existing;

  @override
  State<CreateQuestScreen> createState() => _CreateQuestScreenState();
}

class _CreateQuestScreenState extends State<CreateQuestScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _pointsController;
  final _service = QuestService();

  late String _icon;
  late QuestDifficulty _difficulty;
  late QuestProof _proof;
  late QuestRecurrence _recurrence;
  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleController = TextEditingController(text: e?.title ?? '');
    _descController = TextEditingController(text: e?.description ?? '');
    _pointsController =
        TextEditingController(text: (e?.points ?? 10).toString());
    _icon = e?.icon ?? '⚡';
    _difficulty = e?.difficulty ?? QuestDifficulty.easy;
    _proof = e?.proofRequired ?? QuestProof.none;
    _recurrence = e?.recurrence ?? QuestRecurrence.once;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _pointsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() => _error = 'לא מחובר');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await _service.updateQuest(
          questId: widget.existing!.id,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          icon: _icon,
          points: int.parse(_pointsController.text.trim()),
          difficulty: _difficulty,
          proofRequired: _proof,
          recurrence: _recurrence,
        );
      } else {
        await _service.createQuest(
          familyId: widget.familyId,
          createdBy: uid,
          title: _titleController.text.trim(),
          description: _descController.text.trim(),
          icon: _icon,
          points: int.parse(_pointsController.text.trim()),
          difficulty: _difficulty,
          proofRequired: _proof,
          recurrence: _recurrence,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = _isEdit ? 'שגיאה בעדכון: $e' : 'שגיאה ביצירה: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenChrome(
      title: _isEdit ? 'עריכת קווסט' : 'קווסט חדש',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const FieldLabel('כותרת'),
              GameField(
                controller: _titleController,
                hint: 'למשל: סדר את החדר',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'חובה' : null,
              ),
              const SizedBox(height: 14),
              const FieldLabel('תיאור (אופציונלי)'),
              GameField(
                controller: _descController,
                hint: 'הסבר קצר על המשימה',
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              const FieldLabel('אייקון'),
              _IconPicker(
                selected: _icon,
                onSelect: (v) => setState(() => _icon = v),
              ),
              const SizedBox(height: 14),
              const FieldLabel('נקודות'),
              GameField(
                controller: _pointsController,
                hint: '10',
                keyboardType: TextInputType.number,
                textDirection: TextDirection.ltr,
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'מספר חיובי';
                  if (n > 9999) return 'מקסימום 9999';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const FieldLabel('דרגת קושי'),
              _DifficultyRow(
                selected: _difficulty,
                onSelect: (v) => setState(() => _difficulty = v),
              ),
              const SizedBox(height: 14),
              const FieldLabel('הוכחה נדרשת'),
              _Segmented<QuestProof>(
                values: QuestProof.values,
                selected: _proof,
                labelOf: (v) => v.label,
                onSelect: (v) => setState(() => _proof = v),
              ),
              const SizedBox(height: 14),
              const FieldLabel('תדירות'),
              _Segmented<QuestRecurrence>(
                values: QuestRecurrence.values,
                selected: _recurrence,
                labelOf: (v) => v.label,
                onSelect: (v) => setState(() => _recurrence = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 14),
                ErrorBanner(message: _error!),
              ],
              const SizedBox(height: 24),
              PrimaryButton(
                label: _isEdit ? 'שמור שינויים' : 'צור קווסט',
                onTap: _submit,
                loading: _submitting,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPicker extends StatelessWidget {
  const _IconPicker({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _iconChoices.map((icon) {
        final isSelected = icon == selected;
        return ScaleTap(
          onTap: () => onSelect(icon),
          child: Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppPalette.gold.withValues(alpha: 0.25)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppPalette.gold
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(icon, style: const TextStyle(fontSize: 26)),
          ),
        );
      }).toList(),
    );
  }
}

class _DifficultyRow extends StatelessWidget {
  const _DifficultyRow({required this.selected, required this.onSelect});
  final QuestDifficulty selected;
  final void Function(QuestDifficulty) onSelect;

  List<Color> _gradOf(QuestDifficulty d) {
    switch (d) {
      case QuestDifficulty.easy:
        return AppPalette.easyGrad;
      case QuestDifficulty.medium:
        return AppPalette.mediumGrad;
      case QuestDifficulty.epic:
        return AppPalette.epicGrad;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: QuestDifficulty.values
          .map((d) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ScaleTap(
                    onTap: () => onSelect(d),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: d == selected
                            ? LinearGradient(
                                colors: _gradOf(d)
                                    .map((c) => c.withValues(alpha: 0.4))
                                    .toList(),
                              )
                            : null,
                        color: d == selected
                            ? null
                            : Colors.white.withValues(alpha: 0.04),
                        border: Border.all(
                          color: d == selected
                              ? _gradOf(d).first
                              : Colors.white.withValues(alpha: 0.08),
                          width: d == selected ? 1.5 : 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          d.label,
                          style: displayFont(
                            size: 14,
                            weight: d == selected
                                ? FontWeight.w900
                                : FontWeight.w600,
                            color: d == selected
                                ? Colors.white
                                : Colors.white60,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final void Function(T) onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final isSelected = v == selected;
        return ScaleTap(
          onTap: () => onSelect(v),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppPalette.gold.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected
                    ? AppPalette.gold
                    : Colors.white.withValues(alpha: 0.1),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Text(
              labelOf(v),
              style: bodyFont(
                size: 14,
                color: Colors.white,
                weight:
                    isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
