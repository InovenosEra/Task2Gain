import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_field.dart';
import '../widgets/gradient_text.dart';
import '../widgets/screen_chrome.dart';

class TransferCashCashScreen extends StatefulWidget {
  const TransferCashCashScreen({
    super.key,
    required this.uid,
    required this.familyId,
  });
  final String uid;
  final String familyId;

  @override
  State<TransferCashCashScreen> createState() =>
      _TransferCashCashScreenState();
}

class _TransferCashCashScreenState extends State<TransferCashCashScreen> {
  final _controller = TextEditingController();
  final _service = WalletService();
  bool _submitting = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'הזן סכום חיובי');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _service.requestTransfer(
        userUid: widget.uid,
        familyId: widget.familyId,
        amountILS: amount,
      );
      setState(() => _sent = true);
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
      title: 'העברה ל-CashCash',
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: firestore
                  .collection('wallets')
                  .doc(widget.uid)
                  .snapshots(),
              builder: (context, snap) {
                final money = (snap.data?.data()?['moneyILS'] as num?)
                        ?.toDouble() ??
                    0.0;
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
                        color: AppPalette.sky.withValues(alpha: 0.25),
                        blurRadius: 24,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text('💸',
                          style: TextStyle(fontSize: 38)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'יש לך בארנק',
                              style: bodyFont(
                                size: 12,
                                color: Colors.white60,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            GradientText(
                              '₪${money.toStringAsFixed(2)}',
                              style: displayFont(
                                size: 30,
                                weight: FontWeight.w900,
                                height: 1.0,
                              ),
                              colors: AppPalette.heroGrad,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 28),
            const FieldLabel('כמה להעביר (₪)?'),
            TextField(
              controller: _controller,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.center,
              style: monoFont(size: 36, color: Colors.white),
              cursorColor: AppPalette.gold,
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: monoFont(
                  size: 36,
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
            const SizedBox(height: 12),
            Text(
              'ההורה יקבל בקשה ויצטרך לאשר.\nאחרי האישור — ההורה מבצע את ההעברה ידנית ב-CashCash.',
              textAlign: TextAlign.center,
              style: bodyFont(
                size: 12,
                color: Colors.white54,
                height: 1.5,
              ),
            ),
            if (_sent) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppPalette.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppPalette.green.withValues(alpha: 0.4),
                  ),
                ),
                child: Center(
                  child: Text(
                    '✅ הבקשה נשלחה לאישור',
                    style: displayFont(
                      size: 16,
                      weight: FontWeight.w800,
                    ),
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
              label: _sent ? 'נשלח 🎉' : 'בקש העברה',
              onTap: _sent ? null : _submit,
              loading: _submitting,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: color, width: width),
      );
}
