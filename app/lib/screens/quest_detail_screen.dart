import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/quest.dart';
import '../services/photo_upload_service.dart';
import '../services/quest_instance_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_field.dart';
import '../widgets/gradient_text.dart';
import '../widgets/scale_tap.dart';
import '../widgets/screen_background.dart';

class QuestDetailScreen extends StatefulWidget {
  const QuestDetailScreen({
    super.key,
    required this.quest,
    required this.kidUid,
  });

  final Quest quest;
  final String kidUid;

  @override
  State<QuestDetailScreen> createState() => _QuestDetailScreenState();
}

class _QuestDetailScreenState extends State<QuestDetailScreen> {
  final _service = QuestInstanceService();
  final _uploader = PhotoUploadService();
  final _picker = ImagePicker();
  bool _submitting = false;
  String? _error;
  String? _instanceId;
  File? _proofFile;

  bool get _needsPhoto =>
      widget.quest.proofRequired == QuestProof.photo ||
      widget.quest.proofRequired == QuestProof.beforeAfter;

  List<Color> get _grad {
    switch (widget.quest.difficulty) {
      case QuestDifficulty.easy:
        return AppPalette.easyGrad;
      case QuestDifficulty.medium:
        return AppPalette.mediumGrad;
      case QuestDifficulty.epic:
        return AppPalette.epicGrad;
    }
  }

  Future<void> _pickPhoto({required ImageSource source}) async {
    try {
      final xfile = await _picker.pickImage(
        source: source,
        imageQuality: 75,
        maxWidth: 1600,
      );
      if (xfile == null) return;
      setState(() => _proofFile = File(xfile.path));
    } catch (e) {
      setState(() => _error = 'שגיאה בבחירת תמונה: $e');
    }
  }

  Future<void> _startAndSubmit() async {
    if (_needsPhoto && _proofFile == null) {
      setState(() => _error = 'צריך לצרף תמונה');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final id = _instanceId ??
          await _service.startQuest(
              quest: widget.quest, kidUid: widget.kidUid);
      _instanceId = id;
      List<String>? urls;
      if (_proofFile != null) {
        final url = await _uploader.uploadProof(
          familyId: widget.quest.familyId,
          instanceId: id,
          name: 'proof_${DateTime.now().millisecondsSinceEpoch}',
          file: _proofFile!,
        );
        urls = [url];
      }
      await _service.submit(id, proofPhotos: urls);
      if (!mounted) return;
      _showCelebration();
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showCelebration() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppPalette.bgDeep,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppPalette.gold, width: 2),
            boxShadow: [
              BoxShadow(
                color: AppPalette.gold.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🎉', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 8),
              GradientText(
                'יאללה!',
                style: displayFont(
                    size: 32, weight: FontWeight.w900),
                colors: AppPalette.heroGrad,
              ),
              const SizedBox(height: 10),
              Text(
                'נשלח להורה לאישור.\nכשתאושר תקבל +${widget.quest.points}⭐ ו-${widget.quest.xpReward} XP',
                textAlign: TextAlign.center,
                style: bodyFont(size: 14, height: 1.6),
              ),
              const SizedBox(height: 20),
              ScaleTap(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppPalette.gold, AppPalette.goldDeep],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'אחלה',
                    style: displayFont(
                      size: 16,
                      weight: FontWeight.w900,
                      color: AppPalette.bgDeep,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.quest;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppPalette.bgDeep,
        body: ScreenBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_forward,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 140,
                    height: 140,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(36),
                      gradient: LinearGradient(
                        colors: _grad
                            .map((c) => c.withValues(alpha: 0.3))
                            .toList(),
                      ),
                      border:
                          Border.all(color: _grad.first, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: _grad.first.withValues(alpha: 0.4),
                          blurRadius: 30,
                          spreadRadius: -2,
                        ),
                      ],
                    ),
                    child:
                        Text(q.icon, style: const TextStyle(fontSize: 70)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    q.title,
                    textAlign: TextAlign.center,
                    style: displayFont(
                        size: 26, weight: FontWeight.w900),
                  ),
                  if (q.description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      q.description,
                      textAlign: TextAlign.center,
                      style: bodyFont(
                          size: 14,
                          color: Colors.white70,
                          height: 1.5),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip('${q.points}', '⭐', 'נקודות',
                          AppPalette.gold),
                      _chip('${q.xpReward}', '🔥', 'XP',
                          AppPalette.violet),
                      _chip(q.difficulty.label, '💪', 'קושי',
                          _grad.first),
                      _chip(q.recurrence.label, '🔁', 'תדירות',
                          AppPalette.sky),
                    ],
                  ),
                  if (_needsPhoto) ...[
                    const SizedBox(height: 20),
                    _PhotoProofPanel(
                      file: _proofFile,
                      onPick: _pickPhoto,
                      label: q.proofRequired.label,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 28),
                  ScaleTap(
                    onTap: _submitting ? null : _startAndSubmit,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: LinearGradient(
                          colors: _submitting
                              ? _grad
                                  .map((c) => c.withValues(alpha: 0.4))
                                  .toList()
                              : _grad,
                        ),
                        boxShadow: _submitting
                            ? null
                            : [
                                BoxShadow(
                                  color: _grad.first
                                      .withValues(alpha: 0.55),
                                  blurRadius: 26,
                                  spreadRadius: 1,
                                ),
                              ],
                      ),
                      child: Center(
                        child: _submitting
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : Text(
                                'סיימתי! שלח לאישור',
                                style: displayFont(
                                  size: 20,
                                  weight: FontWeight.w900,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String value, String emoji, String label, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(
            value,
            style: displayFont(size: 14, weight: FontWeight.w900),
          ),
          Text(
            label,
            style: bodyFont(size: 10, color: Colors.white60),
          ),
        ],
      ),
    );
  }
}

class _PhotoProofPanel extends StatelessWidget {
  const _PhotoProofPanel({
    required this.file,
    required this.onPick,
    required this.label,
  });

  final File? file;
  final Future<void> Function({required ImageSource source}) onPick;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('📸', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'הוכחה נדרשת: $label',
                  style: displayFont(
                      size: 14, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (file != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                file!,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 160,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🖼️',
                      style: TextStyle(fontSize: 42)),
                  const SizedBox(height: 6),
                  Text(
                    'אין עדיין תמונה',
                    style: bodyFont(color: Colors.white54),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ProofButton(
                  emoji: '📷',
                  label: 'מצלמה',
                  onTap: () => onPick(source: ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ProofButton(
                  emoji: '🖼️',
                  label: 'מהאוסף',
                  onTap: () => onPick(source: ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProofButton extends StatelessWidget {
  const _ProofButton({
    required this.emoji,
    required this.label,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final Future<void> Function() onTap;
  @override
  Widget build(BuildContext context) {
    return ScaleTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                label,
                style: displayFont(
                    size: 14, weight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
