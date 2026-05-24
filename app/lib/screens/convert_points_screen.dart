import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_field.dart';
import '../widgets/gradient_text.dart';
import '../widgets/screen_chrome.dart';

class ConvertPointsScreen extends StatefulWidget {
  const ConvertPointsScreen({
    super.key,
    required this.uid,
    required this.familyId,
  });
  final String uid;
  final String familyId;

  @override
  State<ConvertPointsScreen> createState() => _ConvertPointsScreenState();
}

class _ConvertPointsScreenState extends State<ConvertPointsScreen> {
  final _controller = TextEditingController();
  final _service = WalletService();
  bool _submitting = false;
  String? _error;
  double? _credited;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _convert() async {
    final pts = int.tryParse(_controller.text.trim());
    if (pts == null || pts <= 0) {
      setState(() => _error = 'הזן מספר חיובי');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
      _credited = null;
    });
    try {
      final shekels = await _service.convertPoints(
        userUid: widget.uid,
        pointsToConvert: pts,
      );
      setState(() => _credited = shekels);
      _controller.clear();
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;
    return ScreenChrome(
      title: 'המרת נקודות',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('wallets')
                  .doc(widget.uid)
                  .snapshots(),
              builder: (context, snap) {
                final data = snap.data?.data() ?? const {};
                final points = (data['points'] as num?)?.toInt() ?? 0;
                final money =
                    (data['moneyILS'] as num?)?.toDouble() ?? 0.0;
                return Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        Color(0xFF34206B),
                        Color(0xFF1A1B3A),
                        Color(0xFF3F1A55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppPalette.gold.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _stat('⭐', '$points', 'נקודות')),
                      Container(
                        width: 1,
                        height: 56,
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                      Expanded(
                          child: _stat('💰',
                              '₪${money.toStringAsFixed(2)}', 'כסף')),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const FieldLabel('כמה נקודות להמיר?'),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: monoFont(size: 38, color: Colors.white),
              cursorColor: AppPalette.gold,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: monoFont(
                  size: 38,
                  color: Colors.white.withValues(alpha: 0.18),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                contentPadding: const EdgeInsets.symmetric(vertical: 18),
                border: _border(Colors.white.withValues(alpha: 0.08)),
                enabledBorder:
                    _border(Colors.white.withValues(alpha: 0.08)),
                focusedBorder: _border(AppPalette.gold, width: 1.6),
              ),
            ),
            if (_credited != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppPalette.green.withValues(alpha: 0.5),
                  ),
                ),
                child: Center(
                  child: GradientText(
                    '🎉  +₪${_credited!.toStringAsFixed(2)}',
                    style: displayFont(size: 22, weight: FontWeight.w900),
                    colors: const [AppPalette.green, AppPalette.gold],
                  ),
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'המר עכשיו',
              onTap: _convert,
              loading: _submitting,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _stat(String emoji, String big, String small) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 28)),
        const SizedBox(height: 4),
        Text(
          big,
          style: displayFont(size: 22, weight: FontWeight.w900, height: 1.0),
        ),
        const SizedBox(height: 2),
        Text(
          small,
          style: bodyFont(size: 11, color: Colors.white60),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
