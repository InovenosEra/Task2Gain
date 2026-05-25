import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../game/economy_config.dart';
import '../services/wallet_service.dart';
import '../theme/app_theme.dart';
import '../widgets/game_field.dart';
import 'convert_points_screen.dart';

/// Opens the cash-out sheet: spend XP on tokens (to keep playing), money,
/// or point the player to the prize shop. The XP -> money path reuses the
/// existing [ConvertPointsScreen]; the XP -> tokens trade lives here.
Future<void> showCashOutSheet(
  BuildContext context, {
  required String uid,
  required String familyId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _CashOutBody(uid: uid, familyId: familyId),
  );
}

class _CashOutBody extends StatefulWidget {
  const _CashOutBody({required this.uid, required this.familyId});
  final String uid;
  final String familyId;

  @override
  State<_CashOutBody> createState() => _CashOutBodyState();
}

class _CashOutBodyState extends State<_CashOutBody> {
  final WalletService _service = WalletService();
  bool _busy = false;
  String? _error;
  int? _tokensGained;

  // XP amounts offered for the token trade (Y = tokensFromXp(X)).
  static final List<int> _tradeAmounts = [
    20,
    40,
    (kXpToTokenDailyCap * 2), // the daily-cap-maxing trade
  ];

  Future<void> _trade(int xp) async {
    setState(() {
      _busy = true;
      _error = null;
      _tokensGained = null;
    });
    try {
      final got = await _service.convertXpToTokens(
        userUid: widget.uid,
        xpToSpend: xp,
      );
      setState(() => _tokensGained = got);
    } on StateError catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'שגיאה: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        padding: EdgeInsets.fromLTRB(
            20, 14, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: AppPalette.bgDeep,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('פדיון נקודות',
                textAlign: TextAlign.center,
                style: displayFont(size: 20, weight: FontWeight.w900)),
            const SizedBox(height: 14),
            _balances(),
            const SizedBox(height: 20),
            Text('החלף נקודות לאסימונים כדי להמשיך לבנות',
                style: bodyFont(size: 13, color: Colors.white70)),
            const SizedBox(height: 4),
            Text(
              'יחס המרה ${(kXpToTokenRate * 100).round()}% · עד $kXpToTokenDailyCap טוקנים ביום',
              style: bodyFont(size: 10.5, color: Colors.white38),
            ),
            const SizedBox(height: 10),
            _tradeRow(),
            if (_tokensGained != null) ...[
              const SizedBox(height: 12),
              _successBanner('🎉  +$_tokensGained ⚡'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorBanner(message: _error!),
            ],
            const SizedBox(height: 20),
            const Divider(color: Colors.white12, height: 1),
            const SizedBox(height: 16),
            PrimaryButton(
              label: '💰  המר נקודות לכסף',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ConvertPointsScreen(
                    uid: widget.uid,
                    familyId: widget.familyId,
                  ),
                ));
              },
            ),
            const SizedBox(height: 10),
            Text('🎁  פרסים אמיתיים זמינים בלשונית "חנות"',
                textAlign: TextAlign.center,
                style: bodyFont(size: 11.5, color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _balances() {
    final stream = FirebaseFirestore.instance
        .collection('wallets')
        .doc(widget.uid)
        .snapshots();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        final w = snap.data?.data() ?? const {};
        final xp = (w['points'] as num?)?.toInt() ?? 0;
        final tokens = (w['tokens'] as num?)?.toInt() ?? 0;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppPalette.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(child: _stat('⭐', '$xp', 'נקודות')),
              Container(
                  width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
              Expanded(child: _stat('⚡', '$tokens', 'אסימונים')),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String emoji, String value, String label) => Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 3),
          Text(value, style: displayFont(size: 20, weight: FontWeight.w900)),
          Text(label, style: bodyFont(size: 10, color: Colors.white54)),
        ],
      );

  Widget _tradeRow() {
    return Row(
      children: [
        for (final xp in _tradeAmounts) ...[
          Expanded(
            child: GestureDetector(
              onTap: _busy ? null : () => _trade(xp),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppPalette.gold.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppPalette.gold.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Text('$xp ⭐',
                        style: bodyFont(size: 12, color: Colors.white70)),
                    const SizedBox(height: 2),
                    Text('${tokensFromXp(xp)} ⚡',
                        style:
                            displayFont(size: 16, weight: FontWeight.w900)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _successBanner(String text) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppPalette.green.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppPalette.green.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(text,
              style: displayFont(size: 18, weight: FontWeight.w900)),
        ),
      );
}
